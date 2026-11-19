import SwiftUI

/// Exact port of `src/Calculator/Views/CalculatorProgrammerOperators.xaml` (HEX/DEC/OCT/BIN simultaneous radix rows).
public struct ProgrammerRadixDisplayView: View {
    @Environment(\.colorScheme) private var colorScheme
    let vm: StandardCalculatorViewModel

    public init(vm: StandardCalculatorViewModel) {
        self.vm = vm
    }

    public var body: some View {
        VStack(spacing: 1) {
            radixRow(tag: "HEX", value: vm.hexDisplayValue, base: .hex)
            radixRow(tag: "DEC", value: vm.decimalDisplayValue, base: .decimal)
            radixRow(tag: "OCT", value: vm.octalDisplayValue, base: .octal)
            radixRow(tag: "BIN", value: vm.binaryDisplayValue, base: .binary)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }

    private func radixRow(tag: String, value: String, base: NumberBase) -> some View {
        RadixRowButton(
            tag: tag,
            value: value,
            isSelected: vm.currentRadix == base,
            onSelect: { vm.switchProgrammerBase(base) },
            onCopy: { vm.copyValue(value) }
        )
    }
}

private struct RadixRowButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    let tag: String
    let value: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onCopy: () -> Void

    var body: some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        Button(action: onSelect) {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isSelected ? theme.accentDefault : .clear)
                    .frame(width: 3, height: 16)
                    .padding(.vertical, 3)

                Text(tag)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
                    .frame(width: 44, alignment: .leading)
                    .padding(.leading, 8)

                Text(value)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 8)
            }
            .frame(minHeight: 22)
            .background(
                RoundedRectangle(cornerRadius: CalcTheme.controlCornerRadius, style: .continuous)
                    .fill(isHovered ? theme.subtleFillHover : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(ResourceProvider.shared.string("copyMenuItem", fallback: "Copy")) {
                onCopy()
            }
        }
    }
}

/// Exact port of `src/Calculator/Views/CalculatorProgrammerDisplayPanel.xaml` combined with Programmer memory buttons.
public struct ProgrammerDisplayPanelView: View {
    let vm: StandardCalculatorViewModel
    let isDocked: Bool

    public init(vm: StandardCalculatorViewModel, isDocked: Bool) {
        self.vm = vm
        self.isDocked = isDocked
    }

