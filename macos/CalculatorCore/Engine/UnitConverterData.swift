import Foundation

public struct ConverterCategory: Identifiable, Hashable, Sendable {
    public let id: Int32
    public let mode: ViewMode
    public let name: String
    public let supportsNegative: Bool
    public let isCurrency: Bool

    public init(id: Int32, mode: ViewMode, name: String, supportsNegative: Bool, isCurrency: Bool) {
        self.id = id
        self.mode = mode
        self.name = name
        self.supportsNegative = supportsNegative
        self.isCurrency = isCurrency
    }
}

public struct ConverterUnit: Identifiable, Hashable, Sendable {
    public let id: Int32
    public let name: String
    public let accessibleName: String
    public let abbreviation: String
    public let isSource: Bool
    public let isTarget: Bool
    public let isWhimsical: Bool
    public let currencySymbol: String
    public let currencyCode: String

    public init(
        id: Int32,
        name: String,
        accessibleName: String? = nil,
        abbreviation: String,
        isSource: Bool = false,
        isTarget: Bool = false,
        isWhimsical: Bool = false,
        currencySymbol: String = "",
        currencyCode: String = ""
    ) {
        self.id = id
        self.name = name
        self.accessibleName = accessibleName ?? name
        self.abbreviation = abbreviation
        self.isSource = isSource
        self.isTarget = isTarget
        self.isWhimsical = isWhimsical
        self.currencySymbol = currencySymbol
        self.currencyCode = currencyCode
    }
}

public struct ConverterRatio: Sendable {
    public let fromUnitId: Int32
    public let toUnitId: Int32
    public let ratio: Double
    public let offset: Double
    public let offsetFirst: Bool
}

public struct SupplementaryResultItem: Identifiable, Equatable, Sendable {
    public let id: Int32
    public let value: String
    public let unitName: String
    public let unitAbbreviation: String
    public let isWhimsical: Bool
    public let delighterEmoji: String?

    public init(
        id: Int32,
        value: String,
        unitName: String,
        unitAbbreviation: String,
        isWhimsical: Bool,
        delighterEmoji: String? = nil
    ) {
        self.id = id
        self.value = value
        self.unitName = unitName
        self.unitAbbreviation = unitAbbreviation
        self.isWhimsical = isWhimsical
        self.delighterEmoji = delighterEmoji
    }
}

/// Exact port of `UnitConverterDataLoader.cs`, `DelighterUnitStyles.xaml`, and `CurrencyHttpClient.cs`.
/// Feeds exact unit definitions and conversion tables into the unmodified C++ `UnitConversionManager::UnitConverter`.
public final class UnitConverterDataCatalog: Sendable {
    public let categories: [ConverterCategory]
    public let unitsByCategory: [Int32: [ConverterUnit]]
    public let ratios: [ConverterRatio]
    public let currencyRatiosByCode: [String: Double]

    /// Exact emoji mappings from `src/Calculator/Views/DelighterUnitStyles.xaml`.
    public static let delighterEmojis: [Int32: String] = [
        99: "⚽",   // Soccer field
        100: "💾",  // Floppy disk
        101: "💿",  // CD
        102: "📀",  // DVD
        103: "🔋",  // Battery
        105: "📎",  // Paperclip
        107: "✈",   // Jumbo jet
        108: "💡",  // Lightbulb
        109: "🐎",  // Horse (Power)
        111: "🛀",  // Bathtub
        113: "❄",   // Snowflake
        114: "🐘",  // Elephant
        118: "👋",  // Hand (Area)
        121: "🐢",  // Turtle
        122: "✈",   // Jet (Speed)
        123: "🐳",  // Whale
        124: "☕",  // Coffee cup
        125: "🏊",  // Swimming pool
        126: "🐎",  // Horse (Speed)
        127: "📄",  // Paper
        128: "🏰",  // Castle
        129: "🍌",  // Banana
        130: "🍰",  // Slice of cake
        131: "👋",  // Hand (Length)
        132: "🚂",  // Train engine
        133: "⚽",  // Soccer ball
    ]

