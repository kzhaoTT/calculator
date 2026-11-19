import CCalcManager
import Foundation

@MainActor
public protocol CalcManagerBridgeDelegate: AnyObject {
    func onPrimaryDisplay(_ display: String, isError: Bool)
    func onIsInError(_ isError: Bool)
    func onExpressionDisplay(_ tokens: [ExpressionToken])
    func onParenthesisCount(_ count: UInt32)
    func onNoRightParenAdded()
    func onMaxDigitsReached()
    func onBinaryOperatorReceived()
    func onHistoryItemAdded(_ index: UInt32)
    func onMemorizedNumbers(_ items: [String])
    func onMemoryItemChanged(_ index: UInt32)
    func onInputChanged()
}

/// Thin Swift wrapper around the unmodified C++ `CalculationManager::CalculatorManager` via `CCalcManager`.
@MainActor
public final class CalcManagerBridge {
    private nonisolated(unsafe) var handle: CMCalculatorRef?
    public weak var delegate: CalcManagerBridgeDelegate?
    private let resourceProvider: ResourceProvider

    public init(resourceProvider: ResourceProvider = .shared) {
        self.resourceProvider = resourceProvider
        let context = Unmanaged.passUnretained(self).toOpaque()

        var callbacks = CMCalculatorCallbacks()
        callbacks.context = context

        callbacks.onPrimaryDisplay = { ctx, displayPtr, isError in
            guard let ctx else { return }
            let str = displayPtr.map { String(cString: $0) } ?? ""
            MainActor.assumeIsolated {
                let bridge = Unmanaged<CalcManagerBridge>.fromOpaque(ctx).takeUnretainedValue()
                bridge.delegate?.onPrimaryDisplay(str, isError: isError)
            }
        }

        callbacks.onIsInError = { ctx, isError in
            guard let ctx else { return }
            MainActor.assumeIsolated {
                let bridge = Unmanaged<CalcManagerBridge>.fromOpaque(ctx).takeUnretainedValue()
                bridge.delegate?.onIsInError(isError)
            }
        }

        callbacks.onExpressionDisplay = { ctx, tokensPtr, count in
            guard let ctx else { return }
            var result: [ExpressionToken] = []
            if let tokensPtr, count > 0 {
                result.reserveCapacity(count)
                for i in 0..<count {
                    let raw = tokensPtr[i]
                    let val = raw.value.map { String(cString: $0) } ?? ""
                    let type = ExpressionTokenType(rawValue: Int32(raw.tokenType.rawValue)) ?? .operator
                    result.append(ExpressionToken(id: i, token: val, commandIndex: raw.commandIndex, type: type))
                }
            }
            MainActor.assumeIsolated {
                let bridge = Unmanaged<CalcManagerBridge>.fromOpaque(ctx).takeUnretainedValue()
                bridge.delegate?.onExpressionDisplay(result)
            }
        }

        callbacks.onParenthesisCount = { ctx, count in
            guard let ctx else { return }
            MainActor.assumeIsolated {
                let bridge = Unmanaged<CalcManagerBridge>.fromOpaque(ctx).takeUnretainedValue()
                bridge.delegate?.onParenthesisCount(count)
            }
        }

        callbacks.onNoRightParenAdded = { ctx in
            guard let ctx else { return }
            MainActor.assumeIsolated {
                let bridge = Unmanaged<CalcManagerBridge>.fromOpaque(ctx).takeUnretainedValue()
                bridge.delegate?.onNoRightParenAdded()
            }
        }

        callbacks.onMaxDigitsReached = { ctx in
            guard let ctx else { return }
            MainActor.assumeIsolated {
                let bridge = Unmanaged<CalcManagerBridge>.fromOpaque(ctx).takeUnretainedValue()
                bridge.delegate?.onMaxDigitsReached()
            }
        }

        callbacks.onBinaryOperatorReceived = { ctx in
            guard let ctx else { return }
            MainActor.assumeIsolated {
                let bridge = Unmanaged<CalcManagerBridge>.fromOpaque(ctx).takeUnretainedValue()
                bridge.delegate?.onBinaryOperatorReceived()
            }
        }

        callbacks.onHistoryItemAdded = { ctx, idx in
            guard let ctx else { return }
            MainActor.assumeIsolated {
                let bridge = Unmanaged<CalcManagerBridge>.fromOpaque(ctx).takeUnretainedValue()
                bridge.delegate?.onHistoryItemAdded(idx)
            }
        }

        callbacks.onMemorizedNumbers = { ctx, itemsPtr, count in
            guard let ctx else { return }
            var items: [String] = []
            if let itemsPtr, count > 0 {
                items.reserveCapacity(count)
                for i in 0..<count {
                    if let cstr = itemsPtr[i] {
                        items.append(String(cString: cstr))
                    }
                }
            }
            MainActor.assumeIsolated {
                let bridge = Unmanaged<CalcManagerBridge>.fromOpaque(ctx).takeUnretainedValue()
                bridge.delegate?.onMemorizedNumbers(items)
            }
        }

        callbacks.onMemoryItemChanged = { ctx, idx in
            guard let ctx else { return }
            MainActor.assumeIsolated {
                let bridge = Unmanaged<CalcManagerBridge>.fromOpaque(ctx).takeUnretainedValue()
                bridge.delegate?.onMemoryItemChanged(idx)
            }
        }

        callbacks.onInputChanged = { ctx in
            guard let ctx else { return }
            MainActor.assumeIsolated {
                let bridge = Unmanaged<CalcManagerBridge>.fromOpaque(ctx).takeUnretainedValue()
                bridge.delegate?.onInputChanged()
            }
        }

        callbacks.getEngineString = { ctx, idPtr, outBuf, outBufSize in
            guard let ctx, let idPtr else { return 0 }
            let id = String(cString: idPtr)
            let val = MainActor.assumeIsolated {
                let bridge = Unmanaged<CalcManagerBridge>.fromOpaque(ctx).takeUnretainedValue()
                return bridge.resourceProvider.engineString(id)
            }
            let utf8 = Array(val.utf8)
            if let outBuf, outBufSize > 0 {
                let copyCount = min(utf8.count, outBufSize - 1)
                if copyCount > 0 {
                    _ = utf8.withUnsafeBytes { rawBuf in
                        memcpy(outBuf, rawBuf.baseAddress!, copyCount)
                    }
                }
                outBuf[copyCount] = 0
            }
            return utf8.count
        }

        self.handle = cm_calc_create(callbacks)
    }

