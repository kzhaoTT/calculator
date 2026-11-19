import AppKit
import SwiftUI

public enum AppThemePreference: String, CaseIterable, Identifiable, Sendable {
    case light = "Light"
    case dark = "Dark"
    case system = "Default"

    public var id: String { rawValue }
}

/// Exact Windows 11 Fluent Design palette derived from `src/Calculator/App.xaml` and WinUI 2.x theme tokens.
public struct CalcTheme: Sendable {
    public let isDark: Bool

    public init(colorScheme: ColorScheme) {
        self.isDark = colorScheme == .dark
    }

    public init(isDark: Bool) {
        self.isDark = isDark
    }

    // MARK: - Window & Surfaces
    public var windowBackground: Color {
        isDark ? Color(hex: 0x202020) : Color(hex: 0xF3F3F3)
    }

    public var paneBackground: Color {
        isDark ? Color(hex: 0x2C2C2C) : Color(hex: 0xF9F9F9)
    }

    public var flyoutBackground: Color {
        isDark ? Color(hex: 0x2C2C2C) : Color(hex: 0xFCFCFC)
    }

    public var flyoutBorder: Color {
        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }

    public var cardBackground: Color {
        isDark ? Color.white.opacity(0.05) : Color.white.opacity(0.70)
    }

    public var cardBorder: Color {
        isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.06)
    }

    public var dividerStroke: Color {
        isDark ? Color.white.opacity(0.0837) : Color.black.opacity(0.0578)
    }

    public var smokeOverlay: Color {
        Color.black.opacity(isDark ? 0.42 : 0.30)
    }

    // MARK: - Text
    public var textPrimary: Color {
        isDark ? Color.white : Color.black.opacity(0.8956)
    }

    public var textSecondary: Color {
        isDark ? Color.white.opacity(0.786) : Color.black.opacity(0.6063)
    }

    public var textTertiary: Color {
        isDark ? Color.white.opacity(0.5442) : Color.black.opacity(0.4458)
    }

    public var textDisabled: Color {
        isDark ? Color.white.opacity(0.3628) : Color.black.opacity(0.3614)
    }

    // MARK: - Accent Colors (Windows 11 Fluent Blue)
    public var accentDefault: Color {
        isDark ? Color(hex: 0x4CC2FF) : Color(hex: 0x0067C0)
    }

    public var accentHover: Color {
        isDark ? Color(hex: 0x4CC2FF).opacity(0.90) : Color(hex: 0x0067C0).opacity(0.90)
    }

    public var accentPressed: Color {
        isDark ? Color(hex: 0x4CC2FF).opacity(0.80) : Color(hex: 0x0067C0).opacity(0.80)
    }

    public var accentDisabled: Color {
        isDark ? Color.white.opacity(0.1581) : Color.black.opacity(0.2169)
    }

    public var textOnAccent: Color {
        isDark ? Color.black.opacity(0.8956) : Color.white
    }

    public var accentText: Color {
        isDark ? Color(hex: 0x99EBFF) : Color(hex: 0x003E92)
    }

    // MARK: - Numeric Buttons (CalcButtonFillColor* from App.xaml)
    public var numericFillDefault: Color {
        isDark ? Color.white.opacity(0.125) : Color.white
    }

    public var numericFillHover: Color {
        isDark ? Color.white.opacity(0.0852) : Color.white.opacity(0.75)
    }

    public var numericFillPressed: Color {
        isDark ? Color.white.opacity(0.0359) : Color.white.opacity(0.50)
    }

    public var numericFillDisabled: Color {
        isDark ? Color.white.opacity(0.0359) : Color.white.opacity(0.125)
    }

    // MARK: - Operator Buttons (CalcButtonAltFillColor* from App.xaml)
    public var operatorFillDefault: Color {
        isDark ? Color.white.opacity(0.0852) : Color.white.opacity(0.50)
    }

    public var operatorFillHover: Color {
        isDark ? Color.white.opacity(0.1256) : Color.white.opacity(0.25)
    }

    public var operatorFillPressed: Color {
        isDark ? Color.white.opacity(0.0852) : Color.white.opacity(0.125)
    }

    public var operatorFillDisabled: Color {
        isDark ? Color.white.opacity(0.0359) : Color.white.opacity(0.125)
    }

    public var buttonBorder: Color {
        isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.0578)
    }

    // MARK: - Subtle Buttons (Memory bar, Hamburger, History, OperatorPanel)
    public var subtleFillHover: Color {
        isDark ? Color.white.opacity(0.0605) : Color.black.opacity(0.0373)
    }

    public var subtleFillPressed: Color {
        isDark ? Color.white.opacity(0.0419) : Color.black.opacity(0.0241)
    }

    // MARK: - Graphing Colors (from App.xaml & GraphingCalculator.xaml)
    public var graphBackgroundDark: Color { Color(hex: 0x1F1F1F) }
    public var graphGridDark: Color { Color(hex: 0x4F4F4F) }
    public var graphAxisDark: Color { Color.white }

    public var graphBackgroundLight: Color { Color.white }
    public var graphGridLight: Color { Color(hex: 0xC6C6C6) }
    public var graphAxisLight: Color { Color.black }

    public var graphCommandPanelBackground: Color {
        isDark ? Color(hex: 0x303030) : Color(hex: 0xF3F3F3)
    }

    public var graphErrorBackground: Color { Color(hex: 0xEB5757).opacity(0.20) }
    public var graphErrorBorder: Color { Color(hex: 0xEB5757) }

    public var equationPalette: [Color] {
        if isDark {
            return [
                Color(hex: 0x4D92C8), Color(hex: 0x4DCDD5), Color(hex: 0xA366E0), Color(hex: 0x58A358),
                Color(hex: 0x4DDB97), Color(hex: 0x4DA688), Color(hex: 0x8A8B8C), Color(hex: 0xEF5865),
                Color(hex: 0xEB4DAF), Color(hex: 0xCA5B93), Color(hex: 0xFFCE4D), Color(hex: 0xF99255),
                Color(hex: 0xB0896D), Color(hex: 0xFFFFFF),
            ]
        } else {
            return [
                Color(hex: 0x0063B1), Color(hex: 0x00B7C3), Color(hex: 0x6600CC), Color(hex: 0x107C10),
                Color(hex: 0x00CC6A), Color(hex: 0x008055), Color(hex: 0x58595B), Color(hex: 0xE81123),
                Color(hex: 0xE3008C), Color(hex: 0xB31564), Color(hex: 0xFFB900), Color(hex: 0xF7630C),
                Color(hex: 0x8E562E), Color(hex: 0x000000),
            ]
        }
    }

    public static let equationColorNames: [String] = [
        "Blue", "Teal", "Purple", "Green", "Mint", "Seafoam", "Gray",
        "Red", "Magenta", "Plum", "Yellow", "Orange", "Brown", "White / Black"
    ]

    public static func contrastingForeground(for color: Color) -> Color {
        let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? .black
        let lum = 0.299 * nsColor.redComponent + 0.587 * nsColor.greenComponent + 0.114 * nsColor.blueComponent
        return lum > 0.55 ? .black : .white
    }

    public static let controlCornerRadius: CGFloat = 4
    public static let overlayCornerRadius: CGFloat = 8
}

public extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

/// Native macOS Mica-like translucent backdrop matching Windows 11 Calculator's BackdropMaterial.
public struct FluentBackdropView: NSViewRepresentable {
    public let material: NSVisualEffectView.Material

    public init(material: NSVisualEffectView.Material = .underWindowBackground) {
        self.material = material
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}
