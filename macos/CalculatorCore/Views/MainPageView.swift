import AppKit
import SwiftUI

/// Exact port of `src/Calculator/Views/MainPage.xaml` & `TitleBar.xaml`.
public struct MainPageView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var appVM: ApplicationViewModel

    public init(appVM: ApplicationViewModel) {
        self.appVM = appVM
    }

    public var body: some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        let res = ResourceProvider.shared

        ZStack(alignment: .topLeading) {
            // Authentic Windows 11 Mica-tinted backdrop
            ZStack {
                FluentBackdropView(material: .underWindowBackground)
                theme.windowBackground.opacity(colorScheme == .dark ? 0.86 : 0.88)
            }
            .ignoresSafeArea()

            if appVM.isSettingsOpen {
                VStack(spacing: 0) {
                    TitleBarView(appVM: appVM)
                    SettingsView(appVM: appVM)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                VStack(spacing: 0) {
                    TitleBarView(appVM: appVM)

                    ZStack(alignment: .topLeading) {
                        // Active Mode Content
                        activeModeContent
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // Floating Top-Left Navigation Header: Hamburger + Category Name + Always-on-Top Button
                        if !appVM.isAlwaysOnTop {
                            HStack(spacing: 4) {
                                FluentCalcButton(variant: .subtle, action: {
                                    withAnimation(.easeOut(duration: 0.18)) {
                                        appVM.isNavPaneOpen.toggle()
                                    }
                                }) {
                                    HamburgerIconView(size: 15)
                                }
                                .frame(width: 40, height: 40)
                                .padding(.leading, 4)
                                .help("Open Navigation")

                                Text(appVM.categoryName)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(theme.textPrimary)
                                    .lineLimit(1)
                                    .padding(.leading, 2)

                                if appVM.displayNormalAlwaysOnTopOption {
                                    FluentCalcButton(variant: .subtle, action: {
                                        appVM.toggleAlwaysOnTop()
                                    }) {
                                        CalcGlyphText(CalcGlyph.enterAlwaysOnTop, size: 15)
                                    }
                                    .frame(width: 34, height: 34)
                                    .padding(.leading, 4)
                                    .help(res.string("EnterAlwaysOnTopButton.[using:Windows.UI.Xaml.Controls]ToolTipService.ToolTip", fallback: "Keep on top (Option+Up)"))
                                }
                            }
                            .frame(height: 48)
                        }

                        // Slide-out NavigationView Overlay Pane (256pt wide matching SplitViewOpenPaneLength)
                        if appVM.isNavPaneOpen {
                            ZStack(alignment: .leading) {
                                Color.black.opacity(0.01)
                                    .ignoresSafeArea()
                                    .onTapGesture {
                                        withAnimation(.easeOut(duration: 0.16)) {
                                            appVM.isNavPaneOpen = false
                                        }
                                    }

                                NavigationPaneView(appVM: appVM)
                                    .frame(width: 256)
                                    .transition(.move(edge: .leading))
                            }
                        }
                    }
                }
            }
        }
        .preferredColorScheme(appVM.preferredColorScheme)
    }

    @ViewBuilder
    private var activeModeContent: some View {
        if appVM.mode.isCalculatorMode {
            CalculatorView(vm: appVM.calculatorVM)
        } else if appVM.mode == .date {
            DateCalculatorView(vm: appVM.dateCalcVM)
        } else if appVM.mode == .graphing {
            GraphingCalculatorView(vm: appVM.graphingVM)
        } else if appVM.mode.isConverterMode {
            UnitConverterView(vm: appVM.converterVM)
        } else {
            CalculatorView(vm: appVM.calculatorVM)
        }
    }
}

/// Exact port of `src/Calculator/Views/TitleBar.xaml` adapted cleanly to macOS traffic-light titlebar.
public struct TitleBarView: View {
    @Environment(\.colorScheme) private var colorScheme
    let appVM: ApplicationViewModel

