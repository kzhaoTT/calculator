import SwiftUI

/// Exact port of `src/Calculator/Views/CalculatorStandardOperators.xaml` & `NumberPad.xaml`.
public struct StandardOperatorsView: View {
    let vm: StandardCalculatorViewModel
    let availableHeight: CGFloat
    let availableWidth: CGFloat

    public init(vm: StandardCalculatorViewModel, availableHeight: CGFloat, availableWidth: CGFloat) {
        self.vm = vm
        self.availableHeight = availableHeight
        self.availableWidth = availableWidth
    }

    /// Matches `ShowStandardFunctions` vs `HideStandardFunctions` AdaptiveTrigger (MinWindowHeight=394) in Standard mode.
    private var showStandardFunctions: Bool {
        !vm.isAlwaysOnTop || availableHeight >= 210
    }

    private var numFontSize: CGFloat {
        if availableWidth >= 780 && availableHeight >= 600 { return 38 }
        if availableWidth >= 468 && availableHeight >= 360 { return 24 }
        if availableHeight >= 180 { return 18 }
        return 14
    }

    private var opFontSize: CGFloat {
        if availableWidth >= 780 && availableHeight >= 600 { return 34 }
        if availableWidth >= 468 && availableHeight >= 360 { return 20 }
        if availableHeight >= 180 { return 16 }
        return 12
    }

    private var textOpFontSize: CGFloat {
        if availableWidth >= 780 && availableHeight >= 600 { return 28 }
        if availableWidth >= 468 && availableHeight >= 360 { return 18 }
        if availableHeight >= 180 { return 14 }
        return 12
    }

    public var body: some View {
        let disabledOnError = !vm.isInError
        let decSep = ResourceProvider.shared.decimalSeparator

        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            if showStandardFunctions {
                // Row 0: %  CE  C  ⌫
                GridRow {
                    glyphButton(CalcGlyph.percent, variant: .operator, key: "percent", enabled: disabledOnError, cmd: .percent)
                    textButton("CE", variant: .operator, key: "clearEntry", enabled: true, cmd: .clearEntry)
                    textButton("C", variant: .operator, key: "clear", enabled: true, cmd: .clear)
                    glyphButton(CalcGlyph.backspace, variant: .operator, key: "backspace", enabled: true, cmd: .backspace)
                }

                // Row 1: 1/x  x²  ²√x  ÷
                GridRow {
                    glyphButton(CalcGlyph.invert, variant: .operator, key: "invert", enabled: disabledOnError, cmd: .invert)
                    glyphButton(CalcGlyph.xPower2, variant: .operator, key: "xPower2", enabled: disabledOnError, cmd: .xPower2)
                    glyphButton(CalcGlyph.sqrt, variant: .operator, key: "sqrt", enabled: disabledOnError, cmd: .sqrt)
                    glyphButton(CalcGlyph.divide, variant: .operator, key: "divide", enabled: disabledOnError, cmd: .divide)
                }
            } else {
                // Compact Always-on-Top Row 0: CE  C  ⌫  ÷
                GridRow {
                    textButton("CE", variant: .operator, key: "clearEntry", enabled: true, cmd: .clearEntry)
                    textButton("C", variant: .operator, key: "clear", enabled: true, cmd: .clear)
                    glyphButton(CalcGlyph.backspace, variant: .operator, key: "backspace", enabled: true, cmd: .backspace)
                    glyphButton(CalcGlyph.divide, variant: .operator, key: "divide", enabled: disabledOnError, cmd: .divide)
                }
            }

            // Row 2: 7  8  9  ×
            GridRow {
                numButton(7)
                numButton(8)
                numButton(9)
                glyphButton(CalcGlyph.multiply, variant: .operator, key: "multiply", enabled: disabledOnError, cmd: .multiply)
            }

            // Row 3: 4  5  6  −
            GridRow {
                numButton(4)
                numButton(5)
                numButton(6)
                glyphButton(CalcGlyph.subtract, variant: .operator, key: "subtract", enabled: disabledOnError, cmd: .subtract)
            }

            // Row 4: 1  2  3  +
            GridRow {
                numButton(1)
                numButton(2)
                numButton(3)
                glyphButton(CalcGlyph.add, variant: .operator, key: "add", enabled: disabledOnError, cmd: .add)
            }

            // Row 5: +/-  0  .  =
            GridRow {
                glyphButton(CalcGlyph.negate, variant: .numeric, key: "negate", enabled: disabledOnError, cmd: .sign)
                numButton(0)
                FluentCalcButton(
                    variant: .numeric,
                    isEnabled: disabledOnError,
                    isLit: vm.litButtonKey == "decimal",
                    action: { vm.press(.decimal) }
                ) {
                    Text(decSep)
                        .font(.system(size: numFontSize, weight: .regular))
                }
                glyphButton(CalcGlyph.equals, variant: .accent, key: "equals", enabled: true, cmd: .equals)
            }
        }
    }

    private func numButton(_ digit: Int) -> some View {
        FluentCalcButton(
            variant: .numeric,
            isEnabled: true,
            isLit: vm.litButtonKey == "num\(digit)",
            action: { vm.press(CalcCommand.digit(digit)) }
        ) {
            Text("\(digit)")
                .font(.system(size: numFontSize, weight: .regular))
        }
    }

    private func textButton(_ title: String, variant: CalcButtonVariant, key: String, enabled: Bool, cmd: CalcCommand) -> some View {
        FluentCalcButton(
            variant: variant,
            isEnabled: enabled,
            isLit: vm.litButtonKey == key,
            action: { vm.press(cmd) }
        ) {
            Text(title)
                .font(.system(size: textOpFontSize, weight: .regular))
        }
    }

    private func glyphButton(_ glyph: String, variant: CalcButtonVariant, key: String, enabled: Bool, cmd: CalcCommand) -> some View {
        FluentCalcButton(
            variant: variant,
            isEnabled: enabled,
            isLit: vm.litButtonKey == key,
            action: { vm.press(cmd) }
        ) {
            CalcGlyphText(glyph, size: opFontSize)
        }
    }
}