    public static func build(regionCode: String = ResourceProvider.shared.regionCode, res: ResourceProvider = .shared) -> UnitConverterDataCatalog {
        let useUSCustomaryAndFahrenheit = ["US", "FM", "MH", "PW"].contains(regionCode)
        let useUSCustomary = useUSCustomaryAndFahrenheit || regionCode == "LR"
        let useSI = !useUSCustomary
        let useFahrenheit = useUSCustomaryAndFahrenheit || ["BS", "KY", "LR"].contains(regionCode)
        let useWattInsteadOfKilowatt = regionCode == "GB"
        let usePyeong = ["JP", "TW", "KP", "KR"].contains(regionCode)

        let categories: [ConverterCategory] = ViewMode.converterModes.map { mode in
            ConverterCategory(
                id: Int32(mode.rawValue),
                mode: mode,
                name: res.string(mode.nameResourceKey),
                supportsNegative: mode.supportsNegative,
                isCurrency: mode == .currency
            )
        }

        var orderedByCat: [Int32: [(unit: ConverterUnit, order: Int)]] = [:]

        func loc(_ key: String) -> String { res.string(key) }

        func addUnit(
            _ mode: ViewMode,
            _ id: Int32,
            _ nameKey: String,
            _ abbrKey: String,
            _ order: Int,
            isSource: Bool = false,
            isTarget: Bool = false,
            isWhimsical: Bool = false
        ) {
            let catId = Int32(mode.rawValue)
            let name = loc(nameKey)
            let abbr = loc(abbrKey)
            let u = ConverterUnit(
                id: id,
                name: name,
                accessibleName: name,
                abbreviation: abbr,
                isSource: isSource,
                isTarget: isTarget,
                isWhimsical: isWhimsical
            )
            orderedByCat[catId, default: []].append((u, order))
        }

        // MARK: - Currency (Exact mock data from CurrencyHttpClient.cs)
        let mockCurrencies: [(id: Int32, country: String, code: String, name: String, symbol: String, rate: Double)] = [
            (201, "Mars", "MAR", "The Martian Dollar", "¤", 1.00),
            (202, "Moon", "MON", "Moon Bucks", "¤", 0.50),
            (203, "Neptune", "NEP", "Space Coins", "¤", 0.00125),
            (204, "Saturn", "SAT", "Rings", "¤", 0.25),
            (205, "Uranus", "URA", "Galaxy Credits", "¤", 2.75),
            (206, "Venus", "VEN", "Venusian Seashells", "¤", 900.00),
            (207, "Jupiter", "JUP", "Gas Money", "¤", 1.23456789123456789),
            (208, "Mercury", "MER", "Sun Notes", "¤", 2.00),
        ]
        var currencyRateMap: [String: Double] = [:]
        var currencyUnits: [(ConverterUnit, Int)] = []
        for (idx, c) in mockCurrencies.enumerated() {
            currencyRateMap[c.code] = c.rate
            let u = ConverterUnit(
                id: c.id,
                name: "\(c.country) - \(c.name)",
                accessibleName: "\(c.country) \(c.name)",
                abbreviation: c.code,
                isSource: idx == 0,
                isTarget: idx == 1,
                isWhimsical: false,
                currencySymbol: c.symbol,
                currencyCode: c.code
            )
            currencyUnits.append((u, idx))
        }
        orderedByCat[Int32(ViewMode.currency.rawValue)] = currencyUnits

        // MARK: - Area
        addUnit(.area, 1, "UnitName_Acre", "UnitAbbreviation_Acre", 9)
        addUnit(.area, 2, "UnitName_Hectare", "UnitAbbreviation_Hectare", 4)
        addUnit(.area, 3, "UnitName_SquareCentimeter", "UnitAbbreviation_SquareCentimeter", 2)
        addUnit(.area, 4, "UnitName_SquareFoot", "UnitAbbreviation_SquareFoot", 7, isSource: useSI, isTarget: useUSCustomary)
        addUnit(.area, 5, "UnitName_SquareInch", "UnitAbbreviation_SquareInch", 6)
        addUnit(.area, 6, "UnitName_SquareKilometer", "UnitAbbreviation_SquareKilometer", 5)
        addUnit(.area, 7, "UnitName_SquareMeter", "UnitAbbreviation_SquareMeter", 3, isSource: useUSCustomary, isTarget: useSI)
        addUnit(.area, 8, "UnitName_SquareMile", "UnitAbbreviation_SquareMile", 10)
        addUnit(.area, 9, "UnitName_SquareMillimeter", "UnitAbbreviation_SquareMillimeter", 1)
        addUnit(.area, 10, "UnitName_SquareYard", "UnitAbbreviation_SquareYard", 8)
        addUnit(.area, 118, "UnitName_Hand", "UnitAbbreviation_Hand", 11, isWhimsical: true)
        addUnit(.area, 127, "UnitName_Paper", "UnitAbbreviation_Paper", 12, isWhimsical: true)
        addUnit(.area, 99, "UnitName_SoccerField", "UnitAbbreviation_SoccerField", 13, isWhimsical: true)
        addUnit(.area, 128, "UnitName_Castle", "UnitAbbreviation_Castle", 14, isWhimsical: true)
        if usePyeong {
            addUnit(.area, 165, "UnitName_Pyeong", "UnitAbbreviation_Pyeong", 15)
        }

        // MARK: - Data
        addUnit(.data, 11, "UnitName_Bit", "UnitAbbreviation_Bit", 1)
        addUnit(.data, 167, "UnitName_Nibble", "UnitAbbreviation_Nibble", 2)
        addUnit(.data, 12, "UnitName_Byte", "UnitAbbreviation_Byte", 3)
        addUnit(.data, 15, "UnitName_Kilobit", "UnitAbbreviation_Kilobit", 4)
        addUnit(.data, 149, "UnitName_Kibibits", "UnitAbbreviation_Kibibits", 5)
        addUnit(.data, 16, "UnitName_Kilobyte", "UnitAbbreviation_Kilobyte", 6)
        addUnit(.data, 150, "UnitName_Kibibytes", "UnitAbbreviation_Kibibytes", 7)
        addUnit(.data, 17, "UnitName_Megabit", "UnitAbbreviation_Megabit", 8)
        addUnit(.data, 151, "UnitName_Mebibits", "UnitAbbreviation_Mebibits", 9)
        addUnit(.data, 18, "UnitName_Megabyte", "UnitAbbreviation_Megabyte", 10, isTarget: true)
        addUnit(.data, 152, "UnitName_Mebibytes", "UnitAbbreviation_Mebibytes", 11)
        addUnit(.data, 13, "UnitName_Gigabit", "UnitAbbreviation_Gigabit", 12)
        addUnit(.data, 147, "UnitName_Gibibits", "UnitAbbreviation_Gibibits", 13)
        addUnit(.data, 14, "UnitName_Gigabyte", "UnitAbbreviation_Gigabyte", 14, isSource: true)
        addUnit(.data, 148, "UnitName_Gibibytes", "UnitAbbreviation_Gibibytes", 15)
        addUnit(.data, 21, "UnitName_Terabit", "UnitAbbreviation_Terabit", 16)
        addUnit(.data, 155, "UnitName_Tebibits", "UnitAbbreviation_Tebibits", 17)
        addUnit(.data, 22, "UnitName_Terabyte", "UnitAbbreviation_Terabyte", 18)
        addUnit(.data, 156, "UnitName_Tebibytes", "UnitAbbreviation_Tebibytes", 19)
        addUnit(.data, 19, "UnitName_Petabit", "UnitAbbreviation_Petabit", 20)
        addUnit(.data, 153, "UnitName_Pebibits", "UnitAbbreviation_Pebibits", 21)
        addUnit(.data, 20, "UnitName_Petabyte", "UnitAbbreviation_Petabyte", 22)
        addUnit(.data, 154, "UnitName_Pebibytes", "UnitAbbreviation_Pebibytes", 23)
        addUnit(.data, 143, "UnitName_Exabits", "UnitAbbreviation_Exabits", 24)
        addUnit(.data, 145, "UnitName_Exbibits", "UnitAbbreviation_Exbibits", 25)
        addUnit(.data, 144, "UnitName_Exabytes", "UnitAbbreviation_Exabytes", 26)
        addUnit(.data, 146, "UnitName_Exbibytes", "UnitAbbreviation_Exbibytes", 27)
        addUnit(.data, 163, "UnitName_Zetabits", "UnitAbbreviation_Zetabits", 28)
        addUnit(.data, 161, "UnitName_Zebibits", "UnitAbbreviation_Zebibits", 29)
        addUnit(.data, 164, "UnitName_Zetabytes", "UnitAbbreviation_Zetabytes", 30)
        addUnit(.data, 162, "UnitName_Zebibytes", "UnitAbbreviation_Zebibytes", 31)
        addUnit(.data, 159, "UnitName_Yottabit", "UnitAbbreviation_Yottabit", 32)
        addUnit(.data, 157, "UnitName_Yobibits", "UnitAbbreviation_Yobibits", 33)
        addUnit(.data, 160, "UnitName_Yottabyte", "UnitAbbreviation_Yottabyte", 34)
        addUnit(.data, 158, "UnitName_Yobibytes", "UnitAbbreviation_Yobibytes", 35)
        addUnit(.data, 100, "UnitName_FloppyDisk", "UnitAbbreviation_FloppyDisk", 36, isWhimsical: true)
        addUnit(.data, 101, "UnitName_CD", "UnitAbbreviation_CD", 37, isWhimsical: true)
        addUnit(.data, 102, "UnitName_DVD", "UnitAbbreviation_DVD", 38, isWhimsical: true)

        // MARK: - Energy
        addUnit(.energy, 25, "UnitName_Electron-Volt", "UnitAbbreviation_Electron-Volt", 1)
        addUnit(.energy, 27, "UnitName_Joule", "UnitAbbreviation_Joule", 2, isSource: true)
        addUnit(.energy, 29, "UnitName_Kilojoule", "UnitAbbreviation_Kilojoule", 3)
        addUnit(.energy, 24, "UnitName_Calorie", "UnitAbbreviation_Calorie", 4)
        addUnit(.energy, 28, "UnitName_Kilocalorie", "UnitAbbreviation_Kilocalorie", 5, isTarget: true)
        addUnit(.energy, 26, "UnitName_Foot-Pound", "UnitAbbreviation_Foot-Pound", 6)
        addUnit(.energy, 23, "UnitName_BritishThermalUnit", "UnitAbbreviation_BritishThermalUnit", 7)
        addUnit(.energy, 166, "UnitName_Kilowatthour", "UnitAbbreviation_Kilowatthour", 8)
        addUnit(.energy, 103, "UnitName_Battery", "UnitAbbreviation_Battery", 9, isWhimsical: true)
        addUnit(.energy, 129, "UnitName_Banana", "UnitAbbreviation_Banana", 10, isWhimsical: true)
        addUnit(.energy, 130, "UnitName_SliceOfCake", "UnitAbbreviation_SliceOfCake", 11, isWhimsical: true)

        // MARK: - Length
        addUnit(.length, 168, "UnitName_Angstrom", "UnitAbbreviation_Angstrom", 1)
        addUnit(.length, 38, "UnitName_Nanometer", "UnitAbbreviation_Nanometer", 2)
        addUnit(.length, 35, "UnitName_Micron", "UnitAbbreviation_Micron", 3)
        addUnit(.length, 37, "UnitName_Millimeter", "UnitAbbreviation_Millimeter", 4)
        addUnit(.length, 30, "UnitName_Centimeter", "UnitAbbreviation_Centimeter", 5, isSource: useUSCustomary, isTarget: useSI)
        addUnit(.length, 34, "UnitName_Meter", "UnitAbbreviation_Meter", 6)
        addUnit(.length, 33, "UnitName_Kilometer", "UnitAbbreviation_Kilometer", 7)
        addUnit(.length, 32, "UnitName_Inch", "UnitAbbreviation_Inch", 8, isSource: useSI, isTarget: useUSCustomary)
        addUnit(.length, 31, "UnitName_Foot", "UnitAbbreviation_Foot", 9)
        addUnit(.length, 40, "UnitName_Yard", "UnitAbbreviation_Yard", 10)
        addUnit(.length, 36, "UnitName_Mile", "UnitAbbreviation_Mile", 11)
        addUnit(.length, 39, "UnitName_NauticalMile", "UnitAbbreviation_NauticalMile", 12)
        addUnit(.length, 105, "UnitName_Paperclip", "UnitAbbreviation_Paperclip", 13, isWhimsical: true)
        addUnit(.length, 131, "UnitName_Hand", "UnitAbbreviation_Hand", 14, isWhimsical: true)
        addUnit(.length, 107, "UnitName_JumboJet", "UnitAbbreviation_JumboJet", 15, isWhimsical: true)

        // MARK: - Power
        addUnit(.power, 45, "UnitName_Watt", "UnitAbbreviation_Watt", 1, isSource: useWattInsteadOfKilowatt)
        addUnit(.power, 44, "UnitName_Kilowatt", "UnitAbbreviation_Kilowatt", 2, isSource: !useWattInsteadOfKilowatt)
        addUnit(.power, 43, "UnitName_Horsepower", "UnitAbbreviation_Horsepower", 3, isTarget: true)
        addUnit(.power, 42, "UnitName_Foot-PoundPerMinute", "UnitAbbreviation_Foot-PoundPerMinute", 4)
        addUnit(.power, 41, "UnitName_BTUPerMinute", "UnitAbbreviation_BTUPerMinute", 5)
        addUnit(.power, 108, "UnitName_LightBulb", "UnitAbbreviation_LightBulb", 6, isWhimsical: true)
        addUnit(.power, 109, "UnitName_Horse", "UnitAbbreviation_Horse", 7, isWhimsical: true)
        addUnit(.power, 132, "UnitName_TrainEngine", "UnitAbbreviation_TrainEngine", 8, isWhimsical: true)

        // MARK: - Temperature
        addUnit(.temperature, 46, "UnitName_DegreesCelsius", "UnitAbbreviation_DegreesCelsius", 1, isSource: useFahrenheit, isTarget: !useFahrenheit)
        addUnit(.temperature, 47, "UnitName_DegreesFahrenheit", "UnitAbbreviation_DegreesFahrenheit", 2, isSource: !useFahrenheit, isTarget: useFahrenheit)
        addUnit(.temperature, 48, "UnitName_Kelvin", "UnitAbbreviation_Kelvin", 3)

        // MARK: - Time
        addUnit(.time, 51, "UnitName_Microsecond", "UnitAbbreviation_Microsecond", 1)
        addUnit(.time, 52, "UnitName_Millisecond", "UnitAbbreviation_Millisecond", 2)
        addUnit(.time, 54, "UnitName_Second", "UnitAbbreviation_Second", 3)
        addUnit(.time, 53, "UnitName_Minute", "UnitAbbreviation_Minute", 4, isTarget: true)
        addUnit(.time, 50, "UnitName_Hour", "UnitAbbreviation_Hour", 5, isSource: true)
        addUnit(.time, 49, "UnitName_Day", "UnitAbbreviation_Day", 6)
        addUnit(.time, 55, "UnitName_Week", "UnitAbbreviation_Week", 7)
        addUnit(.time, 56, "UnitName_Year", "UnitAbbreviation_Year", 8)

        // MARK: - Speed
        addUnit(.speed, 57, "UnitName_CentimetersPerSecond", "UnitAbbreviation_CentimetersPerSecond", 1)
        addUnit(.speed, 62, "UnitName_MetersPerSecond", "UnitAbbreviation_MetersPerSecond", 2)
        addUnit(.speed, 59, "UnitName_KilometersPerHour", "UnitAbbreviation_KilometersPerHour", 3, isSource: useUSCustomary, isTarget: useSI)
        addUnit(.speed, 58, "UnitName_FeetPerSecond", "UnitAbbreviation_FeetPerSecond", 4)
        addUnit(.speed, 63, "UnitName_MilesPerHour", "UnitAbbreviation_MilesPerHour", 5, isSource: useSI, isTarget: useUSCustomary)
        addUnit(.speed, 60, "UnitName_Knot", "UnitAbbreviation_Knot", 6)
        addUnit(.speed, 61, "UnitName_Mach", "UnitAbbreviation_Mach", 7)
        addUnit(.speed, 121, "UnitName_Turtle", "UnitAbbreviation_Turtle", 8, isWhimsical: true)
        addUnit(.speed, 126, "UnitName_Horse", "UnitAbbreviation_Horse", 9, isWhimsical: true)
        addUnit(.speed, 122, "UnitName_Jet", "UnitAbbreviation_Jet", 10, isWhimsical: true)

        // MARK: - Volume
        addUnit(.volume, 75, "UnitName_Milliliter", "UnitAbbreviation_Milliliter", 1, isSource: useUSCustomary, isTarget: useSI)
        addUnit(.volume, 64, "UnitName_CubicCentimeter", "UnitAbbreviation_CubicCentimeter", 2)
        addUnit(.volume, 74, "UnitName_Liter", "UnitAbbreviation_Liter", 3)
        addUnit(.volume, 67, "UnitName_CubicMeter", "UnitAbbreviation_CubicMeter", 4)
        addUnit(.volume, 79, "UnitName_TeaspoonUS", "UnitAbbreviation_TeaspoonUS", 5, isSource: useSI, isTarget: useUSCustomary && regionCode != "GB")
        addUnit(.volume, 78, "UnitName_TablespoonUS", "UnitAbbreviation_TablespoonUS", 6)
        addUnit(.volume, 71, "UnitName_FluidOunceUS", "UnitAbbreviation_FluidOunceUS", 7)
        addUnit(.volume, 69, "UnitName_CupUS", "UnitAbbreviation_CupUS", 8)
        addUnit(.volume, 77, "UnitName_PintUS", "UnitAbbreviation_PintUS", 9)
        addUnit(.volume, 81, "UnitName_QuartUS", "UnitAbbreviation_QuartUS", 10)
        addUnit(.volume, 73, "UnitName_GallonUS", "UnitAbbreviation_GallonUS", 11)
        addUnit(.volume, 66, "UnitName_CubicInch", "UnitAbbreviation_CubicInch", 12)
        addUnit(.volume, 65, "UnitName_CubicFoot", "UnitAbbreviation_CubicFoot", 13)
        addUnit(.volume, 68, "UnitName_CubicYard", "UnitAbbreviation_CubicYard", 14)
        addUnit(.volume, 115, "UnitName_TeaspoonUK", "UnitAbbreviation_TeaspoonUK", 15, isTarget: useUSCustomary && regionCode == "GB")
        addUnit(.volume, 116, "UnitName_TablespoonUK", "UnitAbbreviation_TablespoonUK", 16)
        addUnit(.volume, 70, "UnitName_FluidOunceUK", "UnitAbbreviation_FluidOunceUK", 17)
        addUnit(.volume, 76, "UnitName_PintUK", "UnitAbbreviation_PintUK", 18)
        addUnit(.volume, 80, "UnitName_QuartUK", "UnitAbbreviation_QuartUK", 19)
        addUnit(.volume, 72, "UnitName_GallonUK", "UnitAbbreviation_GallonUK", 20)
        addUnit(.volume, 124, "UnitName_CoffeeCup", "UnitAbbreviation_CoffeeCup", 22, isWhimsical: true)
        addUnit(.volume, 111, "UnitName_Bathtub", "UnitAbbreviation_Bathtub", 23, isWhimsical: true)
        addUnit(.volume, 125, "UnitName_SwimmingPool", "UnitAbbreviation_SwimmingPool", 24, isWhimsical: true)

        // MARK: - Weight and Mass
        addUnit(.weight, 82, "UnitName_Carat", "UnitAbbreviation_Carat", 1)
        addUnit(.weight, 90, "UnitName_Milligram", "UnitAbbreviation_Milligram", 2)
        addUnit(.weight, 83, "UnitName_Centigram", "UnitAbbreviation_Centigram", 3)
        addUnit(.weight, 84, "UnitName_Decigram", "UnitAbbreviation_Decigram", 4)
        addUnit(.weight, 86, "UnitName_Gram", "UnitAbbreviation_Gram", 5)
        addUnit(.weight, 85, "UnitName_Decagram", "UnitAbbreviation_Decagram", 6)
        addUnit(.weight, 87, "UnitName_Hectogram", "UnitAbbreviation_Hectogram", 7)
        addUnit(.weight, 88, "UnitName_Kilogram", "UnitAbbreviation_Kilogram", 8, isSource: useUSCustomary, isTarget: useSI)
        addUnit(.weight, 95, "UnitName_Tonne", "UnitAbbreviation_Tonne", 9)
        addUnit(.weight, 91, "UnitName_Ounce", "UnitAbbreviation_Ounce", 10)
        addUnit(.weight, 92, "UnitName_Pound", "UnitAbbreviation_Pound", 11, isSource: useSI, isTarget: useUSCustomary)
        addUnit(.weight, 94, "UnitName_Stone", "UnitAbbreviation_Stone", 12)
        addUnit(.weight, 93, "UnitName_ShortTon", "UnitAbbreviation_ShortTon", 13)
        addUnit(.weight, 89, "UnitName_LongTon", "UnitAbbreviation_LongTon", 14)
        addUnit(.weight, 113, "UnitName_Snowflake", "UnitAbbreviation_Snowflake", 15, isWhimsical: true)
        addUnit(.weight, 133, "UnitName_SoccerBall", "UnitAbbreviation_SoccerBall", 16, isWhimsical: true)
        addUnit(.weight, 114, "UnitName_Elephant", "UnitAbbreviation_Elephant", 17, isWhimsical: true)
        addUnit(.weight, 123, "UnitName_Whale", "UnitAbbreviation_Whale", 18, isWhimsical: true)

        // MARK: - Pressure
        addUnit(.pressure, 137, "UnitName_Atmosphere", "UnitAbbreviation_Atmosphere", 1, isSource: true)
        addUnit(.pressure, 138, "UnitName_Bar", "UnitAbbreviation_Bar", 2, isTarget: true)
        addUnit(.pressure, 139, "UnitName_KiloPascal", "UnitAbbreviation_KiloPascal", 3)
        addUnit(.pressure, 140, "UnitName_MillimeterOfMercury ", "UnitAbbreviation_MillimeterOfMercury ", 4)
        addUnit(.pressure, 141, "UnitName_Pascal", "UnitAbbreviation_Pascal", 5)
        addUnit(.pressure, 142, "UnitName_PSI", "UnitAbbreviation_PSI", 6)

        // MARK: - Angle
        addUnit(.angle, 134, "UnitName_Degree", "UnitAbbreviation_Degree", 1, isSource: true)
        addUnit(.angle, 135, "UnitName_Radian", "UnitAbbreviation_Radian", 2, isTarget: true)
        addUnit(.angle, 136, "UnitName_Gradian", "UnitAbbreviation_Gradian", 3)

        var unitsByCat: [Int32: [ConverterUnit]] = [:]
        for (catId, list) in orderedByCat {
            unitsByCat[catId] = list.sorted { $0.order < $1.order }.map { $0.unit }
        }

        // Exact conversion factors from `UnitConverterDataLoader.cs`
        let factors: [ViewMode: [Int32: Double]] = [
            .area: [
                1: 4046.8564224, 7: 1, 4: 0.09290304, 10: 0.83612736, 9: 0.000001,
                3: 0.0001, 5: 0.00064516, 8: 2589988.110336, 6: 1000000, 2: 10000,
                118: 0.012516104, 127: 0.06032246, 99: 10869.66, 128: 100000, 165: 400.0 / 121.0,
            ],
            .data: [
                11: 0.000000125, 167: 0.0000005, 12: 0.000001, 16: 0.001, 18: 1,
                14: 1000, 22: 1000000, 20: 1000000000, 144: 1e12, 164: 1e15, 160: 1e18,
                15: 0.000125, 17: 0.125, 13: 125, 21: 125000, 19: 125000000,
                143: 125e9, 163: 125e12, 159: 125e15,
                147: 134.217728, 148: 1073.741824, 149: 0.000128, 150: 0.001024,
                151: 0.131072, 152: 1.048576, 153: 140737488.355328, 154: 1125899906.842624,
                155: 137438.953472, 156: 1099511.627776, 145: 144115188075.855872,
                146: 1152921504606.846976, 161: 147573952589676.412928, 162: 1180591620717411.303424,
                157: 151115727451828646.838272, 158: 1208925819614629174.706176,
                100: 1.474560, 101: 700, 102: 4700,
            ],
            .energy: [
                24: 4.184, 28: 4184, 23: 1055.056, 29: 1000, 166: 3600000,
                25: 1.602176565e-19, 27: 1, 26: 1.3558179483314,
                103: 9000, 129: 439614, 130: 1046700,
            ],
            .length: [
                32: 0.0254, 31: 0.3048, 40: 0.9144, 36: 1609.344, 35: 0.000001,
                37: 0.001, 38: 1e-9, 168: 1e-10, 30: 0.01, 34: 1, 33: 1000, 39: 1852,
                105: 0.035052, 131: 0.18669, 107: 76,
            ],
            .power: [
                41: 17.58426666666667, 42: 0.0225969658055233, 45: 1, 44: 1000,
                43: 745.69987158227022, 108: 60, 109: 745.7, 132: 2982799.486329081,
            ],
            .time: [
                49: 86400, 54: 1, 55: 604800, 56: 31557600,
                52: 0.001, 51: 0.000001, 53: 60, 50: 3600,
            ],
            .volume: [
                69: 236.588237, 77: 473.176473, 76: 568.26125, 81: 946.352946,
                80: 1136.5225, 73: 3785.411784, 72: 4546.09, 74: 1000,
                79: 4.92892159375, 78: 14.78676478125, 64: 1, 68: 764554.857984,
                67: 1000000, 75: 1, 66: 16.387064, 65: 28316.846592,
                71: 29.5735295625, 70: 28.4130625, 115: 5.91938802083333333333,
                116: 17.7581640625, 124: 236.5882, 111: 378541.2, 125: 3750000000,
            ],
            .weight: [
                88: 1, 87: 0.1, 85: 0.01, 86: 0.001, 92: 0.45359237,
                91: 0.028349523125, 90: 0.000001, 83: 0.00001, 84: 0.0001,
                89: 1016.0469088, 95: 1000, 94: 6.35029318, 82: 0.0002,
                93: 907.18474, 113: 0.000002, 133: 0.4325, 114: 4000, 123: 90000,
            ],
            .speed: [
                57: 1, 58: 30.48, 59: 27.777777777777777777778, 60: 51.44,
                61: 34030, 62: 100, 63: 44.7, 121: 8.94, 126: 2011.5, 122: 24585,
            ],
            .angle: [
                134: 1, 135: 57.29577951308233, 136: 0.9,
            ],
            .pressure: [
                137: 1, 138: 0.9869232667160128, 139: 0.0098692326671601,
                140: 0.0013155687145324, 141: 9.869232667160128e-6, 142: 0.068045961016531,
            ],
        ]

        var allRatios: [ConverterRatio] = []

        // Temperature explicit conversions
        let tempConversions: [(Int32, Int32, Double, Double, Bool)] = [
            (46, 46, 1, 0, false),
            (46, 47, 1.8, 32, false),
            (46, 48, 1, 273.15, false),
            (47, 46, 0.55555555555555555555555555555556, -32, true),
            (47, 47, 1, 0, false),
            (47, 48, 0.55555555555555555555555555555556, 459.67, true),
            (48, 46, 1, -273.15, true),
            (48, 47, 1.8, -459.67, false),
            (48, 48, 1, 0, false),
        ]
        for t in tempConversions {
            allRatios.append(ConverterRatio(fromUnitId: t.0, toUnitId: t.1, ratio: t.2, offset: t.3, offsetFirst: t.4))
        }

        // Factor-based conversions for physical categories
        for cat in categories where cat.mode != .temperature && cat.mode != .currency {
            guard let units = unitsByCat[cat.id], let catFactors = factors[cat.mode] else { continue }
            for src in units {
                guard let srcFactor = catFactors[src.id] else { continue }
                for dst in units {
                    guard let dstFactor = catFactors[dst.id], dstFactor > 0 else { continue }
                    allRatios.append(ConverterRatio(
                        fromUnitId: src.id,
                        toUnitId: dst.id,
                        ratio: srcFactor / dstFactor,
                        offset: 0,
                        offsetFirst: false
                    ))
                }
            }
        }

        // Currency ratios: ratio(src -> dst) = rate(dst) / rate(src) (matching CurrencyDataLoader.cs)
        if let currUnits = unitsByCat[Int32(ViewMode.currency.rawValue)] {
            for src in currUnits {
                guard let srcRate = currencyRateMap[src.currencyCode], srcRate > 0 else { continue }
                for dst in currUnits {
                    guard let dstRate = currencyRateMap[dst.currencyCode], dstRate > 0 else { continue }
                    allRatios.append(ConverterRatio(
                        fromUnitId: src.id,
                        toUnitId: dst.id,
                        ratio: dstRate / srcRate,
                        offset: 0,
                        offsetFirst: false
                    ))
                }
            }
        }

        return UnitConverterDataCatalog(
            categories: categories,
            unitsByCategory: unitsByCat,
            ratios: allRatios,
            currencyRatiosByCode: currencyRateMap
        )
    }

    public init(
        categories: [ConverterCategory],
        unitsByCategory: [Int32: [ConverterUnit]],
        ratios: [ConverterRatio],
        currencyRatiosByCode: [String: Double]
    ) {
        self.categories = categories
        self.unitsByCategory = unitsByCategory
        self.ratios = ratios
        self.currencyRatiosByCode = currencyRatiosByCode
    }
}