    public init(appVM: ApplicationViewModel) {
        self.appVM = appVM
    }

    public var body: some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        let res = ResourceProvider.shared

        HStack(spacing: 8) {
            // Reserve horizontal space for macOS native window traffic light buttons (close/minimize/zoom)
            Spacer().frame(width: 72)

            if appVM.isAlwaysOnTop {
                // Exit Always-on-Top button (matching AOTMiniState in TitleBar.xaml)
                FluentCalcButton(variant: .subtle, action: {
                    appVM.setAlwaysOnTop(false)
                }) {
                    CalcGlyphText(CalcGlyph.exitAlwaysOnTop, size: 14)
                }
                .frame(width: 36, height: 26)
                .help(res.string("ExitAlwaysOnTopButton.[using:Windows.UI.Xaml.Controls]ToolTipService.ToolTip", fallback: "Back to full view (Option+Down)"))

                Spacer()
            } else {
                WindowsCalculatorAppIcon(size: 16)

                Text(res.string("AppName", fallback: "Calculator"))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(theme.textSecondary)

                Spacer()
            }
        }
        .frame(height: 30)
    }
}

/// Exact port of WinUI `NavigationView` overlay pane (`PaneDisplayMode="LeftMinimal"`, `OpenPaneLength="256"`).
private struct NavigationPaneView: View {
    @Environment(\.colorScheme) private var colorScheme
    let appVM: ApplicationViewModel

    var body: some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        let res = ResourceProvider.shared

        VStack(spacing: 0) {
            // Top hamburger close button inside pane
            HStack {
                FluentCalcButton(variant: .subtle, action: {
                    withAnimation(.easeOut(duration: 0.16)) {
                        appVM.isNavPaneOpen = false
                    }
                }) {
                    HamburgerIconView(size: 15)
                }
                .frame(width: 40, height: 40)
                .padding(.leading, 4)
                Spacer()
            }
            .frame(height: 48)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    // Calculator Group Header
                    sectionHeader(res.string("CalculatorModeTextCaps", fallback: "Calculator"))
                    ForEach(ViewMode.calculatorModes) { mode in
                        NavMenuItemRow(
                            glyph: mode.glyph,
                            title: mode.displayName,
                            isSelected: appVM.mode == mode,
                            action: {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    appVM.selectMode(mode)
                                }
                            }
                        )
                    }

                    // Converter Group Header
                    sectionHeader(res.string("ConverterModeTextCaps", fallback: "Converter"))
                        .padding(.top, 8)
                    ForEach(ViewMode.converterModes) { mode in
                        NavMenuItemRow(
                            glyph: mode.glyph,
                            title: mode.displayName,
                            isSelected: appVM.mode == mode,
                            action: {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    appVM.selectMode(mode)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
            }

            Rectangle()
                .fill(theme.dividerStroke)
                .frame(height: 1)

            // Pinned Settings Footer Item (matching IsSettingsVisible="True")
            NavMenuItemRow(
                glyph: CalcGlyph.settings,
                title: res.string("SettingsHeader.Text", fallback: "Settings"),
                isSelected: false,
                action: {
                    withAnimation(.easeOut(duration: 0.16)) {
                        appVM.openSettings()
                    }
                }
            )
            .padding(4)
        }
        .background(
            ZStack {
                FluentBackdropView(material: .popover)
                theme.paneBackground.opacity(colorScheme == .dark ? 0.92 : 0.95)
            }
        )
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(theme.flyoutBorder)
                .frame(width: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 14, x: 4, y: 0)
    }

    private func sectionHeader(_ title: String) -> some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        return Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
    }
}

private struct NavMenuItemRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    let glyph: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isSelected ? theme.accentDefault : .clear)
                    .frame(width: 3, height: 16)

                CalcGlyphText(glyph, size: 15)
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.trailing, 12)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                        isSelected
                            ? theme.subtleFillHover
                            : (isHovered ? theme.subtleFillHover : .clear)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