    public var body: some View {
        let res = ResourceProvider.shared
        HStack(spacing: 2) {
            // Left: Full Keypad & Bit-Flip Keypad toggle buttons
            IndicatorToggleButton(
                isSelected: !vm.isBitFlipChecked,
                action: { vm.isBitFlipChecked = false }
            ) {
                CalcGlyphText(CalcGlyph.fullKeypad, size: 16)
            }
            .frame(width: 48)
            .help(res.string("fullKeypad.[using:Windows.UI.Xaml.Controls]ToolTipService.ToolTip", fallback: "Full keypad"))

            IndicatorToggleButton(
                isSelected: vm.isBitFlipChecked,
                action: { vm.isBitFlipChecked = true }
            ) {
                CalcGlyphText(CalcGlyph.bitFlip, size: 16)
            }
            .frame(width: 48)
            .help(res.string("bitFlip.[using:Windows.UI.Xaml.Controls]ToolTipService.ToolTip", fallback: "Bit toggling keypad"))

            Spacer(minLength: 4)

            // Center: QWORD / DWORD / WORD / BYTE cycling button
            FluentCalcButton(
                variant: .subtle,
                isEnabled: !vm.isInError,
                action: { vm.cycleBitLength() }
            ) {
                Text(vm.bitLength.label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .frame(width: 72)

            Spacer(minLength: 4)

            // Right: MS and M⌄ buttons (M⌄ hidden when Docked panel is visible >= 560pt)
            FluentCalcButton(
                variant: .subtle,
                isEnabled: !vm.isInError,
                action: { vm.memoryStore() }
            ) {
                CalcGlyphText(CalcGlyph.memStore, size: 15)
            }
            .frame(width: 48)
            .help("Memory store (Ctrl+M)")

            if !isDocked {
                FluentCalcButton(
                    variant: .subtle,
                    isEnabled: !vm.isMemoryEmpty && !vm.isInError,
                    action: { vm.isMemoryFlyoutOpen.toggle() }
                ) {
                    CalcGlyphText(CalcGlyph.memFlyout, size: 15)
                }
                .frame(width: 48)
                .help("Memory")
            }
        }
        .padding(.horizontal, 4)
    }
}

/// Exact port of `src/Calculator/Views/CalculatorProgrammerRadixOperators.xaml`.
public struct ProgrammerRadixOperatorsView: View {
    @Bindable var vm: StandardCalculatorViewModel
    let availableHeight: CGFloat
    let availableWidth: CGFloat

    @State private var showBitwisePopover = false
    @State private var showBitShiftPopover = false

    public init(vm: StandardCalculatorViewModel, availableHeight: CGFloat, availableWidth: CGFloat) {
        self.vm = vm
        self.availableHeight = availableHeight
        self.availableWidth = availableWidth
    }

    private var numFontSize: CGFloat {
        if availableWidth >= 630 && availableHeight >= 400 { return 22 }
        return 17
    }

    private var hexFontSize: CGFloat {
        if availableWidth >= 630 && availableHeight >= 400 { return 20 }
        return 15
    }

    private var opFontSize: CGFloat {
        if availableWidth >= 630 && availableHeight >= 400 { return 18 }
        return 14
    }

    public var body: some View {
        let res = ResourceProvider.shared
        let ok = !vm.isInError

        VStack(spacing: 2) {
            // Operator Panel Row: Bitwise ⌄ | Bit shift ⌄
            HStack(spacing: 4) {
                OperatorPanelDropdownButton(
                    glyph: CalcGlyph.bitwise,
                    title: res.string("bitwiseButton.Text", fallback: "Bitwise"),
                    isEnabled: ok,
                    fontSize: availableWidth >= 630 ? 14 : 12,
                    glyphSize: availableWidth >= 630 ? 18 : 15,
                    isPresented: $showBitwisePopover
                ) {
                    bitwiseFlyoutContent
                }

                OperatorPanelDropdownButton(
                    glyph: CalcGlyph.bitShift,
                    title: res.string("bitShiftButton.Text", fallback: "Bit shift"),
                    isEnabled: ok,
                    fontSize: availableWidth >= 630 ? 14 : 12,
                    glyphSize: availableWidth >= 630 ? 18 : 15,
                    isPresented: $showBitShiftPopover
                ) {
                    bitShiftFlyoutContent
                }

                Spacer()
            }
            .frame(height: availableWidth >= 630 ? 38 : 32)

            // 5 x 6 Programmer Keypad Grid
            Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                // Row 0: A  ≪  ≫  C/CE  ⌫
                GridRow {
                    hexBtn("A", key: "hexA", cmd: .hexA)
                    glyphBtn(CalcGlyph.lsh, enabled: ok, cmd: vm.bitShiftMode.leftCommand)
                    glyphBtn(CalcGlyph.rsh, enabled: ok, cmd: vm.bitShiftMode.rightCommand)
                    if vm.isInputEmpty {
                        textBtn("C", key: "clear", enabled: true, cmd: .clear)
                    } else {
                        textBtn("CE", key: "clearEntry", enabled: true, cmd: .clearEntry)
                    }
                    glyphBtn(CalcGlyph.backspace, key: "backspace", enabled: true, cmd: .backspace)
                }

                // Row 1: B  (  )  %  ÷
                GridRow {
                    hexBtn("B", key: "hexB", cmd: .hexB)
                    ParenthesisCalcButton(
                        count: vm.openParenthesisCount,
                        fontSize: opFontSize + 2,
                        isEnabled: ok,
                        isLit: vm.litButtonKey == "openParen",
                        action: { vm.press(.openParenthesis) }
                    )
                    textBtn(")", key: "closeParen", enabled: ok, cmd: .closeParenthesis)
                    textBtn("%", key: "mod", enabled: ok, cmd: .mod)
                    glyphBtn(CalcGlyph.divide, key: "divide", enabled: ok, cmd: .divide)
                }

                // Row 2: C  7  8  9  ×
                GridRow {
                    hexBtn("C", key: "hexC", cmd: .hexC)
                    numBtn(7)
                    numBtn(8)
                    numBtn(9)
                    glyphBtn(CalcGlyph.multiply, key: "multiply", enabled: ok, cmd: .multiply)
                }

                // Row 3: D  4  5  6  −
                GridRow {
                    hexBtn("D", key: "hexD", cmd: .hexD)
                    numBtn(4)
                    numBtn(5)
                    numBtn(6)
                    glyphBtn(CalcGlyph.subtract, key: "subtract", enabled: ok, cmd: .subtract)
                }

                // Row 4: E  1  2  3  +
                GridRow {
                    hexBtn("E", key: "hexE", cmd: .hexE)
                    numBtn(1)
                    numBtn(2)
                    numBtn(3)
                    glyphBtn(CalcGlyph.add, key: "add", enabled: ok, cmd: .add)
                }

                // Row 5: F  +/−  0  .  =
                GridRow {
                    hexBtn("F", key: "hexF", cmd: .hexF)
                    glyphBtn(CalcGlyph.negate, variant: .numeric, key: "negate", enabled: ok, cmd: .sign)
                    numBtn(0)
                    FluentCalcButton(variant: .numeric, isEnabled: false, action: {}) {
                        Text(res.decimalSeparator)
                            .font(.system(size: numFontSize, weight: .regular))
                    }
                    glyphBtn(CalcGlyph.equals, variant: .accent, key: "equals", enabled: true, cmd: .equals)
                }
            }
        }
    }

    private var bitwiseFlyoutContent: some View {
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            GridRow {
                bitwiseBtn("AND", .bitwiseAnd)
                bitwiseBtn("OR", .bitwiseOr)
                bitwiseBtn("NOT", .bitwiseNot)
            }
            GridRow {
                bitwiseBtn("NAND", .nand)
                bitwiseBtn("NOR", .nor)
                bitwiseBtn("XOR", .bitwiseXor)
            }
        }
        .frame(width: 210, height: 96)
    }

