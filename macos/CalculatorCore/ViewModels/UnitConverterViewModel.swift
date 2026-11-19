import AppKit
import Foundation
import Observation

@MainActor
@Observable
public final class UnitConverterViewModel: UnitConverterBridgeDelegate {
    private let catalog: UnitConverterDataCatalog
    private let bridge: UnitConverterBridge
    private let res: ResourceProvider

    public private(set) var currentMode: ViewMode = .length
    public private(set) var currentCategory: ConverterCategory
    public private(set) var units: [ConverterUnit] = []

    public var unit1: ConverterUnit?
    public var unit2: ConverterUnit?
    public private(set) var value1: String = "0"
    public private(set) var value2: String = "0"
    public private(set) var value1Active: Bool = true
    public var value2Active: Bool { !value1Active }

    public private(set) var supplementaryResults: [SupplementaryResultItem] = []

    // Currency-specific display properties
    public var isCurrencyCategory: Bool { currentMode == .currency }
    public private(set) var currencySymbol1: String = ""
    public private(set) var currencySymbol2: String = ""
    public private(set) var currencyRatioEquality: String = ""
    public private(set) var currencyTimestamp: String = ""
    public private(set) var isRefreshingCurrency: Bool = false

    public var litButtonKey: String?
    public var modeAnimationTrigger: Int = 0

    private var rawValueFrom: String = "0"
    private var rawValueTo: String = "0"
    private var lastCurrencyUpdate: Date = Date()

    public init(regionCode: String = ResourceProvider.shared.regionCode, resourceProvider: ResourceProvider = .shared) {
        self.res = resourceProvider
        self.catalog = UnitConverterDataCatalog.build(regionCode: regionCode, res: resourceProvider)
        self.bridge = UnitConverterBridge(catalog: self.catalog)
        self.currentCategory = self.catalog.categories.first(where: { $0.mode == .length }) ?? self.catalog.categories[0]
        self.bridge.delegate = self
        self.setMode(.length)
    }

    public func setMode(_ mode: ViewMode) {
        guard mode.isConverterMode,
              let category = catalog.categories.first(where: { $0.mode == mode })
        else { return }

        currentMode = mode
        currentCategory = category
        let allUnits = catalog.unitsByCategory[category.id] ?? []
        // Non-whimsical units appear in dropdowns (matching Windows Calculator)
        units = allUnits.filter { !$0.isWhimsical }

        let (fromId, toId) = bridge.setCategory(category.id)
        let selected1 = units.first(where: { $0.id == fromId }) ?? units.first
        let selected2 = units.first(where: { $0.id == toId }) ?? units.dropFirst().first ?? units.first

        unit1 = selected1
        unit2 = selected2
        value1Active = true

        if let u1 = selected1, let u2 = selected2 {
            bridge.setUnitTypes(fromUnitId: u1.id, toUnitId: u2.id)
        }
        updateCurrencyMetadata()
        modeAnimationTrigger &+= 1
    }

    public func selectUnit1(_ unit: ConverterUnit) {
        unit1 = unit
        applyCurrentUnitSelection()
    }

    public func selectUnit2(_ unit: ConverterUnit) {
        unit2 = unit
        applyCurrentUnitSelection()
    }

    private func applyCurrentUnitSelection() {
        guard let u1 = unit1, let u2 = unit2 else { return }
        if value1Active {
            bridge.setUnitTypes(fromUnitId: u1.id, toUnitId: u2.id)
        } else {
            bridge.setUnitTypes(fromUnitId: u2.id, toUnitId: u1.id)
        }
        updateCurrencyMetadata()
    }

    public func activateValue1() {
        guard !value1Active else { return }
        value1Active = true
        bridge.switchActive(newValue: rawValueTo)
        updateCurrencyMetadata()
    }

    public func activateValue2() {
        guard value1Active else { return }
        value1Active = false
        bridge.switchActive(newValue: rawValueTo)
        updateCurrencyMetadata()
    }

    public func sendCommand(_ command: UnitConverterCommand) {
        bridge.sendCommand(command)
    }

