import AppKit
import Foundation
import Observation

@MainActor
@Observable
public final class StandardCalculatorViewModel: CalcManagerBridgeDelegate {
    private static let standardModePrecision: Int32 = 16
    private static let scientificModePrecision: Int32 = 32
    private static let programmerModePrecision: Int32 = 64

    private let engine: CalcManagerBridge
    private let res: ResourceProvider

    // Mode state
    public private(set) var activeMode: ViewMode = .standard
    public var isStandard: Bool { activeMode == .standard }
    public var isScientific: Bool { activeMode == .scientific }
    public var isProgrammer: Bool { activeMode == .programmer }

    // Display state
    public private(set) var displayValue: String = "0"
    public private(set) var expressionTokens: [ExpressionToken] = []
    public private(set) var isInError: Bool = false
    public private(set) var isInputEmpty: Bool = true
    public private(set) var openParenthesisCount: UInt32 = 0

    // Scientific state
    public var angleMode: AngleMode = .degrees
    public var isFToEChecked: Bool = false
    public private(set) var isFToEEnabled: Bool = true
    public var isSecondChecked: Bool = false
    public var isTrigSecondChecked: Bool = false
    public var isHypChecked: Bool = false

    // Programmer state
    public private(set) var currentRadix: NumberBase = .decimal
    public private(set) var bitLength: BitLength = .qword
    public var isBitFlipChecked: Bool = false
    public var bitShiftMode: BitShiftMode = .arithmetic
    public private(set) var hexDisplayValue: String = "0"
    public private(set) var decimalDisplayValue: String = "0"
    public private(set) var octalDisplayValue: String = "0"
    public private(set) var binaryDisplayValue: String = "0"
    public private(set) var binaryDigits: [Bool] = Array(repeating: false, count: 64)

    public var areHexButtonsEnabled: Bool { isProgrammer && currentRadix == .hex }
    public var isDecimalButtonEnabled: Bool { !isProgrammer && !isInError }

    // Memory & History state
    public private(set) var memorizedNumbers: [MemoryItem] = []
    public var isMemoryEmpty: Bool { memorizedNumbers.isEmpty }
    public private(set) var historyItems: [HistoryItem] = []
    public var isHistoryFlyoutOpen: Bool = false
    public var isMemoryFlyoutOpen: Bool = false
    public var selectedDockTab: Int = 0 // 0 = History, 1 = Memory

    // Always-on-top & keyboard visual press feedback
    public var isAlwaysOnTop: Bool = false
    public var litButtonKey: String?
    public var modeAnimationTrigger: Int = 0

    private var isLastOperationHistoryLoad: Bool = false

    public init(resourceProvider: ResourceProvider = .shared) {
        self.res = resourceProvider
        self.engine = CalcManagerBridge(resourceProvider: resourceProvider)
        self.engine.delegate = self
        self.setCalculatorType(.standard)
    }

    public func setCalculatorType(_ mode: ViewMode) {
        guard mode.isCalculatorMode else { return }
        activeMode = mode
        isInError = false
        isSecondChecked = false
        isTrigSecondChecked = false
        isHypChecked = false

        switch mode {
        case .standard:
            if isFToEChecked { isFToEChecked = false }
            engine.setStandardMode()
            currentRadix = .decimal
            engine.setRadix(.decimal)
            engine.setPrecision(Self.standardModePrecision)
            engine.updateMaxIntDigits()
            reloadHistory()

        case .scientific:
            engine.setScientificMode()
            currentRadix = .decimal
            engine.setRadix(.decimal)
            engine.setPrecision(Self.scientificModePrecision)
            // Sync angle mode with engine
            switch angleMode {
            case .degrees: engine.sendCommand(.degree)
            case .radians: engine.sendCommand(.radians)
            case .gradians: engine.sendCommand(.grads)
            }
            reloadHistory()

        case .programmer:
            if isFToEChecked { isFToEChecked = false }
            isBitFlipChecked = false
            engine.setProgrammerMode()
            engine.setPrecision(Self.programmerModePrecision)
            engine.setRadix(currentRadix)
            engine.sendCommand(bitLength.command)
            engine.setMemorizedNumbersString()
            updateProgrammerPanelDisplay()

        default:
            break
        }
        modeAnimationTrigger &+= 1
    }

