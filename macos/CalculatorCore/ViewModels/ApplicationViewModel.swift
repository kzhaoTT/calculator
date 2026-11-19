import AppKit
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
public final class ApplicationViewModel {
    private static let modeDefaultsKey = "WindowsCalculatorMac.ViewMode"
    private static let themeDefaultsKey = "WindowsCalculatorMac.ThemePreference"

    public var mode: ViewMode = .standard
    public var previousMode: ViewMode = .standard
    public var isNavPaneOpen: Bool = false
    public var isSettingsOpen: Bool = false
    public var isAlwaysOnTop: Bool = false

    public var themePreference: AppThemePreference = .system {
        didSet {
            UserDefaults.standard.set(themePreference.rawValue, forKey: Self.themeDefaultsKey)
        }
    }

    public let calculatorVM: StandardCalculatorViewModel
    public let converterVM: UnitConverterViewModel
    public let dateCalcVM: DateCalculatorViewModel
    public let graphingVM: GraphingCalculatorViewModel

    /// Callback wired by the macOS Window controller to toggle `NSWindow.level = .floating` and resize for CompactOverlay.
    public var onAlwaysOnTopChanged: ((Bool) -> Void)?

    public init(restoreState: Bool = true) {
        ResourceProvider.registerCalculatorFont()

        self.calculatorVM = StandardCalculatorViewModel()
        self.converterVM = UnitConverterViewModel()
        self.dateCalcVM = DateCalculatorViewModel()
        self.graphingVM = GraphingCalculatorViewModel()

        if restoreState {
            if let savedTheme = UserDefaults.standard.string(forKey: Self.themeDefaultsKey),
               let pref = AppThemePreference(rawValue: savedTheme) {
                self.themePreference = pref
            }
            if let savedModeRaw = UserDefaults.standard.object(forKey: Self.modeDefaultsKey) as? Int,
               let savedMode = ViewMode(rawValue: savedModeRaw) {
                self.selectMode(savedMode)
            } else {
                self.selectMode(.standard)
            }
        } else {
            self.selectMode(.standard)
        }
    }

    public var categoryName: String {
        mode.displayName
    }

    /// True only in Standard mode when not already in Always-on-Top mode (exact match to ApplicationViewModel.cs).
    public var displayNormalAlwaysOnTopOption: Bool {
        mode == .standard && !isAlwaysOnTop
    }

    public var preferredColorScheme: ColorScheme? {
        switch themePreference {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    public func selectMode(_ newMode: ViewMode) {
        if isAlwaysOnTop && newMode != .standard {
            setAlwaysOnTop(false)
        }
        previousMode = mode
        mode = newMode
        isNavPaneOpen = false
        isSettingsOpen = false

        if newMode.isCalculatorMode {
            calculatorVM.setCalculatorType(newMode)
        } else if newMode.isConverterMode {
            converterVM.setMode(newMode)
        }

        UserDefaults.standard.set(newMode.rawValue, forKey: Self.modeDefaultsKey)
    }

    public func toggleAlwaysOnTop() {
        setAlwaysOnTop(!isAlwaysOnTop)
    }

    public func setAlwaysOnTop(_ enabled: Bool) {
        guard isAlwaysOnTop != enabled else { return }
        isAlwaysOnTop = enabled
        calculatorVM.isAlwaysOnTop = enabled
        if enabled {
            isNavPaneOpen = false
            isSettingsOpen = false
            calculatorVM.isHistoryFlyoutOpen = false
            calculatorVM.isMemoryFlyoutOpen = false
        }
        onAlwaysOnTopChanged?(enabled)
    }

    public func openSettings() {
        isNavPaneOpen = false
        isSettingsOpen = true
    }

    public func closeSettings() {
        isSettingsOpen = false
    }

    public func copyCurrentResult() {
        if mode.isCalculatorMode {
            calculatorVM.copyDisplay()
        } else if mode.isConverterMode {
            converterVM.copyActiveValue()
        } else if mode == .date {
            dateCalcVM.copyResult()
        }
    }

    public func pasteIntoCurrentMode() {
        if mode.isCalculatorMode {
            calculatorVM.pasteFromClipboard()
        } else if mode.isConverterMode {
            converterVM.pasteFromClipboard()
        }
    }

    /// Global keyboard shortcut handler matching Windows Calculator's `KeyboardShortcutManager.cs` and `Resources.resw`.
    /// Returns `true` if the event was handled.
    public func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Don't steal keystrokes while typing in a text field (Graphing equations, Graph Settings, etc.)
        if let responder = NSApp.keyWindow?.firstResponder, responder is NSTextView {
            return false
        }

        let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])
        let chars = event.charactersIgnoringModifiers ?? ""
        let lower = chars.lowercased()
        let keyCode = event.keyCode

