import AppKit
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
public final class GraphEquationItem: Identifiable {
    public nonisolated let id: UUID = UUID()
    public var functionLabelIndex: Int
    public var expression: String
    public var colorIndex: Int
    public var lineStyle: EquationLineStyle = .solid
    public var isLineEnabled: Bool = true
    public var isLastItemInList: Bool = false

    public var parsed: ParsedEquation?
    public var errorText: String?
    public var hasError: Bool { errorText != nil }
    public var isInequality: Bool { parsed?.isInequality ?? false }

    public init(functionLabelIndex: Int, expression: String = "", colorIndex: Int, isLastItemInList: Bool = false) {
        self.functionLabelIndex = functionLabelIndex
        self.expression = expression
        self.colorIndex = colorIndex
        self.isLastItemInList = isLastItemInList
    }
}

@MainActor
@Observable
public final class GraphVariableItem: Identifiable {
    public nonisolated var id: String { name }
    public let name: String
    public var value: Double = 1.0
    public var minValue: Double = -10.0
    public var maxValue: Double = 10.0
    public var step: Double = 0.1
    public var sliderSettingsVisible: Bool = false

    public init(name: String, value: Double = 1.0) {
        self.name = name
        self.value = value
    }
}

@MainActor
@Observable
public final class GraphingCalculatorViewModel {
    public var equations: [GraphEquationItem] = []
    public var variables: [GraphVariableItem] = []
    public var focusedEquationId: UUID?

    // Viewport range (default -10..10 matching Windows Calculator)
    public var xMin: Double = -10.0
    public var xMax: Double = 10.0
    public var yMin: Double = -10.0
    public var yMax: Double = 10.0

    // Graph options
    public var trigUnit: GraphTrigUnit = .radians
    public var lineWidth: Double = 2.0
    public var isMatchAppTheme: Bool = false // Windows Calculator defaults to Always Light for graph canvas
    public var isManualAdjustment: Bool = false
    public var activeTracing: Bool = false
    public var tracePoint: (x: Double, y: Double, eqIndex: Int)?

    // UI panels & keypad toggles
    public var showGraphSettings: Bool = false
    public var analyzedEquationId: UUID?
    public var analysisResult: GraphAnalysisResult?
    public var isSecondChecked: Bool = false
    public var isTrigSecondChecked: Bool = false
    public var isHypChecked: Bool = false
    public var isNarrowShowingEquations: Bool = false

    // Range text fields for Graph Options popover
    public var xMinText: String = "-10"
    public var xMaxText: String = "10"
    public var yMinText: String = "-10"
    public var yMaxText: String = "10"

    public var xMinError: Bool { Double(xMinText) == nil }
    public var xMaxError: Bool { Double(xMaxText) == nil }
    public var yMinError: Bool { Double(yMinText) == nil }
    public var yMaxError: Bool { Double(yMaxText) == nil }
    public var xRangeError: Bool { !xMinError && !xMaxError && (Double(xMinText) ?? 0) >= (Double(xMaxText) ?? 0) }
    public var yRangeError: Bool { !yMinError && !yMaxError && (Double(yMinText) ?? 0) >= (Double(yMaxText) ?? 0) }

    public var isKeyGraphFeaturesVisible: Bool { analyzedEquationId != nil }

    public var analyzedEquation: GraphEquationItem? {
        guard let id = analyzedEquationId else { return nil }
        return equations.first(where: { $0.id == id })
    }

    public var variableValuesMap: [String: Double] {
        var map: [String: Double] = [:]
        for v in variables {
            map[v.name] = v.value
        }
        return map
    }

    public init() {
        let first = GraphEquationItem(functionLabelIndex: 1, expression: "", colorIndex: 0, isLastItemInList: true)
        equations = [first]
        focusedEquationId = first.id
    }

    public func updateExpression(for id: UUID, text: String) {
        guard let eq = equations.first(where: { $0.id == id }) else { return }
        eq.expression = text
        reparseEquation(eq)
        ensureTrailingAddRow()
        syncVariables()
    }

    public func submitEquation(for id: UUID) {
        guard let eq = equations.first(where: { $0.id == id }) else { return }
        reparseEquation(eq)
        ensureTrailingAddRow()
        syncVariables()
        // Focus the trailing add row if we just filled it
        if let last = equations.last {
            focusedEquationId = last.id
        }
    }

    public func insertKeypadText(_ text: String, cursorOffsetFromStart: Int? = nil) {
        let target: GraphEquationItem
        if let id = focusedEquationId, let existing = equations.first(where: { $0.id == id }) {
            target = existing
        } else if let last = equations.last {
            target = last
            focusedEquationId = last.id
        } else {
            return
        }
        target.expression += text
        reparseEquation(target)
        ensureTrailingAddRow()
        syncVariables()
    }

    public func backspaceActiveEquation() {
        guard let id = focusedEquationId,
              let eq = equations.first(where: { $0.id == id }),
              !eq.expression.isEmpty
        else { return }
        eq.expression.removeLast()
        reparseEquation(eq)
        syncVariables()
    }

