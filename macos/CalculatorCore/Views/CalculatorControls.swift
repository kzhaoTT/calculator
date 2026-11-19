import SwiftUI

public enum CalcButtonVariant {
    case numeric
    case `operator`
    case accent
    case subtle
    case emphasizedToggle(isOn: Bool)
}

/// Native macOS button styled 1:1 with Windows 11 Calculator's Fluent `CalcButtonStyle` in `App.xaml`.
public struct FluentCalcButton<Label: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    @State private var isPressed = false

    private let variant: CalcButtonVariant
    private let isEnabled: Bool
    private let isLit: Bool
    private let cornerRadius: CGFloat
    private let action: () -> Void
    private let label: () -> Label

    public init(
        variant: CalcButtonVariant = .operator,
        isEnabled: Bool = true,
        isLit: Bool = false,
        cornerRadius: CGFloat = CalcTheme.controlCornerRadius,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.variant = variant
        self.isEnabled = isEnabled
        self.isLit = isLit
        self.cornerRadius = cornerRadius
        self.action = action
        self.label = label
    }

    public var body: some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        let effectivePressed = isPressed || isLit

        Button(action: action) {
            label()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(foregroundColor(theme: theme, pressed: effectivePressed))
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(backgroundColor(theme: theme, pressed: effectivePressed))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(borderColor(theme: theme), lineWidth: showsBorder ? 0.5 : 0)
                )
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(PressTrackingButtonStyle(isPressed: $isPressed))
        .disabled(!isEnabled)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.083)) {
                isHovered = hovering
            }
        }
    }

    private var showsBorder: Bool {
        switch variant {
        case .subtle: return false
        default: return true
        }
    }

    private func borderColor(theme: CalcTheme) -> Color {
        switch variant {
        case .accent:
            return Color.clear
        case .emphasizedToggle(let isOn) where isOn:
            return Color.clear
        default:
            return theme.buttonBorder
        }
    }

    private func backgroundColor(theme: CalcTheme, pressed: Bool) -> Color {
        switch variant {
        case .numeric:
            if !isEnabled { return theme.numericFillDisabled }
            if pressed { return theme.numericFillPressed }
            if isHovered { return theme.numericFillHover }
            return theme.numericFillDefault

        case .operator:
            if !isEnabled { return theme.operatorFillDisabled }
            if pressed { return theme.operatorFillPressed }
            if isHovered { return theme.operatorFillHover }
            return theme.operatorFillDefault

        case .accent:
            if !isEnabled { return theme.accentDisabled }
            if pressed { return theme.accentPressed }
            if isHovered { return theme.accentHover }
            return theme.accentDefault

        case .subtle:
            if !isEnabled { return .clear }
            if pressed { return theme.subtleFillPressed }
            if isHovered { return theme.subtleFillHover }
            return .clear

        case .emphasizedToggle(let isOn):
            if isOn {
                if !isEnabled { return theme.accentDisabled }
                if pressed { return theme.accentPressed }
                if isHovered { return theme.accentHover }
                return theme.accentDefault
            } else {
                if !isEnabled { return theme.operatorFillDisabled }
                if pressed { return theme.operatorFillPressed }
                if isHovered { return theme.operatorFillHover }
                return theme.operatorFillDefault
            }
        }
    }

    private func foregroundColor(theme: CalcTheme, pressed: Bool) -> Color {
        if !isEnabled { return theme.textDisabled }
        switch variant {
        case .accent:
            return theme.textOnAccent
        case .emphasizedToggle(let isOn) where isOn:
            return theme.textOnAccent
        default:
            return pressed ? theme.textSecondary : theme.textPrimary
        }
    }
}

public struct PressTrackingButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    public init(isPressed: Binding<Bool>) {
        self._isPressed = isPressed
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
    }
}

/// Parenthesis button with open parenthesis counter badge matching `ParenthesisCalcButtonStyle` in `App.xaml`.
public struct ParenthesisCalcButton: View {
    let count: UInt32
    let fontSize: CGFloat
    let isEnabled: Bool
    let isLit: Bool
    let action: () -> Void

    public init(count: UInt32, fontSize: CGFloat, isEnabled: Bool = true, isLit: Bool = false, action: @escaping () -> Void) {
        self.count = count
        self.fontSize = fontSize
        self.isEnabled = isEnabled
        self.isLit = isLit
        self.action = action
    }

    public var body: some View {
        FluentCalcButton(variant: .operator, isEnabled: isEnabled, isLit: isLit, action: action) {
            ZStack {
                Text("(")
                    .font(.system(size: fontSize, weight: .regular))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: max(10, fontSize * 0.55), weight: .semibold))
                        .offset(x: fontSize * 0.55, y: fontSize * 0.35)
                }
            }
        }
    }
}

