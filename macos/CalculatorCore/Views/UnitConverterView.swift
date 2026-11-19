import SwiftUI

/// Exact port of `src/Calculator/Views/UnitConverter.xaml`, `SupplementaryResults.xaml`, & `DelighterUnitStyles.xaml`.
public struct UnitConverterView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var vm: UnitConverterViewModel
    @State private var numpadScale: CGFloat = 1.0

    public init(vm: UnitConverterViewModel) {
        self.vm = vm
    }

    public var body: some View {
        GeometryReader { geo in
            // Exact AspectRatioTrigger Threshold="1" from UnitConverter.xaml!
            let isLandscape = geo.size.width >= geo.size.height
            let isWide = geo.size.width >= 640

            VStack(spacing: 0) {
                // Header height spacer for MainPage hamburger + Category Name
                Spacer().frame(height: 48)

                if isLandscape {
                    HStack(spacing: 0) {
                        converterValuesColumn(isWide: isWide)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        converterNumPad(isWide: isWide)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .scaleEffect(numpadScale)
                            .padding(.trailing, 4)
                            .padding(.bottom, 4)
                    }
                } else {
                    VStack(spacing: 0) {
                        converterValuesColumn(isWide: isWide)
                            .frame(maxHeight: geo.size.height * 0.44)
                        converterNumPad(isWide: isWide)
                            .frame(maxHeight: .infinity)
                            .scaleEffect(numpadScale)
                            .padding(.horizontal, 4)
                            .padding(.bottom, 4)
                    }
                }
            }
            .onChange(of: vm.modeAnimationTrigger) { _, _ in
                numpadScale = 0.94
                withAnimation(.easeOut(duration: 0.22)) {
                    numpadScale = 1.0
                }
            }
        }
    }

    private func converterValuesColumn(isWide: Bool) -> some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        let res = ResourceProvider.shared
        let valueFontSize: CGFloat = isWide ? 46 : 40
        let symbolFontSize: CGFloat = isWide ? 28 : 20

        return VStack(alignment: .leading, spacing: 2) {
            // Value 1 + Currency Symbol 1
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if vm.isCurrencyCategory && !vm.currencySymbol1.isEmpty {
                    Text(vm.currencySymbol1)
                        .font(.system(size: symbolFontSize, weight: .light))
                        .foregroundStyle(theme.textPrimary)
                        .padding(.leading, 14)
                }
                Button(action: { vm.activateValue1() }) {
                    CalculationResultView(
                        text: vm.value1,
                        maxFontSize: valueFontSize,
                        minFontSize: 16,
                        alignment: .leading,
                        fontWeight: vm.value1Active ? .semibold : .light,
                        onCopy: { vm.copyValue(vm.value1) },
                        onPaste: { vm.pasteFromClipboard() }
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)

            // Unit 1 Selector Dropdown
            unitPicker(selection: vm.unit1, onSelect: { vm.selectUnit1($0) })
                .padding(.leading, 12)
                .padding(.bottom, 8)

            // Value 2 + Currency Symbol 2
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if vm.isCurrencyCategory && !vm.currencySymbol2.isEmpty {
                    Text(vm.currencySymbol2)
                        .font(.system(size: symbolFontSize, weight: .light))
                        .foregroundStyle(theme.textPrimary)
                        .padding(.leading, 14)
                }
                Button(action: { vm.activateValue2() }) {
                    CalculationResultView(
                        text: vm.value2,
                        maxFontSize: valueFontSize,
                        minFontSize: 16,
                        alignment: .leading,
                        fontWeight: vm.value2Active ? .semibold : .light,
                        onCopy: { vm.copyValue(vm.value2) },
                        onPaste: { vm.pasteFromClipboard() }
                    )
                }
                .buttonStyle(.plain)
            }

            // Unit 2 Selector Dropdown
            unitPicker(selection: vm.unit2, onSelect: { vm.selectUnit2($0) })
                .padding(.leading, 12)
                .padding(.bottom, 8)

            // Supplementary Results ("About equal to") OR Currency Metadata
            if vm.isCurrencyCategory {
                VStack(alignment: .leading, spacing: 3) {
                    if !vm.currencyRatioEquality.isEmpty {
                        Text(vm.currencyRatioEquality)
                            .font(.system(size: 12))
                            .foregroundStyle(theme.textSecondary)
                    }
                    if !vm.currencyTimestamp.isEmpty {
                        Text(vm.currencyTimestamp)
                            .font(.system(size: 12))
                            .foregroundStyle(theme.textSecondary)
                    }
                    Button {
                        vm.refreshCurrencyRates()
                    } label: {
                        HStack(spacing: 6) {
                            Text(res.string("RefreshButtonText.Content", fallback: "Update rates"))
                                .font(.system(size: 12))
                                .foregroundStyle(theme.accentText)
                            if vm.isRefreshingCurrency {
                                ProgressView()
                                    .controlSize(.mini)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
                .padding(.horizontal, 16)
            } else if !vm.supplementaryResults.isEmpty {
                SupplementaryResultsView(results: vm.supplementaryResults)
            }

            Spacer(minLength: 0)
        }
    }

    private func unitPicker(selection: ConverterUnit?, onSelect: @escaping (ConverterUnit) -> Void) -> some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        return Menu {
            ForEach(vm.units) { unit in
                Button(unit.name) {
                    onSelect(unit)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selection?.name ?? "")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                CalcGlyphText(CalcGlyph.chevronDown, size: 10)
                    .foregroundStyle(theme.textPrimary)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func converterNumPad(isWide: Bool) -> some View {
        let decSep = ResourceProvider.shared.decimalSeparator
        let numFont: CGFloat = isWide ? 24 : 18
        let opFont: CGFloat = isWide ? 18 : 15

        return Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            // Row 0: [empty]  CE  ⌫
            GridRow {
                Color.clear
                FluentCalcButton(
                    variant: .operator,
                    isLit: vm.litButtonKey == "clear",
                    action: { vm.sendCommand(.clear) }
                ) {
                    Text("CE").font(.system(size: opFont))
                }
                FluentCalcButton(
                    variant: .operator,
                    isLit: vm.litButtonKey == "backspace",
                    action: { vm.sendCommand(.backspace) }
                ) {
                    CalcGlyphText(CalcGlyph.backspace, size: opFont + 1)
                }
            }

            // Row 1: 7  8  9
            GridRow {
                numBtn(7, .seven, fontSize: numFont)
                numBtn(8, .eight, fontSize: numFont)
                numBtn(9, .nine, fontSize: numFont)
            }

            // Row 2: 4  5  6
            GridRow {
                numBtn(4, .four, fontSize: numFont)
                numBtn(5, .five, fontSize: numFont)
                numBtn(6, .six, fontSize: numFont)
            }

            // Row 3: 1  2  3
            GridRow {
                numBtn(1, .one, fontSize: numFont)
                numBtn(2, .two, fontSize: numFont)
                numBtn(3, .three, fontSize: numFont)
            }

            // Row 4: [+/− if supportsNegative]  0  .
            GridRow {
                if vm.currentCategory.supportsNegative {
                    FluentCalcButton(
                        variant: .numeric,
                        isLit: vm.litButtonKey == "negate",
                        action: { vm.sendCommand(.negate) }
                    ) {
                        CalcGlyphText(CalcGlyph.negate, size: opFont + 1)
                    }
                } else {
                    Color.clear
                }
                numBtn(0, .zero, fontSize: numFont)
                FluentCalcButton(
                    variant: .numeric,
                    isLit: vm.litButtonKey == "decimal",
                    action: { vm.sendCommand(.decimal) }
                ) {
                    Text(decSep).font(.system(size: numFont))
                }
            }
        }
    }

    private func numBtn(_ digit: Int, _ cmd: UnitConverterCommand, fontSize: CGFloat) -> some View {
        FluentCalcButton(
            variant: .numeric,
            isLit: vm.litButtonKey == "num\(digit)",
            action: { vm.sendCommand(cmd) }
        ) {
            Text("\(digit)").font(.system(size: fontSize, weight: .regular))
        }
    }
}

/// Exact port of `src/Calculator/Views/SupplementaryResults.xaml`.
public struct SupplementaryResultsView: View {
    @Environment(\.colorScheme) private var colorScheme
    let results: [SupplementaryResultItem]

    public init(results: [SupplementaryResultItem]) {
        self.results = results
    }

    public var body: some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        let res = ResourceProvider.shared

        VStack(alignment: .leading, spacing: 4) {
            Text(res.string("SupplementaryResultsHeader.Text", fallback: "About equal to"))
                .font(.system(size: 12))
                .foregroundStyle(theme.textSecondary)
                .padding(.leading, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(results) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            if let emoji = item.delighterEmoji {
                                Text(emoji)
                                    .font(.system(size: 18))
                            }
                            Text(item.value)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(theme.textPrimary)
                            Text(item.unitAbbreviation)
                                .font(.system(size: 13))
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}