    public func clearActiveEquation() {
        guard let id = focusedEquationId,
              let eq = equations.first(where: { $0.id == id })
        else { return }
        eq.expression = ""
        eq.parsed = nil
        eq.errorText = nil
        syncVariables()
    }

    public func removeEquation(id: UUID) {
        guard equations.count > 1 else {
            if let first = equations.first {
                first.expression = ""
                first.parsed = nil
                first.errorText = nil
                first.isLastItemInList = true
            }
            syncVariables()
            return
        }
        equations.removeAll { $0.id == id }
        if analyzedEquationId == id {
            analyzedEquationId = nil
            analysisResult = nil
        }
        reindexEquations()
        ensureTrailingAddRow()
        syncVariables()
    }

    public func openKeyGraphFeatures(for id: UUID) {
        guard let eq = equations.first(where: { $0.id == id }) else { return }
        analyzedEquationId = id
        if let parsed = eq.parsed {
            analysisResult = GraphingEngine.analyze(parsed, variables: variableValuesMap, trigUnit: trigUnit, xMin: xMin, xMax: xMax)
        } else {
            analysisResult = GraphAnalysisResult(
                error: ResourceProvider.shared.string("KGFAnalysisCouldNotBePerformed", fallback: "Analysis could not be performed."),
                domain: "", range: "", xIntercepts: [], yIntercept: "",
                minima: [], maxima: [], inflectionPoints: [],
                verticalAsymptotes: [], horizontalAsymptotes: [],
                parity: "", periodicity: nil, monotonicity: []
            )
        }
    }

    public func closeKeyGraphFeatures() {
        analyzedEquationId = nil
        analysisResult = nil
    }

    // MARK: - Zoom / Pan / Range

    public func zoomIn() {
        scaleViewport(factor: 0.8)
    }

    public func zoomOut() {
        scaleViewport(factor: 1.25)
    }

    public func scaleViewport(factor: Double) {
        let cx = 0.5 * (xMin + xMax)
        let cy = 0.5 * (yMin + yMax)
        let halfW = max(1e-6, min(1e6, 0.5 * (xMax - xMin) * factor))
        let halfH = max(1e-6, min(1e6, 0.5 * (yMax - yMin) * factor))
        xMin = cx - halfW
        xMax = cx + halfW
        yMin = cy - halfH
        yMax = cy + halfH
        isManualAdjustment = true
        syncRangeTexts()
    }

    public func pan(dxWorld: Double, dyWorld: Double) {
        xMin += dxWorld
        xMax += dxWorld
        yMin += dyWorld
        yMax += dyWorld
        isManualAdjustment = true
        syncRangeTexts()
    }

    public func resetView() {
        xMin = -10
        xMax = 10
        yMin = -10
        yMax = 10
        isManualAdjustment = false
        syncRangeTexts()
    }

    public func applyRangeTexts() {
        guard !xMinError, !xMaxError, !yMinError, !yMaxError, !xRangeError, !yRangeError,
              let xn = Double(xMinText), let xx = Double(xMaxText),
              let yn = Double(yMinText), let yx = Double(yMaxText)
        else { return }
        xMin = xn
        xMax = xx
        yMin = yn
        yMax = yx
        isManualAdjustment = true
    }

    private func syncRangeTexts() {
        xMinText = GraphingEngine.fmt(xMin)
        xMaxText = GraphingEngine.fmt(xMax)
        yMinText = GraphingEngine.fmt(yMin)
        yMaxText = GraphingEngine.fmt(yMax)
    }

    private func reparseEquation(_ eq: GraphEquationItem) {
        let trimmed = eq.expression.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            eq.parsed = nil
            eq.errorText = nil
            return
        }
        do {
            eq.parsed = try GraphingEngine.parse(trimmed)
            eq.errorText = nil
        } catch {
            eq.parsed = nil
            eq.errorText = error.localizedDescription
        }
    }

    private func ensureTrailingAddRow() {
        for eq in equations {
            eq.isLastItemInList = false
        }
        if let last = equations.last, !last.expression.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if equations.count < 14 {
                let nextIndex = equations.count + 1
                let usedColors = Set(equations.map(\.colorIndex))
                let nextColor = (0..<14).first(where: { !usedColors.contains($0) }) ?? (equations.count % 14)
                let newRow = GraphEquationItem(functionLabelIndex: nextIndex, expression: "", colorIndex: nextColor, isLastItemInList: true)
                equations.append(newRow)
            } else {
                last.isLastItemInList = false
            }
        } else if let last = equations.last {
            last.isLastItemInList = true
        }
        reindexEquations()
    }

    private func reindexEquations() {
        for (idx, eq) in equations.enumerated() {
            eq.functionLabelIndex = idx + 1
        }
    }

    private func syncVariables() {
        var needed: [String] = []
        for eq in equations {
            if let params = eq.parsed?.parameters {
                for p in params where !needed.contains(p) {
                    needed.append(p)
                }
            }
        }
        // Keep existing variable settings, add new ones, remove unused ones
        let existing = Dictionary(uniqueKeysWithValues: variables.map { ($0.name, $0) })
        variables = needed.map { name in
            existing[name] ?? GraphVariableItem(name: name, value: 1.0)
        }
    }
}
