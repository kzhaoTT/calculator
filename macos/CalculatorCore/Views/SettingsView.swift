import AppKit
import SwiftUI

/// Exact port of `src/Calculator/Views/Settings.xaml`.
public struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var appVM: ApplicationViewModel

    @State private var isThemeExpanded = true
    @State private var isAboutExpanded = true

    public init(appVM: ApplicationViewModel) {
        self.appVM = appVM
    }

    public var body: some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        let res = ResourceProvider.shared

        VStack(alignment: .leading, spacing: 0) {
            // Settings Header (with Back button + "Settings" title matching Settings.xaml)
            HStack(spacing: 8) {
                FluentCalcButton(variant: .subtle, action: { appVM.closeSettings() }) {
                    CalcGlyphText(CalcGlyph.back, size: 13)
                }
                .frame(width: 40, height: 36)
                .help("Back")

                Text(res.string("SettingsHeader.Text", fallback: "Settings"))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 48)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    // Appearance Section
                    Text(res.string("SettingsAppearance.Text", fallback: "Appearance"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                        .padding(.top, 10)
                        .padding(.bottom, 4)

                    settingsExpanderCard(
                        icon: { CalcGlyphText(CalcGlyph.palette, size: 18).foregroundStyle(theme.textPrimary) },
                        header: res.string("AppThemeExpander.Header", fallback: "App theme"),
                        description: res.string("AppThemeExpander.Description", fallback: "Select which app theme to display"),
                        trailingText: nil,
                        isExpanded: $isThemeExpanded
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            themeRadioRow(
                                title: res.string("LightThemeRadioButton.Content", fallback: "Light"),
                                pref: .light
                            )
                            themeRadioRow(
                                title: res.string("DarkThemeRadioButton.Content", fallback: "Dark"),
                                pref: .dark
                            )
                            themeRadioRow(
                                title: res.string("SystemThemeRadioButton.Content", fallback: "Use system setting"),
                                pref: .system
                            )
                        }
                        .padding(.vertical, 6)
                    }

                    // About Section
                    Text(res.string("AboutGroupTitle.Text", fallback: "About"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                        .padding(.top, 24)
                        .padding(.bottom, 4)

                    settingsExpanderCard(
                        icon: { appIconView(size: 20) },
                        header: res.string("AppName", fallback: "Calculator"),
                        description: res.localizedFormat("AboutControlCopyright", "2025"),
                        trailingText: "11.2607.0.0",
                        isExpanded: $isAboutExpanded
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            settingsLink(
                                res.string("AboutEULA.Text", fallback: "Microsoft Software License Terms"),
                                url: "https://github.com/microsoft/calculator/blob/main/LICENSE"
                            )
                            settingsLink(
                                res.string("AboutControlServicesAgreement.Text", fallback: "Microsoft Services Agreement"),
                                url: "https://go.microsoft.com/fwlink/?LinkID=822631"
                            )
                            settingsLink(
                                res.string("AboutControlPrivacyStatement.Text", fallback: "Microsoft Privacy Statement"),
                                url: "https://go.microsoft.com/fwlink/?LinkID=521839"
                            )
                        }
                        .padding(.vertical, 6)
                    }

                    // Feedback & Contribute on GitHub
                    settingsLink(
                        res.string("FeedbackButton.Content", fallback: "Feedback"),
                        url: "https://github.com/microsoft/calculator/issues"
                    )
                    .padding(.top, 8)

                    contributeTextView(theme: theme, res: res)
                        .padding(.top, 6)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .background(theme.windowBackground)
    }

    private func settingsExpanderCard<Icon: View, Content: View>(
        @ViewBuilder icon: () -> Icon,
        header: String,
        description: String,
        trailingText: String?,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        return VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack(spacing: 14) {
                    icon()
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(header)
                            .font(.system(size: 14))
                            .foregroundStyle(theme.textPrimary)
                        if !description.isEmpty {
                            Text(description)
                                .font(.system(size: 12))
                                .foregroundStyle(theme.textSecondary)
                        }
                    }

                    Spacer()

                    if let trailingText {
                        Text(trailingText)
                            .font(.system(size: 13))
                            .foregroundStyle(theme.textSecondary)
                            .textSelection(.enabled)
                    }

                    CalcGlyphText(isExpanded.wrappedValue ? CalcGlyph.chevronUp : CalcGlyph.chevronDown, size: 11)
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                Rectangle()
                    .fill(theme.dividerStroke)
                    .frame(height: 1)

                HStack {
                    content()
                    Spacer()
                }
                .padding(.leading, 54)
                .padding(.trailing, 16)
                .padding(.vertical, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(theme.cardBorder, lineWidth: 1)
        )
    }

    private func themeRadioRow(title: String, pref: AppThemePreference) -> some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        let selected = appVM.themePreference == pref
        return Button {
            appVM.themePreference = pref
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .strokeBorder(selected ? theme.accentDefault : theme.textSecondary, lineWidth: selected ? 5 : 1.5)
                    .frame(width: 18, height: 18)
                Text(title)
                    .font(.system(size: 14))
                    .foregroundStyle(theme.textPrimary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func settingsLink(_ title: String, url: String) -> some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        return Button {
            if let u = URL(string: url) {
                NSWorkspace.shared.open(u)
            }
        } label: {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(theme.accentText)
        }
        .buttonStyle(.plain)
    }

    private func contributeTextView(theme: CalcTheme, res: ResourceProvider) -> some View {
        let raw = res.string("AboutControlContribute", fallback: "To learn how you can contribute to Windows Calculator, check out the project on %HL%GitHub%HL%.")
        let parts = raw.components(separatedBy: "%HL%")
        let before = parts.count > 0 ? parts[0] : raw
        let linkText = parts.count > 1 ? parts[1] : "GitHub"
        let after = parts.count > 2 ? parts[2] : ""

        return HStack(spacing: 0) {
            Text(before)
                .font(.system(size: 13))
                .foregroundStyle(theme.textPrimary)
            Button(linkText) {
                if let u = URL(string: "https://go.microsoft.com/fwlink/?linkid=2099939") {
                    NSWorkspace.shared.open(u)
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(theme.accentText)
            Text(after)
                .font(.system(size: 13))
                .foregroundStyle(theme.textPrimary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func appIconView(size: CGFloat) -> some View {
        WindowsCalculatorAppIcon(size: size)
    }
}