        // Settings back on Escape
        if isSettingsOpen {
            if keyCode == 53 { // Escape
                closeSettings()
                return true
            }
            return false
        }

        // Close open navigation pane on Escape
        if isNavPaneOpen && keyCode == 53 {
            isNavPaneOpen = false
            return true
        }

        // Mode switching shortcuts: Option/Alt + 1..5 (and Cmd + 1..5 on macOS!)
        if (mods == .option || mods == .command) && !isAlwaysOnTop {
            switch lower {
            case "1": selectMode(.standard); return true
            case "2": selectMode(.scientific); return true
            case "3": selectMode(.graphing); return true
            case "4": selectMode(.programmer); return true
            case "5": selectMode(.date); return true
            default: break
            }
        }

        // Always-on-Top toggle: Option+Up / Option+Down (matching Menu+Up / Menu+Down in MainPage.xaml & TitleBar.xaml)
        if mods == .option && keyCode == 126 && mode == .standard && !isAlwaysOnTop { // Up
            setAlwaysOnTop(true)
            return true
        }
        if mods == .option && keyCode == 125 && isAlwaysOnTop { // Down
            setAlwaysOnTop(false)
            return true
        }

        // Cmd+C / Cmd+V (macOS standard) + Ctrl+C / Ctrl+V
        if mods == .command || mods == .control {
            if lower == "c" { copyCurrentResult(); return true }
            if lower == "v" { pasteIntoCurrentMode(); return true }
        }

        // Control chords (matching Windows Calculator)
        if mods == .control {
            if lower == "e" && !isAlwaysOnTop { selectMode(.date); return true }
            if mode.isCalculatorMode {
                switch lower {
                case "h":
                    if !isAlwaysOnTop && !calculatorVM.isProgrammer {
                        calculatorVM.isHistoryFlyoutOpen.toggle()
                    }
                    return true
                case "m": calculatorVM.memoryStore(); return true
                case "p": calculatorVM.memoryAdd(); return true
                case "q": calculatorVM.memorySubtract(); return true
                case "r": calculatorVM.memoryRecall(); return true
                case "l": calculatorVM.memoryClearAll(); return true
                default: break
                }
            }
        }

        // Ctrl+Shift+D: Clear History
        if mods == [.control, .shift] && lower == "d" && mode.isCalculatorMode && !isAlwaysOnTop {
            calculatorVM.clearHistory()
            return true
        }

        // Calculator modes keyboard input
        if mode.isCalculatorMode {
            return handleCalculatorKey(keyCode: keyCode, chars: event.characters ?? "", lower: lower, mods: mods)
        }

        // Unit Converter keyboard input
        if mode.isConverterMode {
            return handleConverterKey(keyCode: keyCode, chars: event.characters ?? "", lower: lower, mods: mods)
        }