    public func refreshCurrencyRates() {
        isRefreshingCurrency = true
        lastCurrencyUpdate = Date()
        updateCurrencyMetadata()
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            self?.isRefreshingCurrency = false
        }
    }

    public func copyActiveValue() {
        let val = value1Active ? value1 : value2
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(res.removeGroupSeparators(val), forType: .string)
    }

    public func copyValue(_ value: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(res.removeGroupSeparators(value), forType: .string)
    }

    public func pasteFromClipboard() {
        guard let str = NSPasteboard.general.string(forType: .string) else { return }
        let cleaned = str.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: res.groupingSeparator, with: "")
        guard Double(cleaned) != nil else { return }
        bridge.sendCommand(.clear)
        var isNeg = false
        for ch in cleaned {
            switch ch {
            case "-": isNeg = true
            case "0": bridge.sendCommand(.zero)
            case "1": bridge.sendCommand(.one)
            case "2": bridge.sendCommand(.two)
            case "3": bridge.sendCommand(.three)
            case "4": bridge.sendCommand(.four)
            case "5": bridge.sendCommand(.five)
            case "6": bridge.sendCommand(.six)
            case "7": bridge.sendCommand(.seven)
            case "8": bridge.sendCommand(.eight)
            case "9": bridge.sendCommand(.nine)
            case ".": bridge.sendCommand(.decimal)
            default: break
            }
        }
        if isNeg && currentCategory.supportsNegative {
            bridge.sendCommand(.negate)
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

    // MARK: - UnitConverterBridgeDelegate

    public func onDisplayUpdated(from: String, to: String) {
        rawValueFrom = from
        rawValueTo = to
        let formattedFrom = formatDisplayNumber(from, isCurrency: isCurrencyCategory, isSource: true)
        let formattedTo = formatDisplayNumber(to, isCurrency: isCurrencyCategory, isSource: false)
        if value1Active {
            value1 = formattedFrom
            value2 = formattedTo
        } else {
            value2 = formattedFrom
            value1 = formattedTo
        }
    }

    public func onSuggestedValuesUpdated(_ values: [SupplementaryResultItem]) {
        if isCurrencyCategory {
            supplementaryResults = []
        } else {
            // Match Windows Calculator: top 2-3 regular suggested units + the whimsical Delighter unit at the end
            let regular = values.filter { !$0.isWhimsical }.prefix(3)
            let whimsical = values.filter { $0.isWhimsical }.prefix(1)
            supplementaryResults = Array(regular) + Array(whimsical)
        }
    }

    public func onMaxDigitsReached() {}

    // MARK: - Formatting & Currency Metadata

    private func updateCurrencyMetadata() {
        guard isCurrencyCategory, let u1 = unit1, let u2 = unit2 else {
            currencySymbol1 = ""
            currencySymbol2 = ""
            currencyRatioEquality = ""
            currencyTimestamp = ""
            return
        }
        currencySymbol1 = u1.currencySymbol
        currencySymbol2 = u2.currencySymbol

        let fromUnit = value1Active ? u1 : u2
        let toUnit = value1Active ? u2 : u1
        let fromRate = catalog.currencyRatiosByCode[fromUnit.currencyCode] ?? 1.0
        let toRate = catalog.currencyRatiosByCode[toUnit.currencyCode] ?? 1.0
        let ratio = fromRate > 0 ? toRate / fromRate : 1.0
        let formattedRatio = String(format: "%.4f", ratio)
        currencyRatioEquality = "1 \(fromUnit.currencyCode) = \(formattedRatio) \(toUnit.currencyCode)"

        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        let timeStr = df.string(from: lastCurrencyUpdate)
        let fmt = res.string("CurrencyTimestampFormat", fallback: "Updated %1")
        currencyTimestamp = fmt.replacingOccurrences(of: "%1", with: timeStr)
    }

    private func formatDisplayNumber(_ raw: String, isCurrency: Bool, isSource: Bool) -> String {
        guard !raw.isEmpty else { return "0" }
        // Preserve scientific notation from C++ engine
        if raw.contains("e") || raw.contains("E") {
            return raw
        }
        // For currency target value, format with 2 decimal places when non-integer or fractional
        if isCurrency && !isSource, let num = Double(raw) {
            let nf = NumberFormatter()
            nf.numberStyle = .decimal
            nf.maximumFractionDigits = 2
            nf.minimumFractionDigits = (num == num.rounded() && abs(num) < 1e12) ? 0 : 2
            if let s = nf.string(from: NSNumber(value: num)) {
                return s
            }
        }
        // Add grouping separators to integer part while preserving trailing decimal point / zeros typed by user
        let isNeg = raw.hasPrefix("-")
        let body = isNeg ? String(raw.dropFirst()) : raw
        let parts = body.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let intPart = String(parts[0])
        let groupedInt = groupDigits(intPart)
        var result = (isNeg ? "-" : "") + groupedInt
        if parts.count == 2 {
            result += res.decimalSeparator + String(parts[1])
        }
        return result
    }

    private func groupDigits(_ intStr: String) -> String {
        guard intStr.count > 3 else { return intStr }
        let sep = res.groupingSeparator
        var chars: [Character] = []
        for (idx, ch) in intStr.reversed().enumerated() {
            if idx > 0 && idx % 3 == 0 {
                chars.append(contentsOf: sep.reversed())
            }
            chars.append(ch)
        }
        return String(chars.reversed())
    }
}