    public func press(_ command: CalcCommand) {
        if isInError {
            engine.sendCommand(.clear)
            if !isRecoverableCommand(command) {
                return
            }
        }

        if command == .clear || command == .clearEntry {
            if isFToEChecked {
                isFToEChecked = false
            }
        }

        if isLastOperationHistoryLoad && command != .degree && command != .radians && command != .grads {
            isFToEEnabled = true
            isLastOperationHistoryLoad = false
        }

        engine.sendCommand(command)
    }

    public func cycleAngleMode() {
        angleMode = angleMode.next
        press(angleMode.command)
    }

    public func toggleFToE() {
        isFToEChecked.toggle()
        press(.fToE)
    }

    public func cycleBitLength() {
        bitLength = bitLength.next
        press(bitLength.command)
        updateProgrammerPanelDisplay()
    }

    public func setBitLength(_ length: BitLength) {
        bitLength = length
        press(length.command)
        updateProgrammerPanelDisplay()
    }

    public func switchProgrammerBase(_ base: NumberBase) {
        if isInError {
            engine.sendCommand(.clear)
        }
        currentRadix = base
        engine.setRadix(base)
        updateProgrammerPanelDisplay()
    }

    public func toggleBit(at position: Int) {
        guard position >= 0 && position < bitLength.bitCount else { return }
        if isInError {
            engine.sendCommand(.clear)
        }
        engine.sendRawCommand(CalcCommand.binPos(position))
        updateProgrammerPanelDisplay()
    }

    public func isDigitEnabled(_ digit: Int) -> Bool {
        if !isProgrammer { return true }
        switch currentRadix {
        case .binary: return digit <= 1
        case .octal: return digit <= 7
        case .decimal: return digit <= 9
        case .hex: return true
        }
    }

    // MARK: - Memory Commands

    public func memoryStore() {
        guard !isInError else { return }
        engine.memorizeNumber()
    }

    public func memoryRecall(at index: Int = 0) {
        guard !memorizedNumbers.isEmpty, index >= 0, index < memorizedNumbers.count else { return }
        engine.memorizedNumberLoad(UInt32(index))
        isMemoryFlyoutOpen = false
    }

    public func memoryAdd(at index: Int = 0) {
        guard !isInError else { return }
        engine.memorizedNumberAdd(UInt32(index))
    }

    public func memorySubtract(at index: Int = 0) {
        guard !isInError else { return }
        engine.memorizedNumberSubtract(UInt32(index))
    }

    public func memoryClearItem(at index: Int) {
        guard index >= 0, index < memorizedNumbers.count else { return }
        engine.memorizedNumberClear(UInt32(index))
        memorizedNumbers.remove(at: index)
        for i in 0..<memorizedNumbers.count {
            memorizedNumbers[i].position = i
        }
    }

    public func memoryClearAll() {
        engine.memorizedNumberClearAll()
        memorizedNumbers = []
    }

    // MARK: - History Commands

    public func reloadHistory() {
        guard activeMode == .standard || activeMode == .scientific else { return }
        historyItems = engine.getHistoryItems(for: activeMode)
    }

    public func selectHistoryItem(_ item: HistoryItem) {
        _ = engine.loadHistoryItem(at: item.engineIndex, isScientific: isScientific, isFToE: isFToEChecked)
        isFToEEnabled = false
        isLastOperationHistoryLoad = true
        isHistoryFlyoutOpen = false
    }

