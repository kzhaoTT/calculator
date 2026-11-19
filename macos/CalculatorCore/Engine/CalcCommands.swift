import Foundation

/// Exact enum values from `src/CalcManager/Command.h` and `NumbersAndOperatorsEnum.cs`.
public enum CalcCommand: Int32, CaseIterable, Sendable {
    case none = 0

    case sign = 80
    case clear = 81
    case clearEntry = 82
    case backspace = 83
    case decimal = 84

    case bitwiseAnd = 86
    case bitwiseOr = 87
    case bitwiseXor = 88
    case lsh = 89
    case rsh = 90
    case divide = 91
    case multiply = 92
    case add = 93
    case subtract = 94
    case mod = 95
    case yRootX = 96
    case xPowerY = 97

    case rol = 99
    case ror = 100
    case bitwiseNot = 101

    case sin = 102
    case cos = 103
    case tan = 104
    case sinh = 105
    case cosh = 106
    case tanh = 107

    case logBaseE = 108
    case logBase10 = 109
    case sqrt = 110
    case xPower2 = 111
    case cube = 112
    case factorial = 113
    case invert = 114
    case dms = 115
    case cubeRoot = 116
    case tenPowerX = 117
    case percent = 118

    case fToE = 119
    case pi = 120
    case equals = 121

    case exp = 127
    case openParenthesis = 128
    case closeParenthesis = 129

    case zero = 130
    case one = 131
    case two = 132
    case three = 133
    case four = 134
    case five = 135
    case six = 136
    case seven = 137
    case eight = 138
    case nine = 139
    case hexA = 140
    case hexB = 141
    case hexC = 142
    case hexD = 143
    case hexE = 144
    case hexF = 145

    case modeBasic = 200
    case modeScientific = 201
    case invSin = 202
    case invCos = 203
    case invTan = 204
    case ePowerX = 205
    case invSinh = 206
    case invCosh = 207
    case invTanh = 208
    case modeProgrammer = 209

    case hex = 313
    case dec = 314
    case oct = 315
    case bin = 316
    case qword = 317
    case dword = 318
    case word = 319
    case byte = 320

    case degree = 321
    case radians = 322
    case grads = 323
    case degrees = 324
    case hyp = 325

    case sec = 400
    case invSec = 401
    case csc = 402
    case invCsc = 403
    case cot = 404
    case invCot = 405
    case sech = 406
    case invSech = 407
    case csch = 408
    case invCsch = 409
    case coth = 410
    case invCoth = 411

    case twoPowerX = 412
    case abs = 413
    case floor = 414
    case ceil = 415
    case rolC = 416
    case rorC = 417

    case logBaseY = 500
    case nand = 501
    case nor = 502
    case rshL = 505

    case rand = 600
    case euler = 601

    public static func binPos(_ bitIndex: Int) -> Int32 {
        Int32(700 + bitIndex)
    }

    public static func digit(_ d: Int) -> CalcCommand {
        CalcCommand(rawValue: Int32(130 + d)) ?? .zero
    }
}

/// UnitConverter commands matching `UnitConversionManager::Command` in `src/CalcManager/Command.h`.
public enum UnitConverterCommand: Int32, Sendable {
    case zero = 0
    case one = 1
    case two = 2
    case three = 3
    case four = 4
    case five = 5
    case six = 6
    case seven = 7
    case eight = 8
    case nine = 9
    case decimal = 10
    case negate = 11
    case backspace = 12
    case clear = 13
    case reset = 14
    case none = 15
}

/// Exact ViewMode enum from `src/Calculator.ViewModels/Common/NavCategory.cs`.
public enum ViewMode: Int, CaseIterable, Identifiable, Sendable {
    case standard = 0
    case scientific = 1
    case programmer = 2
    case date = 3
    case volume = 4
    case length = 5
    case weight = 6
    case temperature = 7
    case energy = 8
    case area = 9
    case speed = 10
    case time = 11
    case power = 12
    case data = 13
    case pressure = 14
    case angle = 15
    case currency = 16
    case graphing = 17

    public var id: Int { rawValue }

    public var groupType: CategoryGroupType {
        switch self {
        case .standard, .scientific, .graphing, .programmer, .date:
            return .calculator
        default:
            return .converter
        }
    }

    public var isCalculatorMode: Bool {
        self == .standard || self == .scientific || self == .programmer
    }

    public var isConverterMode: Bool {
        groupType == .converter
    }

    public var supportsNegative: Bool {
        switch self {
        case .standard, .scientific, .graphing, .programmer, .date, .temperature, .power, .angle:
            return true
        default:
            return false
        }
    }

    public var nameResourceKey: String {
        switch self {
        case .standard: return "StandardModeText"
        case .scientific: return "ScientificModeText"
        case .graphing: return "GraphingCalculatorModeText"
        case .programmer: return "ProgrammerModeText"
        case .date: return "DateCalculationModeText"
        case .currency: return "CategoryName_CurrencyText"
        case .volume: return "CategoryName_VolumeText"
        case .length: return "CategoryName_LengthText"
        case .weight: return "CategoryName_WeightText"
        case .temperature: return "CategoryName_TemperatureText"
        case .energy: return "CategoryName_EnergyText"
        case .area: return "CategoryName_AreaText"
        case .speed: return "CategoryName_SpeedText"
        case .time: return "CategoryName_TimeText"
        case .power: return "CategoryName_PowerText"
        case .data: return "CategoryName_DataText"
        case .pressure: return "CategoryName_PressureText"
        case .angle: return "CategoryName_AngleText"
        }
    }

