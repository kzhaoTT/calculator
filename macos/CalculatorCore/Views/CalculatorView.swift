import SwiftUI

/// Exact port of `src/Calculator/Views/Calculator.xaml` & `OperatorsPanel.xaml`.
public struct CalculatorView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var vm: StandardCalculatorViewModel

    @State private var numpadScale: CGFloat = 1.0

    public init(vm: StandardCalculatorViewModel) {
        self.vm = vm
    }

    public var body: some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        let res = ResourceProvider.shared

        GeometryReader { geo in
            let totalWidth = geo.size.width
            let totalHeight = geo.size.height
            let isDocked = totalWidth >= 560 && !vm.isAlwaysOnTop
            let dockWidth: CGFloat = isDocked ? min(320, max(240, totalWidth * 0.36)) : 0
            let mainWidth = totalWidth - dockWidth

            ZStack {
                HStack(spacing: 0) {
                    // Main Calculator Column
                    VStack(spacing: 0) {
                        // Top Row: Space for Hamburger + Category Header on left, History Button on right
                        if !vm.isAlwaysOnTop {
                            HStack {
                                Spacer()
                                if !isDocked && !vm.isProgrammer {
                                    FluentCalcButton(variant: .subtle, action: {
                                        vm.isMemoryFlyoutOpen = false
                                        withAnimation(.easeOut(duration: 0.18)) {
                                            vm.isHistoryFlyoutOpen.toggle()
                                        }
                                    }) {
                                        CalcGlyphText(CalcGlyph.history, size: 16)
                                    }
                                    .frame(width: 40, height: 40)
                                    .padding(.trailing, 4)
                                    .help(res.string("HistoryButton.[using:Windows.UI.Xaml.Controls]ToolTipService.ToolTip", fallback: "History (Ctrl+H)"))
                                }
                            }
                            .frame(height: 48)
                        }

                        // Expression Display Row (hidden in Always-on-Top mode)
                        if !vm.isAlwaysOnTop {
                            ExpressionBarView(tokens: vm.expressionTokens)
                                .frame(height: max(20, totalHeight * 0.045))
                        }

                        // Primary Results Display Row
                        let resultFontSize: CGFloat = {
                            if vm.isAlwaysOnTop {
                                return totalHeight < 260 ? 22 : 38
                            }
                            if totalHeight >= 800 { return 72 }
                            if totalHeight >= 600 { return 48 }
                            return 44
                        }()
                        let resultHeight: CGFloat = {
                            if vm.isAlwaysOnTop { return max(36, totalHeight * 0.20) }
                            if vm.isProgrammer { return max(52, totalHeight * 0.11) }
                            return max(56, totalHeight * 0.145)
                        }()

                        CalculationResultView(
                            text: vm.displayValue,
                            maxFontSize: resultFontSize,
                            minFontSize: 16,
                            alignment: .trailing,
                            fontWeight: .semibold,
                            onCopy: { vm.copyDisplay() },
                            onPaste: { vm.pasteFromClipboard() }
                        )
                        .frame(height: resultHeight)

                        // Mode-specific display controls row
                        if !vm.isAlwaysOnTop {
                            if vm.isScientific {
                                ScientificAngleButtonsView(vm: vm)
                                    .frame(height: 32)
                            } else if vm.isProgrammer {
                                ProgrammerRadixDisplayView(vm: vm)
                            }
                        }

                        // Memory Controls Row (or Programmer Display Panel + MS/M⌄ row)
                        if !vm.isAlwaysOnTop {
                            if vm.isProgrammer {
                                ProgrammerDisplayPanelView(vm: vm, isDocked: isDocked)
                                    .frame(height: 36)
                            } else {
                                memoryToolbar(isDocked: isDocked)
                                    .frame(height: 34)
                            }
                        }

                        // Operators & NumberPad Panel
                        GeometryReader { padGeo in
                            Group {
                                if vm.isStandard {
                                    StandardOperatorsView(
                                        vm: vm,
                                        availableHeight: padGeo.size.height,
                                        availableWidth: padGeo.size.width
                                    )
                                } else if vm.isScientific {
                                    ScientificOperatorsView(
                                        vm: vm,
                                        availableHeight: padGeo.size.height,
                                        availableWidth: padGeo.size.width
                                    )
                                } else if vm.isProgrammer {
                                    if vm.isBitFlipChecked {
                                        ProgrammerBitFlipPanelView(vm: vm)
                                    } else {
                                        ProgrammerRadixOperatorsView(
                                            vm: vm,
                                            availableHeight: padGeo.size.height,
                                            availableWidth: padGeo.size.width
                                        )
                                    }
                                }
                            }
                            .scaleEffect(numpadScale)
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)
                    }
                    .frame(width: mainWidth)

                    // Docked History / Memory Panel (visible when width >= 560pt)
                    if isDocked {
                        DockedHistoryMemoryPanel(vm: vm)
                            .frame(width: dockWidth)
                    }
                }

                // Bottom Slide-Up Flyout Overlay for History / Memory (when not docked)
                if !isDocked && (vm.isHistoryFlyoutOpen || vm.isMemoryFlyoutOpen) {
                    ZStack(alignment: .bottom) {
                        theme.smokeOverlay
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.easeOut(duration: 0.16)) {
                                    vm.isHistoryFlyoutOpen = false
                                    vm.isMemoryFlyoutOpen = false
                                }
                            }

                        VStack(spacing: 0) {
                            if vm.isHistoryFlyoutOpen {
                                HistoryListView(vm: vm)
                            } else {
                                MemoryListView(vm: vm)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: max(220, totalHeight * 0.62))
                        .background(
                            UnevenRoundedRectangle(
                                topLeadingRadius: CalcTheme.overlayCornerRadius,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: CalcTheme.overlayCornerRadius,
                                style: .continuous
                            )
                            .fill(theme.flyoutBackground)
                        )
                        .overlay(
                            UnevenRoundedRectangle(
                                topLeadingRadius: CalcTheme.overlayCornerRadius,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: CalcTheme.overlayCornerRadius,
                                style: .continuous
                            )
                            .strokeBorder(theme.flyoutBorder, lineWidth: 1)
                        )
                        .transition(.move(edge: .bottom))
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

    private func memoryToolbar(isDocked: Bool) -> some View {
        let ok = !vm.isInError
        let hasMem = !vm.isMemoryEmpty && ok

        return HStack(spacing: 2) {
            memBtn(CalcGlyph.memClear, enabled: hasMem, tooltip: "Clear all memory (Ctrl+L)") { vm.memoryClearAll() }
            memBtn(CalcGlyph.memRecall, enabled: hasMem, tooltip: "Memory recall (Ctrl+R)") { vm.memoryRecall() }
            memBtn(CalcGlyph.memAdd, enabled: ok, tooltip: "Memory add (Ctrl+P)") { vm.memoryAdd() }
            memBtn(CalcGlyph.memSubtract, enabled: ok, tooltip: "Memory subtract (Ctrl+Q)") { vm.memorySubtract() }
            memBtn(CalcGlyph.memStore, enabled: ok, tooltip: "Memory store (Ctrl+M)") { vm.memoryStore() }
            if !isDocked {
                memBtn(CalcGlyph.memFlyout, enabled: hasMem, tooltip: "Memory") {
                    vm.isHistoryFlyoutOpen = false
                    withAnimation(.easeOut(duration: 0.18)) {
                        vm.isMemoryFlyoutOpen.toggle()
                    }
                }
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 4)
    }

    private func memBtn(_ glyph: String, enabled: Bool, tooltip: String, action: @escaping () -> Void) -> some View {
        FluentCalcButton(variant: .subtle, isEnabled: enabled, action: action) {
            CalcGlyphText(glyph, size: 15)
        }
        .frame(maxWidth: 72)
        .help(tooltip)
    }
}

/// Expression token bar matching `OverflowTextBlock` (`NormalStyle`) in `src/Calculator/Views/Calculator.xaml`.
private struct ExpressionBarView: View {
    @Environment(\.colorScheme) private var colorScheme
    let tokens: [ExpressionToken]

    var body: some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        let fullText = tokens.map(\.token).joined()

        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Text(fullText)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                            .id("exprEnd")
                    }
                    .padding(.horizontal, 14)
                    .frame(minWidth: geo.size.width, minHeight: geo.size.height, alignment: .bottomTrailing)
                }
                .onChange(of: fullText) { _, _ in
                    proxy.scrollTo("exprEnd", anchor: .trailing)
                }
            }
        }
    }
}