    public func deleteHistoryItem(_ item: HistoryItem) {
        guard let listIdx = historyItems.firstIndex(of: item) else { return }
        // Engine stores oldest->newest; UI stores newest->oldest
        let engineIdx = UInt32(historyItems.count - 1 - listIdx)
        if engine.removeHistoryItem(at: engineIdx) {
            reloadHistory()
        }
    }

    public func clearHistory() {
        engine.clearHistory()
        historyItems = []
    }

    // MARK: - Copy / Paste

    public func copyDisplay() {
        let raw = isInError ? displayValue : res.removeGroupSeparators(displayValue)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(raw, forType: .string)
    }

    public func copyValue(_ value: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(res.removeGroupSeparators(value), forType: .string)
    }

    public func pasteFromClipboard() {
        guard let str = NSPasteboard.general.string(forType: .string), !str.isEmpty else { return }
        paste(str)
    }

    public func paste(_ text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: res.groupingSeparator, with: "")
            .replacingOccurrences(of: " ", with: "")
        guard !cleaned.isEmpty, cleaned.count <= 512 else { return }

        engine.sendCommand(.clearEntry)
        var sendNegate = false
        var isFirst = true
        var prevWasOp = false
        var negateStack: [Bool] = []
        let chars = Array(cleaned)
        var i = 0

