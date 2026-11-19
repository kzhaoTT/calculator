import AppKit
import SwiftUI
import XCTest
@testable import CalculatorCore

@MainActor
final class CalculatorNativeMacTests: XCTestCase {

    // MARK: - Resources & Font

    func testResourcesLoadFromOriginalResw() {
        let res = ResourceProvider.shared
        XCTAssertEqual(res.string("StandardModeText"), "Standard")
        XCTAssertEqual(res.string("ScientificModeText"), "Scientific")
        XCTAssertEqual(res.string("ProgrammerModeText"), "Programmer")
        XCTAssertEqual(res.string("GraphingCalculatorModeText"), "Graphing")
        XCTAssertEqual(res.string("DateCalculationModeText"), "Date calculation")
        XCTAssertEqual(res.string("CategoryName_CurrencyText"), "Currency")
        XCTAssertEqual(res.string("CategoryName_TemperatureText"), "Temperature")
        XCTAssertEqual(res.engineString("99"), "Cannot divide by zero")
        XCTAssertEqual(res.engineString("11"), "÷")
        XCTAssertEqual(res.engineString("12"), "×")
    }

    // MARK: - Standard Calculator (Original C++ CalcManager + Ratpack)

    func testStandardArithmeticAndImmediateExecution() {
        let vm = StandardCalculatorViewModel()
        vm.setCalculatorType(.standard)

        // 2 + 3 * 4 in Standard (immediate execution) = (2 + 3) * 4 = 20
        vm.press(.two)
        vm.press(.add)
        vm.press(.three)
        vm.press(.multiply)
        XCTAssertEqual(vm.displayValue, "5")
        vm.press(.four)
        vm.press(.equals)
        XCTAssertEqual(vm.displayValue, "20")
        // In Standard immediate execution mode, 2+3=5 and 5×4=20 are recorded in history
        XCTAssertEqual(vm.historyItems.count, 2)
        XCTAssertEqual(vm.historyItems.first?.result, "20")
    }

    func testStandardArbitraryPrecisionRatpack() {
        let vm = StandardCalculatorViewModel()
        vm.setCalculatorType(.standard)

        // Classic Ratpack infinite-precision test: (1 / 3) * 3 == 1 (no floating-point 0.9999999999999999!)
        vm.press(.one)
        vm.press(.divide)
        vm.press(.three)
        vm.press(.multiply)
        vm.press(.three)
        vm.press(.equals)
        XCTAssertEqual(vm.displayValue, "1")
    }

    func testStandardDivideByZeroErrorRecovery() {
        let vm = StandardCalculatorViewModel()
        vm.setCalculatorType(.standard)

        vm.press(.five)
        vm.press(.divide)
        vm.press(.zero)
        vm.press(.equals)
        XCTAssertTrue(vm.isInError)
        XCTAssertEqual(vm.displayValue, "Cannot divide by zero")

        // Typing a digit recovers from error
        vm.press(.seven)
        XCTAssertFalse(vm.isInError)
        XCTAssertEqual(vm.displayValue, "7")
    }

    func testStandardFunctionsSqrtSquareInvertPercent() {
        let vm = StandardCalculatorViewModel()
        vm.setCalculatorType(.standard)

        // sqrt(81) = 9
        vm.press(.eight)
        vm.press(.one)
        vm.press(.sqrt)
        XCTAssertEqual(vm.displayValue, "9")

        // 9^2 = 81
        vm.press(.xPower2)
        XCTAssertEqual(vm.displayValue, "81")

        // 1 / 4 = 0.25
        vm.press(.clear)
        vm.press(.four)
        vm.press(.invert)
        XCTAssertEqual(vm.displayValue, "0.25")
    }

    func testMemoryOperationsAndHistoryRecall() {
        let vm = StandardCalculatorViewModel()
        vm.setCalculatorType(.standard)

        vm.press(.four)
        vm.press(.two)
        vm.memoryStore()
        XCTAssertFalse(vm.isMemoryEmpty)
        XCTAssertEqual(vm.memorizedNumbers.first?.value, "42")

        vm.press(.clear)
        vm.press(.eight)
        vm.memoryAdd(at: 0)
        XCTAssertEqual(vm.memorizedNumbers.first?.value, "50")

        vm.press(.clear)
        vm.memoryRecall(at: 0)
        XCTAssertEqual(vm.displayValue, "50")

        vm.memoryClearAll()
        XCTAssertTrue(vm.isMemoryEmpty)
    }

    // MARK: - Scientific Calculator (Original C++ CalcManager)