    public var displayName: String {
        ResourceProvider.shared.string(nameResourceKey)
    }

    public var glyph: String {
        switch self {
        case .standard: return CalcGlyph.navStandard
        case .scientific: return CalcGlyph.navScientific
        case .graphing: return CalcGlyph.navGraphing
        case .programmer: return CalcGlyph.navProgrammer
        case .date: return CalcGlyph.navDate
        case .currency: return CalcGlyph.navCurrency
        case .volume: return CalcGlyph.navVolume
        case .length: return CalcGlyph.navLength
        case .weight: return CalcGlyph.navWeight
        case .temperature: return CalcGlyph.navTemperature
        case .energy: return CalcGlyph.navEnergy
        case .area: return CalcGlyph.navArea
        case .speed: return CalcGlyph.navSpeed
        case .time: return CalcGlyph.navTime
        case .power: return CalcGlyph.navPower
        case .data: return CalcGlyph.navData
        case .pressure: return CalcGlyph.navPressure
        case .angle: return CalcGlyph.navAngle
        }
    }

    /// Exact display order from `NavCategoryStates.CategoryManifest`.
    public static let calculatorModes: [ViewMode] = [
        .standard, .scientific, .graphing, .programmer, .date
    ]

    public static let converterModes: [ViewMode] = [
        .currency, .volume, .length, .weight, .temperature, .energy,
        .area, .speed, .time, .power, .data, .pressure, .angle
    ]
}

public enum CategoryGroupType: Sendable {
    case calculator
    case converter
}

public enum NumberBase: Int32, CaseIterable, Sendable {
    case hex = 0
    case decimal = 1
    case octal = 2
    case binary = 3

    public var radix: UInt32 {
        switch self {
        case .hex: return 16
        case .decimal: return 10
        case .octal: return 8
        case .binary: return 2
        }
    }
}

public enum BitLength: Int, CaseIterable, Sendable {
    case qword = 0 // 64-bit
    case dword = 1 // 32-bit
    case word = 2  // 16-bit
    case byte = 3  // 8-bit

    public var label: String {
        switch self {
        case .qword: return "QWORD"
        case .dword: return "DWORD"
        case .word: return "WORD"
        case .byte: return "BYTE"
        }
    }

    public var bitCount: Int {
        switch self {
        case .qword: return 64
        case .dword: return 32
        case .word: return 16
        case .byte: return 8
        }
    }

    public var command: CalcCommand {
        switch self {
        case .qword: return .qword
        case .dword: return .dword
        case .word: return .word
        case .byte: return .byte
        }
    }

    public var next: BitLength {
        switch self {
        case .qword: return .dword
        case .dword: return .word
        case .word: return .byte
        case .byte: return .qword
        }
    }
}

public enum AngleMode: Int, CaseIterable, Sendable {
    case degrees = 0
    case radians = 1
    case gradians = 2

    public var label: String {
        switch self {
        case .degrees: return "DEG"
        case .radians: return "RAD"
        case .gradians: return "GRAD"
        }
    }

    public var command: CalcCommand {
        switch self {
        case .degrees: return .degree
        case .radians: return .radians
        case .gradians: return .grads
        }
    }

    public var next: AngleMode {
        switch self {
        case .degrees: return .radians
        case .radians: return .gradians
        case .gradians: return .degrees
        }
    }
}

public enum BitShiftMode: Int, CaseIterable, Identifiable, Sendable {
    case arithmetic = 0
    case logical = 1
    case rotateCircular = 2
    case rotateCarry = 3

    public var id: Int { rawValue }

    public var label: String {
        let res = ResourceProvider.shared
        switch self {
        case .arithmetic: return res.string("arithmeticShiftButton.Content", fallback: "Arithmetic shift")
        case .logical: return res.string("logicalShiftButton.Content", fallback: "Logical shift")
        case .rotateCircular: return res.string("rotateCircularButton.Content", fallback: "Rotate circular shift")
        case .rotateCarry: return res.string("rotateCarryShiftButton.Content", fallback: "Rotate through carry circular shift")
        }
    }

    public var leftCommand: CalcCommand {
        switch self {
        case .arithmetic, .logical: return .lsh
        case .rotateCircular: return .rol
        case .rotateCarry: return .rolC
        }
    }

    public var rightCommand: CalcCommand {
        switch self {
        case .arithmetic: return .rsh
        case .logical: return .rshL
        case .rotateCircular: return .ror
        case .rotateCarry: return .rorC
        }
    }
}

public enum ExpressionTokenType: Int32, Sendable {
    case operand = 0
    case `operator` = 1
    case separator = 2
}

public struct ExpressionToken: Identifiable, Equatable, Sendable {
    public let id: Int
    public let token: String
    public let commandIndex: Int32
    public let type: ExpressionTokenType

    public init(id: Int, token: String, commandIndex: Int32, type: ExpressionTokenType) {
        self.id = id
        self.token = token
        self.commandIndex = commandIndex
        self.type = type
    }
}

public struct HistoryItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let expression: String
    public let result: String
    public let engineIndex: UInt32

    public init(id: UUID = UUID(), expression: String, result: String, engineIndex: UInt32) {
        self.id = id
        self.expression = expression
        self.result = result
        self.engineIndex = engineIndex
    }
}

public struct MemoryItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var position: Int
    public var value: String

    public init(id: UUID = UUID(), position: Int, value: String) {
        self.id = id
        self.position = position
        self.value = value
    }
}