/// Subtle caption toggle button with bottom accent indicator pill (used for `F-E`, Programmer FullKeypad / BitFlip).
public struct IndicatorToggleButton<Label: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    @State private var isPressed = false

    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void
    let label: () -> Label

    public init(
        isSelected: Bool,
        isEnabled: Bool = true,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.isSelected = isSelected
        self.isEnabled = isEnabled
        self.action = action
        self.label = label
    }

    public var body: some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        Button(action: action) {
            ZStack(alignment: .bottom) {
                label()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(isEnabled ? (isSelected ? theme.accentDefault : theme.textPrimary) : theme.textDisabled)
                if isSelected {
                    Capsule()
                        .fill(theme.accentDefault)
                        .frame(width: 24, height: 3)
                        .padding(.bottom, 2)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: CalcTheme.controlCornerRadius, style: .continuous)
                    .fill(isPressed ? theme.subtleFillPressed : (isHovered ? theme.subtleFillHover : .clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: CalcTheme.controlCornerRadius, style: .continuous))
        }
        .buttonStyle(PressTrackingButtonStyle(isPressed: $isPressed))
        .disabled(!isEnabled)
        .onHover { isHovered = $0 }
    }
}

/// Operator Panel button (`Trigonometry ⌄`, `Function ⌄`, `Bitwise ⌄`, `Bit shift ⌄`, `Inequalities ⌄`).
public struct OperatorPanelDropdownButton<PopoverContent: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    let glyph: String
    let title: String
    let isEnabled: Bool
    let fontSize: CGFloat
    let glyphSize: CGFloat
    @Binding var isPresented: Bool
    let popoverContent: () -> PopoverContent

    public init(
        glyph: String,
        title: String,
        isEnabled: Bool = true,
        fontSize: CGFloat = 12,
        glyphSize: CGFloat = 16,
        isPresented: Binding<Bool>,
        @ViewBuilder popoverContent: @escaping () -> PopoverContent
    ) {
        self.glyph = glyph
        self.title = title
        self.isEnabled = isEnabled
        self.fontSize = fontSize
        self.glyphSize = glyphSize
        self._isPresented = isPresented
        self.popoverContent = popoverContent
    }

    public var body: some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 7) {
                CalcGlyphText(glyph, size: glyphSize)
                Text(title)
                    .font(.system(size: fontSize, weight: .regular))
                    .lineLimit(1)
                CalcGlyphText(CalcGlyph.chevronDown, size: max(9, fontSize * 0.78))
                    .padding(.top, 1)
            }
            .foregroundStyle(isEnabled ? theme.textPrimary : theme.textDisabled)
            .padding(.horizontal, 10)
            .frame(maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: CalcTheme.controlCornerRadius, style: .continuous)
                    .fill(isPresented ? theme.subtleFillPressed : (isHovered ? theme.subtleFillHover : .clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: CalcTheme.controlCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { isHovered = $0 }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            popoverContent()
                .padding(6)
                .background(theme.flyoutBackground)
        }
    }
}

/// Responsive auto-scaling calculation result display matching `CalculationResult.cs` / `App.xaml`.
public struct CalculationResultView: View {
    @Environment(\.colorScheme) private var colorScheme

    let text: String
    let maxFontSize: CGFloat
    let minFontSize: CGFloat
    let alignment: HorizontalAlignment
    let fontWeight: Font.Weight
    let onCopy: () -> Void
    let onPaste: (() -> Void)?

    public init(
        text: String,
        maxFontSize: CGFloat = 46,
        minFontSize: CGFloat = 14,
        alignment: HorizontalAlignment = .trailing,
        fontWeight: Font.Weight = .semibold,
        onCopy: @escaping () -> Void,
        onPaste: (() -> Void)? = nil
    ) {
        self.text = text
        self.maxFontSize = maxFontSize
        self.minFontSize = minFontSize
        self.alignment = alignment
        self.fontWeight = fontWeight
        self.onCopy = onCopy
        self.onPaste = onPaste
    }

    public var body: some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        let res = ResourceProvider.shared
        Text(text)
            .font(.system(size: maxFontSize, weight: fontWeight))
            .monospacedDigit()
            .foregroundStyle(theme.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(max(0.22, minFontSize / max(1, maxFontSize)))
            .frame(maxWidth: .infinity, alignment: alignment == .trailing ? .trailing : .leading)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
            .contextMenu {
                Button(res.string("copyMenuItem", fallback: "Copy")) {
                    onCopy()
                }
                if let onPaste {
                    Button(res.string("pasteMenuItem", fallback: "Paste")) {
                        onPaste()
                    }
                }
            }
    }
}