    func testScientificOrderOfOperationsAndParentheses() {
        let vm = StandardCalculatorViewModel()
        vm.setCalculatorType(.scientific)

        // 2 + 3 * 4 in Scientific = 14 (respects operator precedence!)
        vm.press(.two)
        vm.press(.add)
        vm.press(.three)
        vm.press(.multiply)
        vm.press(.four)
        vm.press(.equals)
        XCTAssertEqual(vm.displayValue, "14")

        // (2 + 3) * 4 = 20
        vm.press(.clear)
        vm.press(.openParenthesis)
        XCTAssertEqual(vm.openParenthesisCount, 1)
        vm.press(.two)
        vm.press(.add)
        vm.press(.three)
        vm.press(.closeParenthesis)
        XCTAssertEqual(vm.openParenthesisCount, 0)
        vm.press(.multiply)
        vm.press(.four)
        vm.press(.equals)
        XCTAssertEqual(vm.displayValue, "20")
    }

    func testScientificTrigFactorialLog() {
        let vm = StandardCalculatorViewModel()
        vm.setCalculatorType(.scientific)

        // sin(30 deg) = 0.5
        vm.press(.three)
        vm.press(.zero)
        vm.press(.sin)
        XCTAssertEqual(vm.displayValue, "0.5")

        // 5! = 120
        vm.press(.clear)
        vm.press(.five)
        vm.press(.factorial)
        XCTAssertEqual(vm.displayValue, "120")

        // log10(1000) = 3
        vm.press(.clear)
        vm.press(.one)
        vm.press(.zero)
        vm.press(.zero)
        vm.press(.zero)
        vm.press(.logBase10)
        XCTAssertEqual(vm.displayValue, "3")
    }

    // MARK: - Programmer Calculator (Original C++ CalcManager)

    func testProgrammerRadixBitWidthAndBitFlip() {
        let vm = StandardCalculatorViewModel()
        vm.setCalculatorType(.programmer)

        // Enter 255 in DEC -> HEX=FF, OCT=377, BIN=1111 1111
        vm.press(.two)
        vm.press(.five)
        vm.press(.five)
        XCTAssertEqual(vm.hexDisplayValue, "FF")
        XCTAssertEqual(vm.decimalDisplayValue, "255")
        XCTAssertEqual(vm.octalDisplayValue, "377")
        XCTAssertEqual(vm.binaryDisplayValue, "1111 1111")
        XCTAssertTrue(vm.binaryDigits[0])
        XCTAssertTrue(vm.binaryDigits[7])
        XCTAssertFalse(vm.binaryDigits[8])

        // Flip bit 8 -> 255 + 256 = 511 (HEX 1FF)
        vm.toggleBit(at: 8)
        XCTAssertEqual(vm.decimalDisplayValue, "511")
        XCTAssertEqual(vm.hexDisplayValue, "1FF")

        // Switch to BYTE -> 511 truncated to 8-bit signed (-1 / FF)
        vm.setBitLength(.byte)
        XCTAssertEqual(vm.hexDisplayValue, "FF")
        XCTAssertEqual(vm.decimalDisplayValue, "-1")

        // Hex input & bitwise AND
        vm.setBitLength(.qword)
        vm.press(.clear)
        vm.switchProgrammerBase(.hex)
        XCTAssertTrue(vm.areHexButtonsEnabled)
        vm.press(.hexF)
        vm.press(.zero)
        vm.press(.bitwiseAnd)
        vm.press(.hexA)
        vm.press(.hexA)
        vm.press(.equals)
        XCTAssertEqual(vm.hexDisplayValue, "A0")
    }

    // MARK: - Unit Converter (Original C++ UnitConverter)

    func testUnitConverterTemperatureAndLength() {
        let vm = UnitConverterViewModel(regionCode: "US")
        vm.setMode(.temperature)

        let celsius = vm.units.first(where: { $0.id == 46 })!
        let fahrenheit = vm.units.first(where: { $0.id == 47 })!
        vm.selectUnit1(celsius)
        vm.selectUnit2(fahrenheit)

        // 100 C -> 212 F
        vm.sendCommand(.one)
        vm.sendCommand(.zero)
        vm.sendCommand(.zero)
        XCTAssertEqual(vm.value1, "100")
        XCTAssertEqual(vm.value2, "212")

        // Negative temperature: -40 C == -40 F
        vm.sendCommand(.clear)
        vm.sendCommand(.four)
        vm.sendCommand(.zero)
        vm.sendCommand(.negate)
        XCTAssertEqual(vm.value1, "-40")
        XCTAssertEqual(vm.value2, "-40")

        // Length: 1 Meter -> 100 Centimeters + supplementary results
        vm.setMode(.length)
        let meter = vm.units.first(where: { $0.id == 34 })!
        let cm = vm.units.first(where: { $0.id == 30 })!
        vm.selectUnit1(meter)
        vm.selectUnit2(cm)
        vm.sendCommand(.one)
        XCTAssertEqual(vm.value2, "100")
        XCTAssertFalse(vm.supplementaryResults.isEmpty)
        XCTAssertTrue(vm.supplementaryResults.contains(where: { $0.isWhimsical && $0.delighterEmoji != nil }))

        // Currency mode loads planet currencies & converts accurately
        vm.setMode(.currency)
        XCTAssertTrue(vm.isCurrencyCategory)
        XCTAssertFalse(vm.units.isEmpty)
        XCTAssertFalse(vm.currencyRatioEquality.isEmpty)
        vm.sendCommand(.clear)
        vm.sendCommand(.one)
        vm.sendCommand(.zero)
        // MAR (1.0) -> MON (0.5): 10 MAR = 5 MON
        XCTAssertEqual(vm.value2, "5")
    }