        while i < chars.count {
            let ch = chars[i]
            let mapped = mapCharToCommand(ch)
            if mapped == .none {
                i += 1
                continue
            }

            var sendCmd = true
            var canSendNegate = isDigitCommand(mapped) && mapped != .zero

            if isFirst || prevWasOp {
                isFirst = false
                prevWasOp = false
                if mapped == .subtract {
                    sendNegate = true
                    sendCmd = false
                } else if mapped == .add {
                    sendCmd = false
                }
            }

            switch mapped {
            case .openParenthesis:
                negateStack.append(sendNegate)
                sendNegate = false
            case .closeParenthesis:
                if let saved = negateStack.popLast() {
                    sendNegate = saved
                    canSendNegate = true
                } else {
                    sendCmd = false
                }
            case .add, .subtract, .multiply, .divide:
                prevWasOp = true
            default:
                break
            }

            if sendCmd {
                engine.sendCommand(mapped)
                if sendNegate {
                    if canSendNegate {
                        engine.sendCommand(.sign)
                    }
                    if mapped != .zero && mapped != .decimal {
                        sendNegate = false
                    }
                }
            }

            if mapped == .exp && i + 1 < chars.count {
                let next = mapCharToCommand(chars[i + 1])
                if next == .subtract {
                    engine.sendCommand(.sign)
                    i += 1
                } else if next == .add {
                    i += 1
                }
            }
            i += 1
        }
    }

    public func lightUpButton(_ key: String) {
        litButtonKey = key
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 85_000_000)
            if self?.litButtonKey == key {
                self?.litButtonKey = nil
            }
        }
    }

    // MARK: - CalcManagerBridgeDelegate

    public func onPrimaryDisplay(_ display: String, isError: Bool) {
        var val = display
        if isProgrammer && currentRadix == .binary {
            val = padBinaryString(val)
        }
        displayValue = val
        isInError = isError
        if isProgrammer {
            updateProgrammerPanelDisplay()
        }
    }

    public func onIsInError(_ isError: Bool) {
        isInError = isError
    }

    public func onExpressionDisplay(_ tokens: [ExpressionToken]) {
        expressionTokens = tokens
    }

    public func onParenthesisCount(_ count: UInt32) {
        openParenthesisCount = count
    }

    public func onNoRightParenAdded() {}
    public func onMaxDigitsReached() {}
    public func onBinaryOperatorReceived() {}

    public func onHistoryItemAdded(_ index: UInt32) {
        reloadHistory()
    }

    public func onMemorizedNumbers(_ items: [String]) {
        // Engine returns newest first (or same order as memorizedNumbers vector);
        // match StandardCalculatorViewModel.SetMemorizedNumbers ordering.
        if items.isEmpty {
            memorizedNumbers = []
            return
        }
        memorizedNumbers = items.enumerated().map { idx, val in
            MemoryItem(position: idx, value: val)
        }
    }

    public func onMemoryItemChanged(_ index: UInt32) {
        // Already refreshed by onMemorizedNumbers
    }

    public func onInputChanged() {
        isInputEmpty = engine.isInputEmpty
    }

    // MARK: - Helpers

    private func updateProgrammerPanelDisplay() {
        let precision: Int32 = 64
        if isInError {
            hexDisplayValue = ""
            decimalDisplayValue = ""
            octalDisplayValue = ""
            binaryDisplayValue = ""
            binaryDigits = Array(repeating: false, count: 64)
            return
        }

        let hex = engine.getResultForRadix(16, precision: precision, groupDigits: true)
        if hex.isEmpty {
            hexDisplayValue = displayValue
            decimalDisplayValue = displayValue
            octalDisplayValue = displayValue
            binaryDisplayValue = padBinaryString(displayValue)
        } else {
            hexDisplayValue = hex
            decimalDisplayValue = engine.getResultForRadix(10, precision: precision, groupDigits: true)
            octalDisplayValue = engine.getResultForRadix(8, precision: precision, groupDigits: true)
            binaryDisplayValue = padBinaryString(engine.getResultForRadix(2, precision: precision, groupDigits: true))
        }

        var bits = Array(repeating: false, count: 64)
        let rawBin = engine.getResultForRadix(2, precision: precision, groupDigits: false)
        var idx = 0
        for ch in rawBin.reversed() {
            if idx < 64 {
                bits[idx] = (ch == "1")
                idx += 1
            }
        }
        binaryDigits = bits
    }

    private func padBinaryString(_ binaryString: String) -> String {
        guard !binaryString.isEmpty, binaryString != "0" else { return binaryString }
        let count = binaryString.filter { $0 != " " }.count
        let pad = (4 - (count % 4)) % 4
        return String(repeating: "0", count: pad) + binaryString
    }

    private func isRecoverableCommand(_ cmd: CalcCommand) -> Bool {
        if cmd.rawValue >= CalcCommand.zero.rawValue && cmd.rawValue <= CalcCommand.hexF.rawValue {
            return true
        }
        return cmd == .decimal
    }

    private func isDigitCommand(_ cmd: CalcCommand) -> Bool {
        cmd.rawValue >= CalcCommand.zero.rawValue && cmd.rawValue <= CalcCommand.nine.rawValue
    }

    private func mapCharToCommand(_ ch: Character) -> CalcCommand {
        switch ch {
        case "0": return .zero
        case "1": return .one
        case "2": return .two
        case "3": return .three
        case "4": return .four
        case "5": return .five
        case "6": return .six
        case "7": return .seven
        case "8": return .eight
        case "9": return .nine
        case "+": return .add
        case "-", "−": return .subtract
        case "*", "×": return .multiply
        case "/", "÷": return .divide
        case "=": return .equals
        case "^": return isScientific ? .xPowerY : .none
        case "%": return (isScientific || isProgrammer) ? .mod : .percent
        case "(": return (isScientific || isProgrammer) ? .openParenthesis : .none
        case ")": return (isScientific || isProgrammer) ? .closeParenthesis : .none
        case "a", "A": return isProgrammer ? .hexA : .none
        case "b", "B": return isProgrammer ? .hexB : .none
        case "c", "C": return isProgrammer ? .hexC : .none
        case "d", "D": return isProgrammer ? .hexD : .none
        case "e", "E": return isProgrammer ? .hexE : (isScientific ? .exp : .none)
        case "f", "F": return isProgrammer ? .hexF : .none
        default:
            if String(ch) == res.decimalSeparator || ch == "." {
                return .decimal
            }
            return .none
        }
    }
}