    deinit {
        if let handle {
            cm_calc_destroy(handle)
        }
    }

    public func reset(clearMemory: Bool = true) { cm_calc_reset(handle, clearMemory) }
    public func setStandardMode() { cm_calc_set_standard_mode(handle) }
    public func setScientificMode() { cm_calc_set_scientific_mode(handle) }
    public func setProgrammerMode() { cm_calc_set_programmer_mode(handle) }
    public func sendCommand(_ command: CalcCommand) { cm_calc_send_command(handle, command.rawValue) }
    public func sendRawCommand(_ command: Int32) { cm_calc_send_command(handle, command) }
    public func setRadix(_ base: NumberBase) { cm_calc_set_radix(handle, base.rawValue) }
    public func setPrecision(_ precision: Int32) { cm_calc_set_precision(handle, precision) }
    public func updateMaxIntDigits() { cm_calc_update_max_int_digits(handle) }

    public func getResultForRadix(_ radix: UInt32, precision: Int32, groupDigits: Bool) -> String {
        guard let ptr = cm_calc_get_result_for_radix(handle, radix, precision, groupDigits) else { return "" }
        defer { cm_string_free(ptr) }
        return String(cString: ptr)
    }

    public var isInputEmpty: Bool { cm_calc_is_input_empty(handle) }
    public var currentDegreeMode: Int32 { cm_calc_get_current_degree_mode(handle) }

    public func memorizeNumber() { cm_calc_memorize_number(handle) }
    public func memorizedNumberLoad(_ idx: UInt32) { cm_calc_memorized_load(handle, idx) }
    public func memorizedNumberAdd(_ idx: UInt32) { cm_calc_memorized_add(handle, idx) }
    public func memorizedNumberSubtract(_ idx: UInt32) { cm_calc_memorized_subtract(handle, idx) }
    public func memorizedNumberClear(_ idx: UInt32) { cm_calc_memorized_clear(handle, idx) }
    public func memorizedNumberClearAll() { cm_calc_memorized_clear_all(handle) }
    public func setMemorizedNumbersString() { cm_calc_set_memorized_numbers_string(handle) }

    public var historyCount: Int { cm_calc_history_count(handle) }
    public var maxHistorySize: Int { cm_calc_history_max_size(handle) }

    public func getHistoryItem(at index: UInt32) -> (expression: String, result: String)? {
        var exprPtr: UnsafeMutablePointer<CChar>?
        var resPtr: UnsafeMutablePointer<CChar>?
        guard cm_calc_history_get(handle, index, &exprPtr, &resPtr) else { return nil }
        defer {
            cm_string_free(exprPtr)
            cm_string_free(resPtr)
        }
        return (exprPtr.map { String(cString: $0) } ?? "", resPtr.map { String(cString: $0) } ?? "")
    }

    public func getHistoryItems(for mode: ViewMode) -> [HistoryItem] {
        let modeInt: Int32 = (mode == .scientific) ? 1 : 0
        let count = cm_calc_history_count_for_mode(handle, modeInt)
        guard count > 0 else { return [] }
        var items: [HistoryItem] = []
        for i in stride(from: count - 1, through: 0, by: -1) {
            var exprPtr: UnsafeMutablePointer<CChar>?
            var resPtr: UnsafeMutablePointer<CChar>?
            if cm_calc_history_get_for_mode(handle, modeInt, UInt32(i), &exprPtr, &resPtr) {
                let expr = exprPtr.map { String(cString: $0) } ?? ""
                let res = resPtr.map { String(cString: $0) } ?? ""
                cm_string_free(exprPtr)
                cm_string_free(resPtr)
                items.append(HistoryItem(expression: expr, result: res, engineIndex: UInt32(i)))
            }
        }
        return items
    }

    public func loadHistoryItem(at index: UInt32, isScientific: Bool, isFToE: Bool) -> Bool {
        cm_calc_history_load(handle, index, isScientific, isFToE)
    }

    public func removeHistoryItem(at index: UInt32) -> Bool {
        cm_calc_history_remove(handle, index)
    }

    public func clearHistory() {
        cm_calc_history_clear(handle)
    }
}
