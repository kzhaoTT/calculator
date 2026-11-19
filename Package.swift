// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WindowsCalculatorMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CalculatorMac", targets: ["CalculatorMac"]),
        .library(name: "CalculatorCore", targets: ["CalculatorCore"]),
    ],
    targets: [
        .target(
            name: "CalcManagerCompat",
            path: "macos/CalcManagerCompat",
            publicHeadersPath: "include"
        ),
        .target(
            name: "CalcManager",
            dependencies: ["CalcManagerCompat"],
            path: "src/CalcManager",
            exclude: [
                "pch.cpp",
                "pch.h",
                "CalcManager.vcxproj",
                "CalcManager.vcxproj.filters",
                "ratpak.natvis",
            ],
            sources: [
                "CalculatorHistory.cpp",
                "CalculatorManager.cpp",
                "ExpressionCommand.cpp",
                "NumberFormattingUtils.cpp",
                "UnitConverter.cpp",
                "CEngine",
                "Ratpack",
            ],
            publicHeadersPath: ".",
            cxxSettings: [
                .headerSearchPath("."),
                .headerSearchPath("Header Files"),
                .headerSearchPath("Ratpack"),
            ]
        ),
        .target(
            name: "CCalcManager",
            dependencies: ["CalcManager", "CalcManagerCompat"],
            path: "macos/CCalcManager",
            publicHeadersPath: "include"
        ),
        .target(
            name: "CalculatorCore",
            dependencies: ["CCalcManager"],
            path: "macos/CalculatorCore",
            resources: [
                .copy("Resources/CalculatorIcons.ttf"),
                .copy("Resources/Resources.resw"),
                .copy("Resources/CEngineStrings.resw"),
                .copy("Resources/CalculatorAppIcon.png"),
            ]
        ),
        .executableTarget(
            name: "CalculatorMac",
            dependencies: ["CalculatorCore"],
            path: "macos/CalculatorApp"
        ),
        .testTarget(
            name: "CalculatorTests",
            dependencies: ["CalculatorCore", "CCalcManager"],
            path: "macos/CalculatorTests"
        ),
    ],
    cxxLanguageStandard: .cxx20
)