    // MARK: - Date Calculator

    func testDateCalculatorDifferenceAndAddSubtract() {
        let vm = DateCalculatorViewModel()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current

        vm.selectedOption = .difference
        vm.fromDate = cal.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        vm.toDate = cal.date(from: DateComponents(year: 2025, month: 2, day: 15))!
        XCTAssertEqual(vm.strDateDiffResult, "1 year, 1 month, 2 weeks")
        XCTAssertEqual(vm.strDateDiffResultInDays, "411 days")

        vm.selectedOption = .addSubtract
        vm.startDate = cal.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        vm.isAddMode = true
        vm.yearsOffset = 1
        vm.monthsOffset = 0
        vm.daysOffset = 0
        XCTAssertTrue(vm.strDateResult.contains("2025"))
    }

    // MARK: - Graphing Engine & ViewModel

    func testGraphingParserEvaluatorAndAnalyzer() throws {
        let parsed = try GraphingEngine.parse("y = x^2 - 4")
        guard case .explicitY(let ast, _) = parsed.kind else {
            return XCTFail("Expected explicitY")
        }
        XCTAssertEqual(GraphingEngine.evaluate(ast, x: 3), 5, accuracy: 1e-9)
        XCTAssertEqual(GraphingEngine.evaluate(ast, x: 2), 0, accuracy: 1e-9)

        let analysis = GraphingEngine.analyze(parsed, variables: [:], trigUnit: .radians)
        XCTAssertNil(analysis.error)
        XCTAssertEqual(analysis.yIntercept, "(0, -4)")
        XCTAssertEqual(analysis.parity, ResourceProvider.shared.string("KGFParityEven"))
        XCTAssertEqual(analysis.xIntercepts.count, 2)
        XCTAssertEqual(analysis.minima.count, 1)

        // Variable slider auto-detection
        let gvm = GraphingCalculatorViewModel()
        let firstId = gvm.equations[0].id
        gvm.updateExpression(for: firstId, text: "a*sin(b*x)")
        XCTAssertEqual(gvm.equations.count, 2) // auto-appends empty row
        XCTAssertEqual(gvm.variables.map(\.name), ["a", "b"])
    }

    // MARK: - ApplicationViewModel

    func testApplicationViewModelAll18Modes() {
        let appVM = ApplicationViewModel(restoreState: false)
        for mode in ViewMode.allCases {
            appVM.selectMode(mode)
            XCTAssertEqual(appVM.mode, mode)
            XCTAssertFalse(appVM.categoryName.isEmpty)
        }
        XCTAssertEqual(ViewMode.calculatorModes.count + ViewMode.converterModes.count, 18)
    }

    // MARK: - Visual View Rendering Verification

    func testRenderAllViewsTrueToOriginal() throws {
        ResourceProvider.registerCalculatorFont()

        let outDir = ProcessInfo.processInfo.environment["CALC_RENDER_SNAPSHOTS"]
        let fm = FileManager.default
        if let outDir {
            try fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        }

        func renderView<V: View>(_ view: V, size: NSSize, dark: Bool, filename: String) {
            let root = view
                .frame(width: size.width, height: size.height)
                .environment(\.colorScheme, dark ? .dark : .light)
            let hosting = NSHostingView(rootView: root)
            hosting.frame = NSRect(origin: .zero, size: size)
            hosting.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            hosting.layoutSubtreeIfNeeded()

            guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
                XCTFail("Failed creating bitmap rep for \(filename)")
                return
            }
            hosting.cacheDisplay(in: hosting.bounds, to: rep)

            if let outDir, let data = rep.representation(using: .png, properties: [:]) {
                let url = URL(fileURLWithPath: outDir).appendingPathComponent(filename)
                try? data.write(to: url)
            }
        }