    private func bitwiseBtn(_ title: String, _ cmd: CalcCommand) -> some View {
        FluentCalcButton(variant: .operator, action: {
            vm.press(cmd)
            showBitwisePopover = false
        }) {
            Text(title).font(.system(size: 13))
        }
    }

    private var bitShiftFlyoutContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(BitShiftMode.allCases) { mode in
                Button {
                    vm.bitShiftMode = mode
                    showBitShiftPopover = false
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: vm.bitShiftMode == mode ? "largecircle.fill.circle" : "circle")
                            .font(.system(size: 14))
                            .foregroundStyle(vm.bitShiftMode == mode ? Color.accentColor : Color.secondary)
                        Text(mode.label)
                            .font(.system(size: 13))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .frame(width: 220)
    }

    private func hexBtn(_ letter: String, key: String, cmd: CalcCommand) -> some View {
        FluentCalcButton(
            variant: .numeric,
            isEnabled: vm.areHexButtonsEnabled,
            isLit: vm.litButtonKey == key,
            action: { vm.press(cmd) }
        ) {
            Text(letter)
                .font(.system(size: hexFontSize, weight: .regular))
        }
    }

    private func numBtn(_ digit: Int) -> some View {
        FluentCalcButton(
            variant: .numeric,
            isEnabled: vm.isDigitEnabled(digit),
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
                .font(.system(size: opFontSize, weight: .regular))
        }
    }

    private func glyphBtn(_ glyph: String, variant: CalcButtonVariant = .operator, key: String = "", enabled: Bool, cmd: CalcCommand) -> some View {
        FluentCalcButton(
            variant: variant,
            isEnabled: enabled,
            isLit: !key.isEmpty && vm.litButtonKey == key,
            action: { vm.press(cmd) }
        ) {
            CalcGlyphText(glyph, size: opFontSize + 1)
        }
    }
}

/// Exact port of `src/Calculator/Views/CalculatorProgrammerBitFlipPanel.xaml` (64 interactive bit toggles in 4x4 nibbles).
public struct ProgrammerBitFlipPanelView: View {
    @Environment(\.colorScheme) private var colorScheme
    let vm: StandardCalculatorViewModel

    public init(vm: StandardCalculatorViewModel) {
        self.vm = vm
    }

    private static let nibbleRowStarts = [60, 44, 28, 12]

    public var body: some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        let activeBits = vm.bitLength.bitCount

        VStack(spacing: 4) {
            Rectangle()
                .fill(theme.dividerStroke)
                .frame(height: 1)
                .padding(.top, 2)
                .padding(.bottom, 4)

            ForEach(Self.nibbleRowStarts, id: \.self) { rowStart in
                VStack(spacing: 2) {
                    HStack(spacing: 10) {
                        ForEach(0..<4, id: \.self) { nibbleOffset in
                            let lsbBit = rowStart - nibbleOffset * 4
                            VStack(spacing: 2) {
                                HStack(spacing: 2) {
                                    ForEach((0..<4).reversed(), id: \.self) { bitInNibble in
                                        let bitPos = lsbBit + bitInNibble
                                        let isEnabled = bitPos < activeBits && !vm.isInError
                                        let isOn = bitPos < vm.binaryDigits.count ? vm.binaryDigits[bitPos] : false
                                        BitToggleButton(
                                            isOn: isOn,
                                            isEnabled: isEnabled,
                                            action: { vm.toggleBit(at: bitPos) }
                                        )
                                    }
                                }
                                HStack {
                                    Spacer()
                                    Text("\(lsbBit)")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(lsbBit < activeBits ? theme.textSecondary : theme.textDisabled)
                                        .frame(minWidth: 16, alignment: .trailing)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 8)
    }
}

private struct BitToggleButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    let isOn: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        Button(action: action) {
            Text(isOn ? "1" : "0")
                .font(.system(size: 19, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(
                    !isEnabled
                        ? theme.textDisabled
                        : (isOn ? theme.accentDefault : theme.textPrimary)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isHovered && isEnabled ? theme.subtleFillHover : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { isHovered = $0 }
    }
}
