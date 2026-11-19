import SwiftUI

/// Exact port of `src/Calculator/Views/CalculatorScientificAngleButtons.xaml`.
public struct ScientificAngleButtonsView: View {
    let vm: StandardCalculatorViewModel

    public init(vm: StandardCalculatorViewModel) {
        self.vm = vm
    }

    public var body: some View {
        HStack(spacing: 2) {
            FluentCalcButton(
                variant: .subtle,
                isEnabled: !vm.isInError,
                action: { vm.cycleAngleMode() }
            ) {
                Text(vm.angleMode.label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .frame(maxWidth: 68)

            IndicatorToggleButton(
                isSelected: vm.isFToEChecked,
                isEnabled: !vm.isInError && vm.isFToEEnabled,
                action: { vm.toggleFToE() }
            ) {
                Text("F-E")
                    .font(.system(size: 13, weight: .semibold))
            }
            .frame(maxWidth: 68)

            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

/// Exact port of `src/Calculator/Views/CalculatorScientificOperators.xaml`.
public struct ScientificOperatorsView: View {
    @Bindable var vm: StandardCalculatorViewModel
    let availableHeight: CGFloat
    let availableWidth: CGFloat

    @State private var showTrigPopover = false
    @State private var showFuncPopover = false

    public init(vm: StandardCalculatorViewModel, availableHeight: CGFloat, availableWidth: CGFloat) {
        self.vm = vm
        self.availableHeight = availableHeight
        self.availableWidth = availableWidth
    }

    private var numFontSize: CGFloat {
        if availableWidth >= 878 && availableHeight >= 600 { return 34 }
        if availableWidth >= 527 && availableHeight >= 400 { return 22 }
        return 18
    }

    private var glyphFontSize: CGFloat {
        if availableWidth >= 878 && availableHeight >= 600 { return 24 }
        if availableWidth >= 527 && availableHeight >= 400 { return 18 }
        return 15
    }

    private var textOpFontSize: CGFloat {
        if availableWidth >= 878 && availableHeight >= 600 { return 22 }
        if availableWidth >= 527 && availableHeight >= 400 { return 15 }
        return 13
    }

    public var body: some View {
        let res = ResourceProvider.shared
        let ok = !vm.isInError
        let decSep = res.decimalSeparator

        VStack(spacing: 2) {
            // Operator Panel Row: Trigonometry ⌄ | Function ⌄
            HStack(spacing: 4) {
                OperatorPanelDropdownButton(
                    glyph: CalcGlyph.trig,
                    title: res.string("trigButton.Text", fallback: "Trigonometry"),
                    isEnabled: ok,
                    fontSize: availableWidth >= 527 ? 14 : 12,
                    glyphSize: availableWidth >= 527 ? 18 : 15,
                    isPresented: $showTrigPopover
                ) {
                    trigFlyoutContent
                }

                OperatorPanelDropdownButton(
                    glyph: CalcGlyph.function,
                    title: res.string("funcButton.Text", fallback: "Function"),
                    isEnabled: ok,
                    fontSize: availableWidth >= 527 ? 14 : 12,
                    glyphSize: availableWidth >= 527 ? 18 : 15,
                    isPresented: $showFuncPopover
                ) {
                    funcFlyoutContent
                }

                Spacer()
            }
            .frame(height: availableWidth >= 527 ? 40 : 34)

            // 5 x 7 Scientific Keypad Grid
            Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                // Row 0: 2nd  π  e  C/CE  ⌫
                GridRow {
                    FluentCalcButton(
                        variant: .emphasizedToggle(isOn: vm.isSecondChecked),
                        isEnabled: ok,
                        action: { vm.isSecondChecked.toggle() }
                    ) {
                        CalcGlyphText(CalcGlyph.second, size: glyphFontSize)
                    }
                    glyphBtn(CalcGlyph.pi, key: "pi", enabled: ok, cmd: .pi)
                    textBtn("e", key: "euler", enabled: ok, cmd: .euler)
                    if vm.isInputEmpty {
                        textBtn("C", key: "clear", enabled: true, cmd: .clear)
                    } else {
                        textBtn("CE", key: "clearEntry", enabled: true, cmd: .clearEntry)
                    }
                    glyphBtn(CalcGlyph.backspace, key: "backspace", enabled: true, cmd: .backspace)
                }

                // Row 1: x²/x³  1/x  |x|  exp  mod
                GridRow {
                    if vm.isSecondChecked {
                        shiftGlyphBtn(CalcGlyph.cube, cmd: .cube, enabled: ok)
                    } else {
                        glyphBtn(CalcGlyph.xPower2, key: "xPower2", enabled: ok, cmd: .xPower2)
                    }
                    glyphBtn(CalcGlyph.invert, key: "invert", enabled: ok, cmd: .invert)
                    glyphBtn(CalcGlyph.abs, key: "abs", enabled: ok, cmd: .abs)
                    textBtn("exp", key: "exp", enabled: ok, cmd: .exp)
                    textBtn("mod", key: "mod", enabled: ok, cmd: .mod)
                }

                // Row 2: ²√x/³√x  (  )  n!  ÷
                GridRow {
                    if vm.isSecondChecked {
                        shiftGlyphBtn(CalcGlyph.cubeRoot, cmd: .cubeRoot, enabled: ok)
                    } else {
                        glyphBtn(CalcGlyph.sqrt, key: "sqrt", enabled: ok, cmd: .sqrt)
                    }
                    ParenthesisCalcButton(
                        count: vm.openParenthesisCount,
                        fontSize: textOpFontSize + 2,
                        isEnabled: ok,
                        isLit: vm.litButtonKey == "openParen",
                        action: { vm.press(.openParenthesis) }
                    )
                    textBtn(")", key: "closeParen", enabled: ok, cmd: .closeParenthesis)
                    glyphBtn(CalcGlyph.factorial, key: "factorial", enabled: ok, cmd: .factorial)
                    glyphBtn(CalcGlyph.divide, key: "divide", enabled: ok, cmd: .divide)
                }

                // Row 3: xʸ/ʸ√x  7  8  9  ×
                GridRow {
                    if vm.isSecondChecked {
                        shiftGlyphBtn(CalcGlyph.yRootX, cmd: .yRootX, enabled: ok)
                    } else {
                        glyphBtn(CalcGlyph.xPowerY, key: "xPowerY", enabled: ok, cmd: .xPowerY)
                    }
                    numBtn(7)
                    numBtn(8)
                    numBtn(9)
                    glyphBtn(CalcGlyph.multiply, key: "multiply", enabled: ok, cmd: .multiply)
                }

                // Row 4: 10ˣ/2ˣ  4  5  6  −
                GridRow {
                    if vm.isSecondChecked {
                        shiftGlyphBtn(CalcGlyph.twoPowerX, cmd: .twoPowerX, enabled: ok)
                    } else {
                        glyphBtn(CalcGlyph.tenPowerX, key: "tenPowerX", enabled: ok, cmd: .tenPowerX)
                    }
                    numBtn(4)
                    numBtn(5)
                    numBtn(6)
                    glyphBtn(CalcGlyph.subtract, key: "subtract", enabled: ok, cmd: .subtract)
                }

                // Row 5: log/logᵧx  1  2  3  +
                GridRow {
                    if vm.isSecondChecked {
                        shiftGlyphBtn(CalcGlyph.logBaseY, cmd: .logBaseY, enabled: ok)
                    } else {
                        textBtn("log", key: "log", enabled: ok, cmd: .logBase10)
                    }
                    numBtn(1)
                    numBtn(2)
                    numBtn(3)
                    glyphBtn(CalcGlyph.add, key: "add", enabled: ok, cmd: .add)
                }

                // Row 6: ln/eˣ  +/−  0  .  =
                GridRow {
                    if vm.isSecondChecked {
                        shiftGlyphBtn(CalcGlyph.ePowerX, cmd: .ePowerX, enabled: ok)
                    } else {
                        textBtn("ln", key: "ln", enabled: ok, cmd: .logBaseE)
                    }
                    glyphBtn(CalcGlyph.negate, variant: .numeric, key: "negate", enabled: ok, cmd: .sign)
                    numBtn(0)
                    FluentCalcButton(
                        variant: .numeric,
                        isEnabled: ok,
                        isLit: vm.litButtonKey == "decimal",
                        action: { vm.press(.decimal) }
                    ) {
                        Text(decSep)
                            .font(.system(size: numFontSize, weight: .regular))
                    }
                    glyphBtn(CalcGlyph.equals, variant: .accent, key: "equals", enabled: true, cmd: .equals)
                }
            }
        }
    }

    // MARK: - Trigonometry Flyout (4 x 2 Grid matching CalculatorScientificOperators.xaml)

    private var trigFlyoutContent: some View {
        let trigItems: [(String, CalcCommand)] = {
            switch (vm.isTrigSecondChecked, vm.isHypChecked) {
            case (false, false):
                return [("sin", .sin), ("cos", .cos), ("tan", .tan), ("sec", .sec), ("csc", .csc), ("cot", .cot)]
            case (true, false):
                return [("sin⁻¹", .invSin), ("cos⁻¹", .invCos), ("tan⁻¹", .invTan), ("sec⁻¹", .invSec), ("csc⁻¹", .invCsc), ("cot⁻¹", .invCot)]
            case (false, true):
                return [("sinh", .sinh), ("cosh", .cosh), ("tanh", .tanh), ("sech", .sech), ("csch", .csch), ("coth", .coth)]
            case (true, true):
                return [("sinh⁻¹", .invSinh), ("cosh⁻¹", .invCosh), ("tanh⁻¹", .invTanh), ("sech⁻¹", .invSech), ("csch⁻¹", .invCsch), ("coth⁻¹", .invCoth)]
            }
        }()

        return Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            GridRow {
                FluentCalcButton(
                    variant: .emphasizedToggle(isOn: vm.isTrigSecondChecked),
                    action: { vm.isTrigSecondChecked.toggle() }
                ) {
                    CalcGlyphText(CalcGlyph.second, size: 15)
                }
                ForEach(0..<3, id: \.self) { i in
                    flyoutTextBtn(trigItems[i].0) {
                        vm.press(trigItems[i].1)
                        closeFlyouts()
                    }
                }
            }
            GridRow {
                FluentCalcButton(
                    variant: .emphasizedToggle(isOn: vm.isHypChecked),
                    action: { vm.isHypChecked.toggle() }
                ) {
                    Text("hyp")
                        .font(.system(size: 13))
                }
                ForEach(3..<6, id: \.self) { i in
                    flyoutTextBtn(trigItems[i].0) {
                        vm.press(trigItems[i].1)
                        closeFlyouts()
                    }
                }
            }
        }
        .frame(width: 264, height: 96)
    }

    // MARK: - Function Flyout (3 x 2 Grid matching CalculatorScientificOperators.xaml)

    private var funcFlyoutContent: some View {
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            GridRow {
                flyoutGlyphBtn(CalcGlyph.abs) { vm.press(.abs); closeFlyouts() }
                flyoutGlyphBtn(CalcGlyph.floor) { vm.press(.floor); closeFlyouts() }
                flyoutGlyphBtn(CalcGlyph.ceil) { vm.press(.ceil); closeFlyouts() }
            }
            GridRow {
                flyoutTextBtn("rand") { vm.press(.rand); closeFlyouts() }
                flyoutGlyphBtn(CalcGlyph.dms) { vm.press(.dms); closeFlyouts() }
                flyoutGlyphBtn(CalcGlyph.degrees) { vm.press(.degrees); closeFlyouts() }
            }
        }
        .frame(width: 198, height: 96)
    }

    private func closeFlyouts() {
        vm.isTrigSecondChecked = false
        vm.isHypChecked = false
        showTrigPopover = false
        showFuncPopover = false
    }

    private func flyoutTextBtn(_ label: String, action: @escaping () -> Void) -> some View {
        FluentCalcButton(variant: .operator, action: action) {
            Text(label).font(.system(size: 13))
        }
    }

    private func flyoutGlyphBtn(_ glyph: String, action: @escaping () -> Void) -> some View {
        FluentCalcButton(variant: .operator, action: action) {
            CalcGlyphText(glyph, size: 17)
        }
    }

    private func numBtn(_ digit: Int) -> some View {
        FluentCalcButton(
            variant: .numeric,
            isLit: vm.litButtonKey == "num\(digit)",
            action: { vm.press(CalcCommand.digit(digit)) }
        ) {
            Text("\(digit)")
                .font(.system(size: numFontSize, weight: .regular))
        }
    }

    private func textBtn(_ title: String, key: String, enabled: Bool, cmd: CalcCommand) -> some View {
        FluentCalcButton(
            variant: .operator,
            isEnabled: enabled,
            isLit: vm.litButtonKey == key,
            action: { vm.press(cmd) }
        ) {
            Text(title)
                .font(.system(size: textOpFontSize, weight: .regular))
        }
    }

    private func glyphBtn(_ glyph: String, variant: CalcButtonVariant = .operator, key: String, enabled: Bool, cmd: CalcCommand) -> some View {
        FluentCalcButton(
            variant: variant,
            isEnabled: enabled,
            isLit: vm.litButtonKey == key,
            action: { vm.press(cmd) }
        ) {
            CalcGlyphText(glyph, size: glyphFontSize)
        }
    }

    private func shiftGlyphBtn(_ glyph: String, cmd: CalcCommand, enabled: Bool) -> some View {
        FluentCalcButton(
            variant: .operator,
            isEnabled: enabled,
            action: {
                vm.isSecondChecked = false
                vm.press(cmd)
            }
        ) {
            CalcGlyphText(glyph, size: glyphFontSize)
        }
    }
}