        return false
    }

    private func handleCalculatorKey(keyCode: UInt16, chars: String, lower: String, mods: NSEvent.ModifierFlags) -> Bool {
        // Return / Enter -> Equals
        if keyCode == 36 || keyCode == 76 {
            calculatorVM.lightUpButton("equals")
            calculatorVM.press(.equals)
            return true
        }
        // Escape -> Clear
        if keyCode == 53 {
            calculatorVM.lightUpButton("clear")
            calculatorVM.press(.clear)
            return true
        }
        // Delete / Backspace -> Backspace
        if keyCode == 51 {
            calculatorVM.lightUpButton("backspace")
            calculatorVM.press(.backspace)
            return true
        }
        // Forward Delete -> ClearEntry
        if keyCode == 117 {
            calculatorVM.lightUpButton("clearEntry")
            calculatorVM.press(.clearEntry)
            return true
        }
        // F9 -> Negate
        if keyCode == 101 {
            calculatorVM.lightUpButton("negate")
            calculatorVM.press(.sign)
            return true
        }

        guard mods.isEmpty || mods == .shift else { return false }

        if let ch = chars.first {
            switch ch {
            case "0"..."9":
                let d = Int(String(ch))!
                if calculatorVM.isDigitEnabled(d) {
                    calculatorVM.lightUpButton("num\(d)")
                    calculatorVM.press(CalcCommand.digit(d))
                }
                return true
            case ".", ",":
                if String(ch) == ResourceProvider.shared.decimalSeparator || ch == "." {
                    if calculatorVM.isDecimalButtonEnabled {
                        calculatorVM.lightUpButton("decimal")
                        calculatorVM.press(.decimal)
                    }
                    return true
                }
            case "+": calculatorVM.lightUpButton("add"); calculatorVM.press(.add); return true
            case "-": calculatorVM.lightUpButton("subtract"); calculatorVM.press(.subtract); return true
            case "*": calculatorVM.lightUpButton("multiply"); calculatorVM.press(.multiply); return true
            case "/": calculatorVM.lightUpButton("divide"); calculatorVM.press(.divide); return true
            case "=": calculatorVM.lightUpButton("equals"); calculatorVM.press(.equals); return true
            case "%":
                if calculatorVM.isStandard {
                    calculatorVM.lightUpButton("percent"); calculatorVM.press(.percent); return true
                } else {
                    calculatorVM.lightUpButton("mod"); calculatorVM.press(.mod); return true
                }
            case "(" where !calculatorVM.isStandard:
                calculatorVM.lightUpButton("openParen"); calculatorVM.press(.openParenthesis); return true
            case ")" where !calculatorVM.isStandard:
                calculatorVM.lightUpButton("closeParen"); calculatorVM.press(.closeParenthesis); return true
            case "^" where calculatorVM.isScientific:
                calculatorVM.lightUpButton("xPowerY"); calculatorVM.press(.xPowerY); return true
            case "!" where calculatorVM.isScientific:
                calculatorVM.lightUpButton("factorial"); calculatorVM.press(.factorial); return true
            case "@" where !calculatorVM.isProgrammer:
                calculatorVM.lightUpButton("sqrt"); calculatorVM.press(.sqrt); return true
            case "|" where calculatorVM.isScientific:
                calculatorVM.lightUpButton("abs"); calculatorVM.press(.abs); return true
            default:
                break
            }
        }

        // Letter shortcuts (matching Windows Calculator)
        if calculatorVM.isProgrammer {
            switch lower {
            case "a" where calculatorVM.areHexButtonsEnabled: calculatorVM.lightUpButton("hexA"); calculatorVM.press(.hexA); return true
            case "b" where calculatorVM.areHexButtonsEnabled: calculatorVM.lightUpButton("hexB"); calculatorVM.press(.hexB); return true
            case "c" where calculatorVM.areHexButtonsEnabled: calculatorVM.lightUpButton("hexC"); calculatorVM.press(.hexC); return true
            case "d" where calculatorVM.areHexButtonsEnabled: calculatorVM.lightUpButton("hexD"); calculatorVM.press(.hexD); return true
            case "e" where calculatorVM.areHexButtonsEnabled: calculatorVM.lightUpButton("hexE"); calculatorVM.press(.hexE); return true
            case "f" where calculatorVM.areHexButtonsEnabled: calculatorVM.lightUpButton("hexF"); calculatorVM.press(.hexF); return true
            case "~": calculatorVM.press(.bitwiseNot); return true
            case "&": calculatorVM.press(.bitwiseAnd); return true
            case "|": calculatorVM.press(.bitwiseOr); return true
            case "<": calculatorVM.press(calculatorVM.bitShiftMode.leftCommand); return true
            case ">": calculatorVM.press(calculatorVM.bitShiftMode.rightCommand); return true
            default: break
            }
        } else {
            switch lower {
            case "r": calculatorVM.lightUpButton("invert"); calculatorVM.press(.invert); return true
            case "q": calculatorVM.lightUpButton("xPower2"); calculatorVM.press(.xPower2); return true
            case "p" where calculatorVM.isScientific: calculatorVM.lightUpButton("pi"); calculatorVM.press(.pi); return true
            case "e" where calculatorVM.isScientific:
                if mods == .shift { calculatorVM.lightUpButton("euler"); calculatorVM.press(.euler) }
                else { calculatorVM.lightUpButton("exp"); calculatorVM.press(.exp) }
                return true
            case "l" where calculatorVM.isScientific: calculatorVM.lightUpButton("log"); calculatorVM.press(.logBase10); return true
            case "n" where calculatorVM.isScientific: calculatorVM.lightUpButton("ln"); calculatorVM.press(.logBaseE); return true
            case "s" where calculatorVM.isScientific:
                calculatorVM.press(mods == .shift ? .invSin : .sin); return true
            case "o" where calculatorVM.isScientific:
                calculatorVM.press(mods == .shift ? .invCos : .cos); return true
            case "t" where calculatorVM.isScientific:
                calculatorVM.press(mods == .shift ? .invTan : .tan); return true
            case "v" where calculatorVM.isScientific:
                calculatorVM.toggleFToE(); return true
            default: break
            }
        }
        return false
    }

    private func handleConverterKey(keyCode: UInt16, chars: String, lower: String, mods: NSEvent.ModifierFlags) -> Bool {
        if keyCode == 53 || keyCode == 117 { // Esc / Delete -> CE
            converterVM.lightUpButton("clear")
            converterVM.sendCommand(.clear)
            return true
        }
        if keyCode == 51 { // Backspace
            converterVM.lightUpButton("backspace")
            converterVM.sendCommand(.backspace)
            return true
        }
        if keyCode == 101 { // F9 -> Negate
            if converterVM.currentCategory.supportsNegative {
                converterVM.lightUpButton("negate")
                converterVM.sendCommand(.negate)
            }
            return true
        }
        guard mods.isEmpty || mods == .shift, let ch = chars.first else { return false }
        switch ch {
        case "0": converterVM.lightUpButton("num0"); converterVM.sendCommand(.zero); return true
        case "1": converterVM.lightUpButton("num1"); converterVM.sendCommand(.one); return true
        case "2": converterVM.lightUpButton("num2"); converterVM.sendCommand(.two); return true
        case "3": converterVM.lightUpButton("num3"); converterVM.sendCommand(.three); return true
        case "4": converterVM.lightUpButton("num4"); converterVM.sendCommand(.four); return true
        case "5": converterVM.lightUpButton("num5"); converterVM.sendCommand(.five); return true
        case "6": converterVM.lightUpButton("num6"); converterVM.sendCommand(.six); return true
        case "7": converterVM.lightUpButton("num7"); converterVM.sendCommand(.seven); return true
        case "8": converterVM.lightUpButton("num8"); converterVM.sendCommand(.eight); return true
        case "9": converterVM.lightUpButton("num9"); converterVM.sendCommand(.nine); return true
        case ".", ",":
            if String(ch) == ResourceProvider.shared.decimalSeparator || ch == "." {
                converterVM.lightUpButton("decimal")
                converterVM.sendCommand(.decimal)
                return true
            }
        case "-":
            if converterVM.currentCategory.supportsNegative {
                converterVM.lightUpButton("negate")
                converterVM.sendCommand(.negate)
                return true
            }
        default: break
        }
        return false
    }
}
