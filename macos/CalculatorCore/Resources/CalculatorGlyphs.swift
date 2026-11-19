import SwiftUI

/// Exact Unicode code points from Windows Calculator's `CalculatorIcons.ttf` ("Calculator Fluent Icons").
public enum CalcGlyph {
    // Chrome / Navigation / Common UI
    public static let back = "\u{E72B}"
    public static let chevronDown = "\u{E70D}"
    public static let chevronUp = "\u{E70E}"
    public static let history = "\u{E81C}"
    public static let delete = "\u{E74D}"
    public static let settings = "\u{E713}"
    public static let palette = "\u{E790}"
    public static let enterAlwaysOnTop = "\u{EE49}"
    public static let exitAlwaysOnTop = "\u{EE47}"
    public static let scrollLeft = "\u{E96F}"
    public static let scrollRight = "\u{E970}"
    public static let share = "\u{E72D}"

    // Navigation menu category icons (from NavCategory.cs)
    public static let navStandard = "\u{E8EF}"
    public static let navScientific = "\u{F196}"
    public static let navGraphing = "\u{F770}"
    public static let navProgrammer = "\u{ECCE}"
    public static let navDate = "\u{E787}"
    public static let navCurrency = "\u{EB0D}"
    public static let navVolume = "\u{F1AA}"
    public static let navLength = "\u{ECC6}"
    public static let navWeight = "\u{F4C1}"
    public static let navTemperature = "\u{E7A3}"
    public static let navEnergy = "\u{ECAD}"
    public static let navArea = "\u{E809}"
    public static let navSpeed = "\u{EADA}"
    public static let navTime = "\u{E917}"
    public static let navPower = "\u{E945}"
    public static let navData = "\u{F20F}"
    public static let navPressure = "\u{EC4A}"
    public static let navAngle = "\u{F515}"

    // Standard & Core Math Operators
    public static let percent = "\u{E94C}"
    public static let backspace = "\u{E94F}"
    public static let invert = "\u{F7C9}"
    public static let xPower2 = "\u{F7C8}"
    public static let sqrt = "\u{F899}"
    public static let divide = "\u{E94A}"
    public static let multiply = "\u{E947}"
    public static let subtract = "\u{E949}"
    public static let add = "\u{E948}"
    public static let equals = "\u{E94E}"
    public static let negate = "\u{F898}"

    // Memory Toolbar
    public static let memClear = "\u{F754}"
    public static let memRecall = "\u{F755}"
    public static let memStore = "\u{F756}"
    public static let memAdd = "\u{F757}"
    public static let memSubtract = "\u{F758}"
    public static let memFlyout = "\u{E61D}"

    // Scientific Operators
    public static let trig = "\u{F892}"
    public static let function = "\u{F893}"
    public static let second = "\u{F897}"
    public static let pi = "\u{F7CF}"
    public static let xPowerY = "\u{F7CA}"
    public static let tenPowerX = "\u{F7CC}"
    public static let cube = "\u{F7CB}"
    public static let cubeRoot = "\u{F881}"
    public static let yRootX = "\u{F7CD}"
    public static let twoPowerX = "\u{F882}"
    public static let logBaseY = "\u{F883}"
    public static let ePowerX = "\u{F7CE}"
    public static let abs = "\u{F884}"
    public static let floor = "\u{F885}"
    public static let ceil = "\u{F886}"
    public static let factorial = "\u{F887}"
    public static let dms = "\u{F890}"
    public static let degrees = "\u{F891}"

    // Programmer Operators
    public static let bitwise = "\u{F895}"
    public static let bitShift = "\u{E301}"
    public static let lsh = "\u{F88E}"
    public static let rsh = "\u{F88F}"
    public static let fullKeypad = "\u{E75F}"
    public static let bitFlip = "\u{F7D0}"

    // Graphing Operators & Controls
    public static let inequality = "\u{F894}"
    public static let lessThan = "\u{F88A}"
    public static let lessThanOrEqual = "\u{F88B}"
    public static let greaterThan = "\u{F88C}"
    public static let greaterThanOrEqual = "\u{F88D}"
    public static let trace = "\u{E3B3}"
    public static let graphSettings = "\u{E3B4}"
    public static let graphNegate = "\u{E3B5}"
    public static let graphViewBase = "\u{E45E}"
    public static let graphViewDot = "\u{E45D}"
    public static let hideEye = "\u{F6AC}"
    public static let showEye = "\u{E890}"
    public static let errorIcon = "\u{F736}"
    public static let removeX = "\u{ECC9}"
}

public struct CalcGlyphText: View {
    public let glyph: String
    public let size: CGFloat

    public init(_ glyph: String, size: CGFloat = 16) {
        self.glyph = glyph
        self.size = size
    }

    public var body: some View {
        Text(glyph)
            .font(.custom("Calculator Fluent Icons", size: size))
    }
}

/// Crisp Fluent Design Windows 11 Calculator icon matching `docs/Images/CalculatorScreenshot.png`.
public struct WindowsCalculatorAppIcon: View {
    public var size: CGFloat = 18

    public init(size: CGFloat = 18) {
        self.size = size
    }

    public var body: some View {
        let corner = max(2, size * 0.14)
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xB8C2CC), Color(hex: 0x7A8694)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: size * 0.08) {
                // Top LCD screen
                RoundedRectangle(cornerRadius: max(1, size * 0.06), style: .continuous)
                    .fill(Color(hex: 0x1E293B))
                    .frame(height: size * 0.24)

                // Key grid (3x3 with blue equals key)
                let keyH = size * 0.13
                VStack(spacing: size * 0.05) {
                    HStack(spacing: size * 0.05) {
                        keyRect(Color.white.opacity(0.92), height: keyH)
                        keyRect(Color.white.opacity(0.92), height: keyH)
                        keyRect(Color.white.opacity(0.92), height: keyH)
                    }
                    HStack(spacing: size * 0.05) {
                        keyRect(Color.white.opacity(0.92), height: keyH)
                        keyRect(Color.white.opacity(0.92), height: keyH)
                        keyRect(Color.white.opacity(0.92), height: keyH)
                    }
                    HStack(spacing: size * 0.05) {
                        keyRect(Color.white.opacity(0.92), height: keyH)
                        keyRect(Color.white.opacity(0.92), height: keyH)
                        keyRect(Color(hex: 0x29A9FF), height: keyH)
                    }
                }
            }
            .padding(size * 0.11)
        }
        .frame(width: size * 0.84, height: size)
    }

    private func keyRect(_ color: Color, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: max(0.8, height * 0.25), style: .continuous)
            .fill(color)
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }
}

/// Crisp Fluent Design hamburger icon (3 thin horizontal lines, matching Windows Segoe Fluent Icons 0xE700).
public struct HamburgerIconView: View {
    public var size: CGFloat = 16

    public init(size: CGFloat = 16) {
        self.size = size
    }

    public var body: some View {
        VStack(spacing: 4) {
            Capsule().frame(width: size, height: 1.2)
            Capsule().frame(width: size, height: 1.2)
            Capsule().frame(width: size, height: 1.2)
        }
    }
}