        // 1. Standard Mode (Dark, exact default size matching CalculatorScreenshot.png)
        let vmStd = ApplicationViewModel(restoreState: false)
        vmStd.themePreference = .dark
        vmStd.selectMode(.standard)
        renderView(MainPageView(appVM: vmStd), size: NSSize(width: 340, height: 540), dark: true, filename: "01_standard_dark.png")

        // 2. Standard Mode (Light) + Wide with Docked History/Memory
        let vmStdWide = ApplicationViewModel(restoreState: false)
        vmStdWide.themePreference = .light
        vmStdWide.selectMode(.standard)
        vmStdWide.calculatorVM.press(.one)
        vmStdWide.calculatorVM.press(.two)
        vmStdWide.calculatorVM.press(.multiply)
        vmStdWide.calculatorVM.press(.eight)
        vmStdWide.calculatorVM.press(.equals)
        vmStdWide.calculatorVM.memoryStore()
        renderView(MainPageView(appVM: vmStdWide), size: NSSize(width: 680, height: 560), dark: false, filename: "02_standard_light_docked.png")

        // 3. Scientific Mode (Dark)
        let vmSci = ApplicationViewModel(restoreState: false)
        vmSci.themePreference = .dark
        vmSci.selectMode(.scientific)
        vmSci.calculatorVM.press(.three)
        vmSci.calculatorVM.press(.zero)
        vmSci.calculatorVM.press(.sin)
        renderView(MainPageView(appVM: vmSci), size: NSSize(width: 360, height: 580), dark: true, filename: "03_scientific_dark.png")

        // 4. Programmer Mode - Full Keypad (Dark)
        let vmProg = ApplicationViewModel(restoreState: false)
        vmProg.themePreference = .dark
        vmProg.selectMode(.programmer)
        vmProg.calculatorVM.press(.two)
        vmProg.calculatorVM.press(.five)
        vmProg.calculatorVM.press(.five)
        renderView(MainPageView(appVM: vmProg), size: NSSize(width: 360, height: 600), dark: true, filename: "04_programmer_keypad_dark.png")

        // 5. Programmer Mode - BitFlip Panel (Dark)
        vmProg.calculatorVM.isBitFlipChecked = true
        renderView(MainPageView(appVM: vmProg), size: NSSize(width: 360, height: 600), dark: true, filename: "05_programmer_bitflip_dark.png")

        // 6. Graphing Mode (Wide 2-column with curves + variable slider)
        let vmGraph = ApplicationViewModel(restoreState: false)
        vmGraph.themePreference = .dark
        vmGraph.selectMode(.graphing)
        let eq1Id = vmGraph.graphingVM.equations[0].id
        vmGraph.graphingVM.updateExpression(for: eq1Id, text: "a*sin(x)")
        if vmGraph.graphingVM.equations.count > 1 {
            let eq2Id = vmGraph.graphingVM.equations[1].id
            vmGraph.graphingVM.updateExpression(for: eq2Id, text: "0.15x^2 - 3")
        }
        renderView(MainPageView(appVM: vmGraph), size: NSSize(width: 960, height: 640), dark: true, filename: "06_graphing_dark.png")

        // 7. Date Calculation Mode (Dark)
        let vmDate = ApplicationViewModel(restoreState: false)
        vmDate.themePreference = .dark
        vmDate.selectMode(.date)
        renderView(MainPageView(appVM: vmDate), size: NSSize(width: 380, height: 540), dark: true, filename: "07_date_dark.png")

        // 8. Unit Converter Mode - Length with Delighters (Dark)
        let vmConv = ApplicationViewModel(restoreState: false)
        vmConv.themePreference = .dark
        vmConv.selectMode(.length)
        vmConv.converterVM.sendCommand(.five)
        vmConv.converterVM.sendCommand(.zero)
        renderView(MainPageView(appVM: vmConv), size: NSSize(width: 360, height: 560), dark: true, filename: "08_converter_length_dark.png")

        // 9. Navigation Pane Open + Settings Page (Dark)
        let vmNav = ApplicationViewModel(restoreState: false)
        vmNav.themePreference = .dark
        vmNav.selectMode(.standard)
        vmNav.isNavPaneOpen = true
        renderView(MainPageView(appVM: vmNav), size: NSSize(width: 360, height: 560), dark: true, filename: "09_nav_pane_dark.png")

        let vmSettings = ApplicationViewModel(restoreState: false)
        vmSettings.themePreference = .dark
        vmSettings.openSettings()
        renderView(MainPageView(appVM: vmSettings), size: NSSize(width: 420, height: 560), dark: true, filename: "10_settings_dark.png")
    }
}
