import AppKit
import SwiftUI

/// Exact port of `src/Calculator/Views/GraphingCalculator/GraphingCalculator.xaml` and all 5 child graphing views.
public struct GraphingCalculatorView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var vm: GraphingCalculatorViewModel

    public init(vm: GraphingCalculatorViewModel) {
        self.vm = vm
    }

    public var body: some View {
        let theme = CalcTheme(colorScheme: colorScheme)

        GeometryReader { geo in
            let isSmallState = geo.size.width < 800

            VStack(spacing: 0) {
                // Top Header Bar (48pt height, with narrow-mode Graph / Equations toggle switch on right)
                HStack {
                    Spacer()
                    if isSmallState {
                        GraphModeSwitchToggle(isShowingEquations: $vm.isNarrowShowingEquations)
                            .padding(.trailing, 12)
                    }
                }
                .frame(height: 48)

                if isSmallState {
                    if vm.isNarrowShowingEquations {
                        rightPanel
                    } else {
                        leftGraphPanel(theme: theme)
                    }
                } else {
                    HStack(spacing: 0) {
                        leftGraphPanel(theme: theme)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        rightPanel
                            .frame(width: min(420, max(300, geo.size.width * 0.34)))
                            .frame(maxHeight: .infinity)
                    }
                }
            }
        }
    }

    private func leftGraphPanel(theme: CalcTheme) -> some View {
        let res = ResourceProvider.shared
        return ZStack {
            GraphCanvasView(vm: vm)

            // Top-Right Command Panel: Active Tracing | Share/Copy | Graph Options
            VStack {
                HStack {
                    Spacer()
                    HStack(spacing: 2) {
                        Button {
                            vm.activeTracing.toggle()
                            if !vm.activeTracing { vm.tracePoint = nil }
                        } label: {
                            CalcGlyphText(CalcGlyph.trace, size: 15)
                                .foregroundStyle(vm.activeTracing ? theme.textOnAccent : theme.textPrimary)
                                .frame(width: 32, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(vm.activeTracing ? theme.accentDefault : .clear)
                                )
                        }
                        .buttonStyle(.plain)
                        .help(vm.activeTracing ? "Exit trace mode" : "Trace")

                        Button {
                            copyGraphSummaryToClipboard()
                        } label: {
                            CalcGlyphText(CalcGlyph.share, size: 15)
                                .foregroundStyle(theme.textPrimary)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .help(res.string("shareButton.[using:Windows.UI.Xaml.Controls]ToolTipService.ToolTip", fallback: "Share"))

                        Button {
                            vm.showGraphSettings.toggle()
                        } label: {
                            CalcGlyphText(CalcGlyph.graphSettings, size: 15)
                                .foregroundStyle(theme.textPrimary)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .help(res.string("graphSettingsButton.[using:Windows.UI.Xaml.Controls]ToolTipService.ToolTip", fallback: "Graph options"))
                        .popover(isPresented: $vm.showGraphSettings, arrowEdge: .bottom) {
                            GraphingSettingsPopoverView(vm: vm)
                                .padding(14)
                                .frame(width: 300)
                        }
                    }
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(theme.graphCommandPanelBackground)
                            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(theme.flyoutBorder, lineWidth: 0.5)
                    )
                    .padding(.top, 8)
                    .padding(.trailing, 8)
                }
                Spacer()
            }

            // Bottom-Right Zoom & Reset View Command Panel
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 2) {
                        Button { vm.zoomIn() } label: {
                            CalcGlyphText(CalcGlyph.add, size: 14)
                                .foregroundStyle(theme.textPrimary)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .help(res.string("zoomInButton.[using:Windows.UI.Xaml.Controls]ToolTipService.ToolTip", fallback: "Zoom in"))

                        Button { vm.zoomOut() } label: {
                            CalcGlyphText(CalcGlyph.subtract, size: 14)
                                .foregroundStyle(theme.textPrimary)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .help(res.string("zoomOutButton.[using:Windows.UI.Xaml.Controls]ToolTipService.ToolTip", fallback: "Zoom out"))

                        Button { vm.resetView() } label: {
                            ZStack {
                                CalcGlyphText(CalcGlyph.graphViewBase, size: 14)
                                if !vm.isManualAdjustment {
                                    CalcGlyphText(CalcGlyph.graphViewDot, size: 14)
                                }
                            }
                            .foregroundStyle(theme.textPrimary)
                            .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .help(res.string("graphViewButton.[using:Windows.UI.Xaml.Controls]ToolTipService.ToolTip", fallback: "Reset view"))
                    }
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(theme.graphCommandPanelBackground)
                            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(theme.flyoutBorder, lineWidth: 0.5)
                    )
                    .padding(.bottom, 8)
                    .padding(.trailing, 8)
                }
            }
        }
        .padding(.top, 4)
    }

    private var rightPanel: some View {
        Group {
            if vm.isKeyGraphFeaturesVisible, let eq = vm.analyzedEquation {
                KeyGraphFeaturesPanelView(vm: vm, equation: eq)
            } else {
                VStack(spacing: 2) {
                    EquationInputAreaView(vm: vm)
                        .frame(maxHeight: .infinity)
                    GraphingNumPadView(vm: vm)
                        .frame(height: 320)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)
                }
            }
        }
    }

    private func copyGraphSummaryToClipboard() {
        let lines = vm.equations
            .filter { !$0.expression.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { "f\($0.functionLabelIndex): \($0.expression)" }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(lines.joined(separator: "\n"), forType: .string)
    }
}

// MARK: - Narrow Mode Graph / Equations Toggle Switch (exact match to GraphModeToggleSwitchStyle)

private struct GraphModeSwitchToggle: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isShowingEquations: Bool

    var body: some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                isShowingEquations.toggle()
            }
        } label: {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(colorScheme == .dark ? Color.black.opacity(0.25) : Color.white.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(theme.accentDefault, lineWidth: 1)
                    )

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(theme.accentDefault)
                    .frame(width: 32, height: 30)
                    .offset(x: isShowingEquations ? 32 : 0)

                HStack(spacing: 0) {
                    CalcGlyphText(CalcGlyph.navGraphing, size: 14)
                        .foregroundStyle(!isShowingEquations ? theme.textOnAccent : theme.textPrimary)
                        .frame(width: 32, height: 30)

                    HStack(spacing: -2) {
                        CalcGlyphText(CalcGlyph.function, size: 12)
                        Text("x").font(.system(size: 10, weight: .light)).offset(y: 4)
                    }
                    .foregroundStyle(isShowingEquations ? theme.textOnAccent : theme.textPrimary)
                    .frame(width: 32, height: 30)
                }
            }
            .frame(width: 64, height: 30)
        }
        .buttonStyle(.plain)
        .help(isShowingEquations ? "Switch to graph mode" : "Switch to equation mode")
    }
}

// MARK: - Interactive Graph Canvas (Native CoreGraphics / SwiftUI Canvas)

public struct GraphCanvasView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var vm: GraphingCalculatorViewModel

    @State private var lastDragTranslation: CGSize = .zero
    @State private var hoverLocation: CGPoint?

    public init(vm: GraphingCalculatorViewModel) {
        self.vm = vm
    }

    public var body: some View {
        let appTheme = CalcTheme(colorScheme: colorScheme)
        let useDarkGraph = vm.isMatchAppTheme && colorScheme == .dark
        let bgColor = useDarkGraph ? appTheme.graphBackgroundDark : appTheme.graphBackgroundLight
        let gridColor = useDarkGraph ? appTheme.graphGridDark : appTheme.graphGridLight
        let axisColor = useDarkGraph ? appTheme.graphAxisDark : appTheme.graphAxisLight
        let eqTheme = CalcTheme(isDark: useDarkGraph)
        let palette = eqTheme.equationPalette

        GeometryReader { geo in
            let size = geo.size
            ZStack(alignment: .topLeading) {
                Canvas { ctx, canvasSize in
                    drawGraph(
                        ctx: &ctx,
                        size: canvasSize,
                        bgColor: bgColor,
                        gridColor: gridColor,
                        axisColor: axisColor,
                        palette: palette
                    )
                }
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            let dxPx = value.translation.width - lastDragTranslation.width
                            let dyPx = value.translation.height - lastDragTranslation.height
                            lastDragTranslation = value.translation
                            let worldW = vm.xMax - vm.xMin
                            let worldH = vm.yMax - vm.yMin
                            vm.pan(
                                dxWorld: -Double(dxPx / max(1, size.width)) * worldW,
                                dyWorld: Double(dyPx / max(1, size.height)) * worldH
                            )
                        }
                        .onEnded { _ in
                            lastDragTranslation = .zero
                        }
                )
                .gesture(
                    MagnificationGesture()
                        .onEnded { scale in
                            if scale > 0.1 {
                                vm.scaleViewport(factor: 1.0 / Double(scale))
                            }
                        }
                )
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let pt):
                        hoverLocation = pt
                        if vm.activeTracing {
                            updateTracePoint(at: pt, size: size)
                        }
                    case .ended:
                        hoverLocation = nil
                        vm.tracePoint = nil
                    }
                }

                // Trace marker + floating coordinate tooltip
                if vm.activeTracing, let tp = vm.tracePoint {
                    let px = worldToScreenX(tp.x, width: size.width)
                    let py = worldToScreenY(tp.y, height: size.height)
                    if px >= 0 && px <= size.width && py >= 0 && py <= size.height {
                        Circle()
                            .fill(Color.white)
                            .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                            .frame(width: 9, height: 9)
                            .position(x: px, y: py)

                        Text("(\(GraphingEngine.fmt(tp.x)), \(GraphingEngine.fmt(tp.y)))")
                            .font(.system(size: 12, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(appTheme.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(appTheme.flyoutBackground)
                                    .shadow(color: .black.opacity(0.2), radius: 3)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(appTheme.flyoutBorder, lineWidth: 1)
                            )
                            .position(
                                x: min(max(60, px + 56), size.width - 60),
                                y: max(24, py - 24)
                            )
                    }
                }
            }
        }
        .clipped()
    }

    private func worldToScreenX(_ x: Double, width: CGFloat) -> CGFloat {
        CGFloat((x - vm.xMin) / max(1e-12, vm.xMax - vm.xMin)) * width
    }

    private func worldToScreenY(_ y: Double, height: CGFloat) -> CGFloat {
        CGFloat(1.0 - (y - vm.yMin) / max(1e-12, vm.yMax - vm.yMin)) * height
    }

    private func updateTracePoint(at pt: CGPoint, size: CGSize) {
        let worldX = vm.xMin + Double(pt.x / max(1, size.width)) * (vm.xMax - vm.xMin)
        let vars = vm.variableValuesMap
        var best: (x: Double, y: Double, dist: CGFloat, idx: Int)?

        for (idx, eq) in vm.equations.enumerated() where eq.isLineEnabled {
            guard let parsed = eq.parsed, case .explicitY(let expr, _) = parsed.kind else { continue }
            let y = GraphingEngine.evaluate(expr, x: worldX, variables: vars, trigUnit: vm.trigUnit)
            guard y.isFinite else { continue }
            let py = worldToScreenY(y, height: size.height)
            let d = abs(py - pt.y)
            if best == nil || d < best!.dist {
                best = (worldX, y, d, idx)
            }
        }

        if let b = best, b.dist < 60 {
            vm.tracePoint = (b.x, b.y, b.idx)
        } else {
            vm.tracePoint = nil
        }
    }

    private func niceGridStep(range: Double, targetDivisions: Double = 8) -> Double {
        let raw = range / max(1, targetDivisions)
        let mag = pow(10.0, floor(log10(max(1e-12, raw))))
        let norm = raw / mag
        if norm < 1.5 { return 1 * mag }
        if norm < 3.5 { return 2 * mag }
        if norm < 7.5 { return 5 * mag }
        return 10 * mag
    }

    private func drawGraph(
        ctx: inout GraphicsContext,
        size: CGSize,
        bgColor: Color,
        gridColor: Color,
        axisColor: Color,
        palette: [Color]
    ) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(bgColor))

        let xRange = vm.xMax - vm.xMin
        let yRange = vm.yMax - vm.yMin
        guard xRange > 0, yRange > 0, size.width > 0, size.height > 0 else { return }

        let xStep = niceGridStep(range: xRange, targetDivisions: max(4, Double(size.width) / 70))
        let yStep = niceGridStep(range: yRange, targetDivisions: max(4, Double(size.height) / 70))

        // Vertical grid lines
        var gx = ceil(vm.xMin / xStep) * xStep
        while gx <= vm.xMax {
            let sx = worldToScreenX(gx, width: size.width)
            var p = Path()
            p.move(to: CGPoint(x: sx, y: 0))
            p.addLine(to: CGPoint(x: sx, y: size.height))
            ctx.stroke(p, with: .color(gridColor.opacity(0.6)), lineWidth: 0.75)
            gx += xStep
        }

        // Horizontal grid lines
        var gy = ceil(vm.yMin / yStep) * yStep
        while gy <= vm.yMax {
            let sy = worldToScreenY(gy, height: size.height)
            var p = Path()
            p.move(to: CGPoint(x: 0, y: sy))
            p.addLine(to: CGPoint(x: size.width, y: sy))
            ctx.stroke(p, with: .color(gridColor.opacity(0.6)), lineWidth: 0.75)
            gy += yStep
        }

        // Axes
        let originX = worldToScreenX(0, width: size.width)
        let originY = worldToScreenY(0, height: size.height)

        if originX >= 0 && originX <= size.width {
            var yAxis = Path()
            yAxis.move(to: CGPoint(x: originX, y: 0))
            yAxis.addLine(to: CGPoint(x: originX, y: size.height))
            ctx.stroke(yAxis, with: .color(axisColor), lineWidth: 1.4)
        }
        if originY >= 0 && originY <= size.height {
            var xAxis = Path()
            xAxis.move(to: CGPoint(x: 0, y: originY))
            xAxis.addLine(to: CGPoint(x: size.width, y: originY))
            ctx.stroke(xAxis, with: .color(axisColor), lineWidth: 1.4)
        }

        // Axis Tick Labels
        let labelYPos = min(max(14, originY + 13), size.height - 14)
        var lx = ceil(vm.xMin / xStep) * xStep
        while lx <= vm.xMax {
            if abs(lx) > xStep * 1e-4 {
                let sx = worldToScreenX(lx, width: size.width)
                if sx > 16 && sx < size.width - 16 {
                    let label = Text(GraphingEngine.fmt(lx))
                        .font(.system(size: 10))
                        .foregroundStyle(axisColor.opacity(0.75))
                    ctx.draw(label, at: CGPoint(x: sx, y: labelYPos), anchor: .center)
                }
            }
            lx += xStep
        }

        let labelXPos = min(max(22, originX - 18), size.width - 22)
        var ly = ceil(vm.yMin / yStep) * yStep
        while ly <= vm.yMax {
            if abs(ly) > yStep * 1e-4 {
                let sy = worldToScreenY(ly, height: size.height)
                if sy > 12 && sy < size.height - 12 {
                    let label = Text(GraphingEngine.fmt(ly))
                        .font(.system(size: 10))
                        .foregroundStyle(axisColor.opacity(0.75))
                    ctx.draw(label, at: CGPoint(x: labelXPos, y: sy), anchor: .center)
                }
            }
            ly += yStep
        }

        // Plot each enabled equation
        let vars = vm.variableValuesMap
        let samples = max(300, Int(size.width * 1.5))

        for eq in vm.equations where eq.isLineEnabled {
            guard let parsed = eq.parsed else { continue }
            let color = palette[eq.colorIndex % palette.count]

            let dash: [CGFloat]
            if parsed.relation.isStrict {
                dash = [6, 4]
            } else {
                switch eq.lineStyle {
                case .solid: dash = []
                case .dash: dash = [8, 5]
                case .dot: dash = [2, 4]
                }
            }
            let strokeStyle = StrokeStyle(lineWidth: CGFloat(vm.lineWidth), lineCap: .round, lineJoin: .round, dash: dash)

            switch parsed.kind {
            case .explicitY(let expr, let rel):
                var path = Path()
                var shadePath = Path()
                var isDrawing = false
                var prevScreenY: CGFloat = 0

                for i in 0...samples {
                    let sx = CGFloat(i) / CGFloat(samples) * size.width
                    let wx = vm.xMin + Double(i) / Double(samples) * xRange
                    let wy = GraphingEngine.evaluate(expr, x: wx, variables: vars, trigUnit: vm.trigUnit)
                    guard wy.isFinite else {
                        isDrawing = false
                        continue
                    }
                    let sy = worldToScreenY(wy, height: size.height)
                    // Break across vertical asymptotes / huge jumps
                    if isDrawing && abs(sy - prevScreenY) > size.height * 0.9 {
                        isDrawing = false
                    }
                    let clampedY = min(max(sy, -size.height * 2), size.height * 3)
                    let pt = CGPoint(x: sx, y: clampedY)
                    if !isDrawing {
                        path.move(to: pt)
                        isDrawing = true
                    } else {
                        path.addLine(to: pt)
                    }
                    prevScreenY = sy

                    if rel.isInequality {
                        let edgeY: CGFloat = (rel == .greaterThan || rel == .greaterOrEqual) ? 0 : size.height
                        shadePath.move(to: CGPoint(x: sx, y: clampedY))
                        shadePath.addLine(to: CGPoint(x: sx, y: edgeY))
                    }
                }

                if rel.isInequality {
                    ctx.stroke(shadePath, with: .color(color.opacity(0.18)), lineWidth: max(1.5, size.width / CGFloat(samples) + 0.5))
                }
                ctx.stroke(path, with: .color(color), style: strokeStyle)

            case .explicitX(let expr, let rel):
                var path = Path()
                var shadePath = Path()
                var isDrawing = false
                var prevScreenX: CGFloat = 0

                for i in 0...samples {
                    let sy = CGFloat(i) / CGFloat(samples) * size.height
                    let wy = vm.yMax - Double(i) / Double(samples) * yRange
                    let wx = GraphingEngine.evaluate(expr, y: wy, variables: vars, trigUnit: vm.trigUnit)
                    guard wx.isFinite else {
                        isDrawing = false
                        continue
                    }
                    let sx = worldToScreenX(wx, width: size.width)
                    if isDrawing && abs(sx - prevScreenX) > size.width * 0.9 {
                        isDrawing = false
                    }
                    let pt = CGPoint(x: min(max(sx, -size.width * 2), size.width * 3), y: sy)
                    if !isDrawing {
                        path.move(to: pt)
                        isDrawing = true
                    } else {
                        path.addLine(to: pt)
                    }
                    prevScreenX = sx

                    if rel.isInequality {
                        let edgeX: CGFloat = (rel == .greaterThan || rel == .greaterOrEqual) ? size.width : 0
                        shadePath.move(to: pt)
                        shadePath.addLine(to: CGPoint(x: edgeX, y: sy))
                    }
                }
                if rel.isInequality {
                    ctx.stroke(shadePath, with: .color(color.opacity(0.18)), lineWidth: max(1.5, size.height / CGFloat(samples) + 0.5))
                }
                ctx.stroke(path, with: .color(color), style: strokeStyle)

            case .implicit(let lhs, let rhs, let rel):
                // Marching-squares grid for implicit curves like x^2 + y^2 = 25
                let cols = 120
                let rows = 120
                let dx = xRange / Double(cols)
                let dy = yRange / Double(rows)
                var vals = Array(repeating: Array(repeating: 0.0, count: cols + 1), count: rows + 1)
                for r in 0...rows {
                    let wy = vm.yMax - Double(r) * dy
                    for c in 0...cols {
                        let wx = vm.xMin + Double(c) * dx
                        vals[r][c] = GraphingEngine.evaluate(lhs, x: wx, y: wy, variables: vars, trigUnit: vm.trigUnit)
                            - GraphingEngine.evaluate(rhs, x: wx, y: wy, variables: vars, trigUnit: vm.trigUnit)
                    }
                }
                var contour = Path()
                let cellW = size.width / CGFloat(cols)
                let cellH = size.height / CGFloat(rows)
                for r in 0..<rows {
                    for c in 0..<cols {
                        let v00 = vals[r][c], v10 = vals[r][c + 1], v11 = vals[r + 1][c + 1], v01 = vals[r + 1][c]
                        guard v00.isFinite, v10.isFinite, v11.isFinite, v01.isFinite else { continue }
                        let x0 = CGFloat(c) * cellW
                        let y0 = CGFloat(r) * cellH

                        if rel.isInequality {
                            let mid = 0.25 * (v00 + v10 + v11 + v01)
                            let inside = (rel == .lessThan || rel == .lessOrEqual) ? (mid < 0) : (mid > 0)
                            if inside {
                                ctx.fill(Path(CGRect(x: x0, y: y0, width: cellW + 0.5, height: cellH + 0.5)), with: .color(color.opacity(0.18)))
                            }
                        }

                        var pts: [CGPoint] = []
                        if v00 * v10 <= 0 && v00 != v10 {
                            let t = CGFloat(v00 / (v00 - v10))
                            pts.append(CGPoint(x: x0 + t * cellW, y: y0))
                        }
                        if v10 * v11 <= 0 && v10 != v11 {
                            let t = CGFloat(v10 / (v10 - v11))
                            pts.append(CGPoint(x: x0 + cellW, y: y0 + t * cellH))
                        }
                        if v01 * v11 <= 0 && v01 != v11 {
                            let t = CGFloat(v01 / (v01 - v11))
                            pts.append(CGPoint(x: x0 + t * cellW, y: y0 + cellH))
                        }
                        if v00 * v01 <= 0 && v00 != v01 {
                            let t = CGFloat(v00 / (v00 - v01))
                            pts.append(CGPoint(x: x0, y: y0 + t * cellH))
                        }
                        if pts.count >= 2 {
                            contour.move(to: pts[0])
                            contour.addLine(to: pts[1])
                        }
                    }
                }
                ctx.stroke(contour, with: .color(color), style: strokeStyle)
            }
        }
    }
}

// MARK: - Equation Input Area (Exact port of EquationInputArea.xaml & EquationStylePanelControl.xaml)

public struct EquationInputAreaView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var vm: GraphingCalculatorViewModel

    public init(vm: GraphingCalculatorViewModel) {
        self.vm = vm
    }

    public var body: some View {
        let theme = CalcTheme(colorScheme: colorScheme)

        ScrollView {
            VStack(spacing: 4) {
                ForEach(vm.equations) { eq in
                    EquationRowView(vm: vm, eq: eq)
                }

                if !vm.variables.isEmpty {
                    Rectangle()
                        .fill(theme.dividerStroke)
                        .frame(height: 1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                    ForEach(vm.variables) { variable in
                        VariableSliderCardView(variable: variable)
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
    }
}

private struct EquationRowView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var vm: GraphingCalculatorViewModel
    @Bindable var eq: GraphEquationItem

    @State private var isHovered = false
    @State private var isColorBtnHovered = false
    @State private var showStylePopover = false
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        let res = ResourceProvider.shared
        let useDarkEq = vm.isMatchAppTheme && colorScheme == .dark
        let eqPalette = CalcTheme(isDark: useDarkEq).equationPalette
        let eqColor = eqPalette[eq.colorIndex % eqPalette.count]
        let fgOnEqColor = CalcTheme.contrastingForeground(for: eqColor)
        let isAddRow = eq.isLastItemInList && eq.expression.isEmpty
        let showActions = (isHovered || isFieldFocused) && !isAddRow

        HStack(spacing: 0) {
            // Left f_n toggle button
            Button {
                if !isAddRow {
                    eq.isLineEnabled.toggle()
                }
            } label: {
                ZStack {
                    if isAddRow || !eq.isLineEnabled {
                        (colorScheme == .dark ? Color.white.opacity(0.28) : Color.black.opacity(0.28))
                    } else {
                        eqColor
                    }

                    if isColorBtnHovered && !isAddRow {
                        CalcGlyphText(eq.isLineEnabled ? CalcGlyph.hideEye : CalcGlyph.showEye, size: 15)
                            .foregroundStyle(eq.isLineEnabled ? fgOnEqColor : Color.white)
                    } else {
                        HStack(alignment: .bottom, spacing: -3) {
                            CalcGlyphText(CalcGlyph.function, size: 15)
                            if !isAddRow {
                                Text("\(eq.functionLabelIndex)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .offset(y: 4)
                            }
                        }
                        .foregroundStyle((isAddRow || !eq.isLineEnabled) ? Color.white.opacity(0.75) : fgOnEqColor)
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 4, bottomLeadingRadius: 4,
                        bottomTrailingRadius: 0, topTrailingRadius: 0,
                        style: .continuous
                    )
                )
            }
            .buttonStyle(.plain)
            .onHover { isColorBtnHovered = $0 }
            .disabled(isAddRow)

            // Math Expression Input Box
            TextField(
                res.string("mathRichEditBox.PlaceholderText", fallback: "Enter an expression"),
                text: Binding(
                    get: { eq.expression },
                    set: { vm.updateExpression(for: eq.id, text: $0) }
                )
            )
            .textFieldStyle(.plain)
            .font(.system(size: 15, design: .serif))
            .foregroundStyle(theme.textPrimary)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 44)
            .focused($isFieldFocused)
            .onSubmit {
                vm.submitEquation(for: eq.id)
            }
            .onChange(of: isFieldFocused) { _, focused in
                if focused { vm.focusedEquationId = eq.id }
            }

            // Right inline action buttons (Analysis, Style, Error, Remove)
            if eq.hasError && !isFieldFocused {
                CalcGlyphText(CalcGlyph.errorIcon, size: 16)
                    .foregroundStyle(theme.graphErrorBorder)
                    .frame(width: 32, height: 44)
                    .help(eq.errorText ?? "Error")
            }

            if showActions && !eq.hasError {
                Button {
                    vm.openKeyGraphFeatures(for: eq.id)
                } label: {
                    CalcGlyphText(CalcGlyph.navPower, size: 14)
                        .foregroundStyle(theme.textPrimary)
                        .frame(width: 34, height: 40)
                }
                .buttonStyle(.plain)
                .help("Analyze function")

                Button {
                    showStylePopover.toggle()
                } label: {
                    CalcGlyphText(CalcGlyph.palette, size: 14)
                        .foregroundStyle(theme.textPrimary)
                        .frame(width: 34, height: 40)
                }
                .buttonStyle(.plain)
                .help("Line options")
                .popover(isPresented: $showStylePopover, arrowEdge: .bottom) {
                    EquationStylePanelView(
                        palette: eqPalette,
                        selectedColorIndex: $eq.colorIndex,
                        selectedStyle: $eq.lineStyle,
                        enableLineStylePicker: !eq.isInequality
                    )
                    .padding(14)
                }
            }

            if showActions {
                Button {
                    vm.removeEquation(id: eq.id)
                } label: {
                    CalcGlyphText(CalcGlyph.delete, size: 14)
                        .foregroundStyle(theme.textPrimary)
                        .frame(width: 34, height: 40)
                }
                .buttonStyle(.plain)
                .help("Remove expression")
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(eq.hasError ? theme.graphErrorBackground : theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(
                    eq.hasError
                        ? theme.graphErrorBorder
                        : ((isFieldFocused || isHovered) && !isAddRow ? eqColor : theme.cardBorder),
                    lineWidth: (isFieldFocused || eq.hasError) ? 1.2 : 0.8
                )
        )
        .onHover { isHovered = $0 }
    }
}

/// Exact port of `src/Calculator/Views/GraphingCalculator/EquationStylePanelControl.xaml` (7x2 color palette + Solid/Dash/Dot style picker).
public struct EquationStylePanelView: View {
    @Environment(\.colorScheme) private var colorScheme
    let palette: [Color]
    @Binding var selectedColorIndex: Int
    @Binding var selectedStyle: EquationLineStyle
    let enableLineStylePicker: Bool

    public var body: some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        let res = ResourceProvider.shared

        VStack(alignment: .leading, spacing: 12) {
            Text(res.string("LineOptionsHeading.Text", fallback: "Line options"))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.textPrimary)

            Text(res.string("LineColorText.Text", fallback: "Color"))
                .font(.system(size: 12))
                .foregroundStyle(theme.textSecondary)

            // 7x2 Grid of 14 equation colors
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(34), spacing: 6), count: 7), spacing: 6) {
                ForEach(0..<palette.count, id: \.self) { idx in
                    Button {
                        selectedColorIndex = idx
                    } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(selectedColorIndex == idx ? theme.textPrimary : .clear, lineWidth: 2)
                                .frame(width: 30, height: 30)
                            Circle()
                                .fill(palette[idx])
                                .overlay(Circle().strokeBorder(theme.dividerStroke, lineWidth: 0.5))
                                .frame(width: 22, height: 22)
                        }
                    }
                    .buttonStyle(.plain)
                    .help(CalcTheme.equationColorNames[idx % CalcTheme.equationColorNames.count])
                }
            }

            Text(res.string("StyleChooserBoxHeading.Text", fallback: "Style"))
                .font(.system(size: 12))
                .foregroundStyle(theme.textSecondary)

            HStack(spacing: 6) {
                ForEach(EquationLineStyle.allCases) { style in
                    Button {
                        selectedStyle = style
                    } label: {
                        linePreview(style: style, color: theme.textPrimary)
                            .frame(width: 72, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(selectedStyle == style ? theme.subtleFillHover : .clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .strokeBorder(selectedStyle == style ? theme.accentDefault : theme.cardBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!enableLineStylePicker)
                }
            }
            .opacity(enableLineStylePicker ? 1 : 0.4)
        }
    }

    private func linePreview(style: EquationLineStyle, color: Color) -> some View {
        let dash: [CGFloat] = {
            switch style {
            case .solid: return []
            case .dash: return [6, 3]
            case .dot: return [2, 3]
            }
        }()
        return Canvas { ctx, size in
            var p = Path()
            p.move(to: CGPoint(x: 8, y: size.height / 2))
            p.addLine(to: CGPoint(x: size.width - 8, y: size.height / 2))
            ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: dash))
        }
    }
}

// MARK: - Variable Slider Card (Exact port of VariableDataTemplate in EquationInputArea.xaml)

private struct VariableSliderCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var variable: GraphVariableItem

    var body: some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        let res = ResourceProvider.shared

        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text(variable.name)
                    .font(.system(size: 15, design: .serif).italic())
                    .foregroundStyle(theme.textPrimary)
                Text("=")
                    .font(.system(size: 15, design: .serif).italic())
                    .foregroundStyle(theme.textPrimary)
                TextField(
                    "",
                    value: $variable.value,
                    format: .number.precision(.fractionLength(0...3))
                )
                .textFieldStyle(.plain)
                .font(.system(size: 14, design: .serif).italic())
                .frame(width: 60)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(theme.textTertiary).frame(height: 1)
                }
                Spacer()
            }

            Slider(
                value: $variable.value,
                in: variable.minValue...max(variable.minValue + 0.01, variable.maxValue),
                step: max(0.001, variable.step)
            )
            .controlSize(.small)

            if variable.sliderSettingsVisible {
                HStack(spacing: 12) {
                    miniNumericField(label: res.string("MinTextBlock.Text", fallback: "Min"), value: $variable.minValue)
                    miniNumericField(label: res.string("StepTextBlock.Text", fallback: "Step"), value: $variable.step)
                    miniNumericField(label: res.string("MaxTextBlock.Text", fallback: "Max"), value: $variable.maxValue)
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    variable.sliderSettingsVisible.toggle()
                }
            } label: {
                CalcGlyphText(variable.sliderSettingsVisible ? CalcGlyph.chevronUp : CalcGlyph.chevronDown, size: 9)
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 40, height: 18)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 2)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(theme.cardBorder, lineWidth: 0.8)
        )
    }

    private func miniNumericField(label: String, value: Binding<Double>) -> some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        return HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(theme.textSecondary)
            TextField("", value: value, format: .number)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .frame(width: 44)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(theme.textTertiary).frame(height: 1)
                }
        }
    }
}

// MARK: - Key Graph Features Panel (Exact port of KeyGraphFeaturesPanel.xaml)

public struct KeyGraphFeaturesPanelView: View {
    @Environment(\.colorScheme) private var colorScheme
    let vm: GraphingCalculatorViewModel
    let equation: GraphEquationItem

    public var body: some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        let res = ResourceProvider.shared
        let useDarkEq = vm.isMatchAppTheme && colorScheme == .dark
        let eqColor = CalcTheme(isDark: useDarkEq).equationPalette[equation.colorIndex % 14]
        let fg = CalcTheme.contrastingForeground(for: eqColor)

        VStack(alignment: .leading, spacing: 0) {
            // Colored Back Header
            HStack(spacing: 0) {
                Button {
                    vm.closeKeyGraphFeatures()
                } label: {
                    HStack(spacing: 6) {
                        CalcGlyphText(CalcGlyph.back, size: 15)
                        HStack(alignment: .bottom, spacing: -3) {
                            CalcGlyphText(CalcGlyph.function, size: 15)
                            Text("\(equation.functionLabelIndex)")
                                .font(.system(size: 10, weight: .semibold))
                                .offset(y: 4)
                        }
                    }
                    .foregroundStyle(fg)
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(eqColor)
                }
                .buttonStyle(.plain)

                Text(equation.expression)
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(theme.textPrimary)
                    .padding(.horizontal, 12)
                    .lineLimit(1)
                Spacer()
            }
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .padding(.horizontal, 6)
            .padding(.top, 4)

            Text(res.string("KeyGraphFeaturesLabel.Text", fallback: "Function analysis"))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 6)

            if let analysis = vm.analysisResult {
                if let err = analysis.error {
                    Text(err)
                        .font(.system(size: 14))
                        .foregroundStyle(theme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            kgfSection(res.string("Domain", fallback: "Domain"), items: [analysis.domain])
                            kgfSection(res.string("Range", fallback: "Range"), items: [analysis.range])
                            kgfSection(
                                res.string("XIntercept", fallback: "X-intercept"),
                                items: analysis.xIntercepts.isEmpty ? [res.string("KGFXInterceptNone", fallback: "None")] : analysis.xIntercepts
                            )
                            kgfSection(res.string("YIntercept", fallback: "Y-intercept"), items: [analysis.yIntercept])
                            kgfSection(
                                res.string("Minima", fallback: "Minima"),
                                items: analysis.minima.isEmpty ? [res.string("KGFMinimaNone", fallback: "None")] : analysis.minima
                            )
                            kgfSection(
                                res.string("Maxima", fallback: "Maxima"),
                                items: analysis.maxima.isEmpty ? [res.string("KGFMaximaNone", fallback: "None")] : analysis.maxima
                            )
                            kgfSection(
                                res.string("InflectionPoints", fallback: "Inflection points"),
                                items: analysis.inflectionPoints.isEmpty ? [res.string("KGFInflectionPointsNone", fallback: "None")] : analysis.inflectionPoints
                            )
                            kgfSection(
                                res.string("VerticalAsymptotes", fallback: "Vertical asymptotes"),
                                items: analysis.verticalAsymptotes.isEmpty ? [res.string("KGFVerticalAsymptotesNone", fallback: "None")] : analysis.verticalAsymptotes
                            )
                            kgfSection(
                                res.string("HorizontalAsymptotes", fallback: "Horizontal asymptotes"),
                                items: analysis.horizontalAsymptotes.isEmpty ? [res.string("KGFHorizontalAsymptotesNone", fallback: "None")] : analysis.horizontalAsymptotes
                            )
                            kgfSection(res.string("Parity", fallback: "Parity"), items: [analysis.parity])

                            if !analysis.monotonicity.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(res.string("Monotonicity", fallback: "Monotonicity"))
                                        .font(.system(size: 12))
                                        .foregroundStyle(theme.textSecondary)
                                    ForEach(Array(analysis.monotonicity.enumerated()), id: \.offset) { _, pair in
                                        HStack(spacing: 12) {
                                            Text(pair.interval)
                                                .font(.system(size: 14, design: .serif))
                                                .foregroundStyle(theme.textPrimary)
                                            Text(pair.direction)
                                                .font(.system(size: 14))
                                                .foregroundStyle(theme.textSecondary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
    }

    private func kgfSection(_ title: String, items: [String]) -> some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        return VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(theme.textSecondary)
            ForEach(items, id: \.self) { val in
                Text(val)
                    .font(.system(size: 14))
                    .foregroundStyle(theme.textPrimary)
                    .textSelection(.enabled)
            }
        }
    }
}

// MARK: - Graph Options Settings Popover (Exact port of GraphingSettings.xaml)

public struct GraphingSettingsPopoverView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var vm: GraphingCalculatorViewModel

    public var body: some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        let res = ResourceProvider.shared

        VStack(alignment: .leading, spacing: 14) {
            Text(res.string("GraphOptionsHeading.Text", fallback: "Graph options"))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.textPrimary)

            // Window section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(res.string("GridHeading.Text", fallback: "Window"))
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    Button(res.string("ResetViewButton.Content", fallback: "Reset view")) {
                        vm.resetView()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.accentText)
                }

                Grid(horizontalSpacing: 10, verticalSpacing: 8) {
                    GridRow {
                        rangeField("X-Min", text: $vm.xMinText, hasError: vm.xMinError || vm.xRangeError)
                        rangeField("X-Max", text: $vm.xMaxText, hasError: vm.xMaxError || vm.xRangeError)
                    }
                    GridRow {
                        rangeField("Y-Min", text: $vm.yMinText, hasError: vm.yMinError || vm.yRangeError)
                        rangeField("Y-Max", text: $vm.yMaxText, hasError: vm.yMaxError || vm.yRangeError)
                    }
                }
            }

            // Units section
            VStack(alignment: .leading, spacing: 6) {
                Text(res.string("UnitsHeading.Text", fallback: "Units"))
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textSecondary)

                HStack(spacing: 4) {
                    trigUnitButton(res.string("TrigModeRadians.Content", fallback: "Radians"), unit: .radians)
                    trigUnitButton(res.string("TrigModeDegrees.Content", fallback: "Degrees"), unit: .degrees)
                    trigUnitButton(res.string("TrigModeGradians.Content", fallback: "Gradians"), unit: .gradians)
                }
            }

            // Line thickness
            VStack(alignment: .leading, spacing: 6) {
                Text(res.string("LineThicknessBoxHeading.Text", fallback: "Line thickness"))
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textSecondary)

                HStack(spacing: 6) {
                    ForEach([1.0, 2.0, 3.0, 4.0], id: \.self) { w in
                        Button {
                            vm.lineWidth = w
                        } label: {
                            Rectangle()
                                .fill(theme.textPrimary)
                                .frame(height: CGFloat(w))
                                .padding(.horizontal, 10)
                                .frame(maxWidth: .infinity, minHeight: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(vm.lineWidth == w ? theme.subtleFillHover : .clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .strokeBorder(vm.lineWidth == w ? theme.accentDefault : theme.cardBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Graph theme
            VStack(alignment: .leading, spacing: 6) {
                Text(res.string("GraphThemeHeading.Text", fallback: "Graph theme"))
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textSecondary)

                graphThemeRadio(res.string("AlwaysLightTheme.Content", fallback: "Always light"), selected: !vm.isMatchAppTheme) {
                    vm.isMatchAppTheme = false
                }
                graphThemeRadio(res.string("MatchAppTheme.Content", fallback: "Match app theme"), selected: vm.isMatchAppTheme) {
                    vm.isMatchAppTheme = true
                }
            }
        }
    }

    private func rangeField(_ label: String, text: Binding<String>, hasError: Bool) -> some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        return VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(theme.textSecondary)
            TextField("", text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(hasError ? theme.graphErrorBackground : theme.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(hasError ? theme.graphErrorBorder : theme.cardBorder, lineWidth: 1)
                )
                .onSubmit { vm.applyRangeTexts() }
                .onChange(of: text.wrappedValue) { _, _ in vm.applyRangeTexts() }
        }
    }

    private func trigUnitButton(_ title: String, unit: GraphTrigUnit) -> some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        let selected = vm.trigUnit == unit
        return Button {
            vm.trigUnit = unit
        } label: {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(selected ? theme.textOnAccent : theme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(selected ? theme.accentDefault : theme.operatorFillDefault)
                )
        }
        .buttonStyle(.plain)
    }

    private func graphThemeRadio(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        return Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .strokeBorder(selected ? theme.accentDefault : theme.textSecondary, lineWidth: selected ? 5 : 1.5)
                    .frame(width: 16, height: 16)
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.textPrimary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Graphing NumPad (Exact port of GraphingNumPad.xaml)

public struct GraphingNumPadView: View {
    @Bindable var vm: GraphingCalculatorViewModel

    @State private var showTrig = false
    @State private var showIneq = false
    @State private var showFunc = false

    public var body: some View {
        let res = ResourceProvider.shared
        let decSep = res.decimalSeparator

        VStack(spacing: 2) {
            // Operator Panel Row: Trigonometry | Inequalities | Function (horizontally scrollable matching OperatorPanelListView)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    OperatorPanelDropdownButton(
                        glyph: CalcGlyph.trig,
                        title: res.string("trigButton.Text", fallback: "Trigonometry"),
                        fontSize: 12,
                        glyphSize: 14,
                        isPresented: $showTrig
                    ) {
                        graphTrigFlyout
                    }
                    .fixedSize(horizontal: true, vertical: false)

                    OperatorPanelDropdownButton(
                        glyph: CalcGlyph.inequality,
                        title: res.string("inequalityButton.Text", fallback: "Inequalities"),
                        fontSize: 12,
                        glyphSize: 14,
                        isPresented: $showIneq
                    ) {
                        graphIneqFlyout
                    }
                    .fixedSize(horizontal: true, vertical: false)

                    OperatorPanelDropdownButton(
                        glyph: CalcGlyph.function,
                        title: res.string("funcButton.Text", fallback: "Function"),
                        fontSize: 12,
                        glyphSize: 14,
                        isPresented: $showFunc
                    ) {
                        graphFuncFlyout
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
            .frame(height: 34)

            // 5 x 7 Keypad Grid matching GraphingNumPad.xaml
            Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                // Row 0: 2nd  π  e  C  ⌫
                GridRow {
                    FluentCalcButton(variant: .emphasizedToggle(isOn: vm.isSecondChecked), action: { vm.isSecondChecked.toggle() }) {
                        CalcGlyphText(CalcGlyph.second, size: 15)
                    }
                    gGlyphBtn(CalcGlyph.pi, insert: "π")
                    gTextBtn("e", insert: "e")
                    FluentCalcButton(variant: .operator, action: { vm.clearActiveEquation() }) {
                        Text("C").font(.system(size: 14))
                    }
                    FluentCalcButton(variant: .operator, action: { vm.backspaceActiveEquation() }) {
                        CalcGlyphText(CalcGlyph.backspace, size: 15)
                    }
                }

                // Row 1: x²/x³  1/x  |x|  𝑥  𝑦
                GridRow {
                    if vm.isSecondChecked {
                        gShiftGlyphBtn(CalcGlyph.cube, insert: "^3")
                    } else {
                        gGlyphBtn(CalcGlyph.xPower2, insert: "^2")
                    }
                    gGlyphBtn(CalcGlyph.invert, insert: "1/")
                    gGlyphBtn(CalcGlyph.abs, insert: "abs()")
                    gTextBtn("𝑥", insert: "x", italic: true)
                    gTextBtn("𝑦", insert: "y", italic: true)
                }

                // Row 2: √/∛  (  )  =  ÷
                GridRow {
                    if vm.isSecondChecked {
                        gShiftGlyphBtn(CalcGlyph.cubeRoot, insert: "cbrt()")
                    } else {
                        gGlyphBtn(CalcGlyph.sqrt, insert: "sqrt()")
                    }
                    gTextBtn("(", insert: "(")
                    gTextBtn(")", insert: ")")
                    gGlyphBtn(CalcGlyph.equals, insert: "=")
                    gGlyphBtn(CalcGlyph.divide, insert: "/")
                }

                // Row 3: xʸ/ʸ√x  7  8  9  ×
                GridRow {
                    if vm.isSecondChecked {
                        gShiftGlyphBtn(CalcGlyph.yRootX, insert: "root(x,n)")
                    } else {
                        gGlyphBtn(CalcGlyph.xPowerY, insert: "^")
                    }
                    gNumBtn("7")
                    gNumBtn("8")
                    gNumBtn("9")
                    gGlyphBtn(CalcGlyph.multiply, insert: "*")
                }

                // Row 4: 10ˣ/2ˣ  4  5  6  −
                GridRow {
                    if vm.isSecondChecked {
                        gShiftGlyphBtn(CalcGlyph.twoPowerX, insert: "2^")
                    } else {
                        gGlyphBtn(CalcGlyph.tenPowerX, insert: "10^")
                    }
                    gNumBtn("4")
                    gNumBtn("5")
                    gNumBtn("6")
                    gGlyphBtn(CalcGlyph.subtract, insert: "-")
                }

                // Row 5: log/logᵧx  1  2  3  +
                GridRow {
                    if vm.isSecondChecked {
                        gShiftGlyphBtn(CalcGlyph.logBaseY, insert: "log(b,x)")
                    } else {
                        gTextBtn("log", insert: "log()")
                    }
                    gNumBtn("1")
                    gNumBtn("2")
                    gNumBtn("3")
                    gGlyphBtn(CalcGlyph.add, insert: "+")
                }

                // Row 6: ln/eˣ  −  0  .  ↵
                GridRow {
                    if vm.isSecondChecked {
                        gShiftGlyphBtn(CalcGlyph.ePowerX, insert: "e^")
                    } else {
                        gTextBtn("ln", insert: "ln()")
                    }
                    FluentCalcButton(variant: .numeric, action: { vm.insertKeypadText("-") }) {
                        CalcGlyphText(CalcGlyph.graphNegate, size: 15)
                    }
                    gNumBtn("0")
                    gNumBtn(decSep)
                    FluentCalcButton(variant: .accent, action: {
                        if let id = vm.focusedEquationId {
                            vm.submitEquation(for: id)
                        }
                    }) {
                        Image(systemName: "return")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
            }
        }
    }

    private var graphTrigFlyout: some View {
        let items: [(String, String)] = {
            switch (vm.isTrigSecondChecked, vm.isHypChecked) {
            case (false, false):
                return [("sin", "sin("), ("cos", "cos("), ("tan", "tan("), ("sec", "sec("), ("csc", "csc("), ("cot", "cot(")]
            case (true, false):
                return [("sin⁻¹", "arcsin("), ("cos⁻¹", "arccos("), ("tan⁻¹", "arctan("), ("sec⁻¹", "arcsec("), ("csc⁻¹", "arccsc("), ("cot⁻¹", "arccot(")]
            case (false, true):
                return [("sinh", "sinh("), ("cosh", "cosh("), ("tanh", "tanh("), ("sech", "sech("), ("csch", "csch("), ("coth", "coth(")]
            case (true, true):
                return [("sinh⁻¹", "arcsinh("), ("cosh⁻¹", "arccosh("), ("tanh⁻¹", "arctanh("), ("sech⁻¹", "arcsech("), ("csch⁻¹", "arccsch("), ("coth⁻¹", "arccoth(")]
            }
        }()

        return Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            GridRow {
                FluentCalcButton(variant: .emphasizedToggle(isOn: vm.isTrigSecondChecked), action: { vm.isTrigSecondChecked.toggle() }) {
                    CalcGlyphText(CalcGlyph.second, size: 14)
                }
                ForEach(0..<3, id: \.self) { i in
                    FluentCalcButton(variant: .operator, action: {
                        vm.insertKeypadText(items[i].1)
                        showTrig = false
                    }) {
                        Text(items[i].0).font(.system(size: 12))
                    }
                }
            }
            GridRow {
                FluentCalcButton(variant: .emphasizedToggle(isOn: vm.isHypChecked), action: { vm.isHypChecked.toggle() }) {
                    Text("hyp").font(.system(size: 12))
                }
                ForEach(3..<6, id: \.self) { i in
                    FluentCalcButton(variant: .operator, action: {
                        vm.insertKeypadText(items[i].1)
                        showTrig = false
                    }) {
                        Text(items[i].0).font(.system(size: 12))
                    }
                }
            }
        }
        .frame(width: 260, height: 92)
    }

    private var graphIneqFlyout: some View {
        HStack(spacing: 2) {
            ineqBtn(CalcGlyph.lessThan, "<")
            ineqBtn(CalcGlyph.lessThanOrEqual, "≤")
            ineqBtn(CalcGlyph.equals, "=")
            ineqBtn(CalcGlyph.greaterThanOrEqual, "≥")
            ineqBtn(CalcGlyph.greaterThan, ">")
        }
        .frame(width: 280, height: 46)
    }

    private func ineqBtn(_ glyph: String, _ str: String) -> some View {
        FluentCalcButton(variant: .operator, action: {
            vm.insertKeypadText(str)
            showIneq = false
        }) {
            CalcGlyphText(glyph, size: 15)
        }
    }

    private var graphFuncFlyout: some View {
        HStack(spacing: 2) {
            funcBtn(CalcGlyph.abs, "abs(")
            funcBtn(CalcGlyph.floor, "floor(")
            funcBtn(CalcGlyph.ceil, "ceiling(")
        }
        .frame(width: 190, height: 46)
    }

    private func funcBtn(_ glyph: String, _ str: String) -> some View {
        FluentCalcButton(variant: .operator, action: {
            vm.insertKeypadText(str)
            showFunc = false
        }) {
            CalcGlyphText(glyph, size: 16)
        }
    }

    private func gNumBtn(_ digit: String) -> some View {
        FluentCalcButton(variant: .numeric, action: { vm.insertKeypadText(digit) }) {
            Text(digit).font(.system(size: 17))
        }
    }

    private func gTextBtn(_ label: String, insert: String, italic: Bool = false) -> some View {
        FluentCalcButton(variant: .operator, action: { vm.insertKeypadText(insert) }) {
            Text(label)
                .font(italic ? .system(size: 15, design: .serif).italic() : .system(size: 13))
        }
    }

    private func gGlyphBtn(_ glyph: String, insert: String) -> some View {
        FluentCalcButton(variant: .operator, action: { vm.insertKeypadText(insert) }) {
            CalcGlyphText(glyph, size: 15)
        }
    }

    private func gShiftGlyphBtn(_ glyph: String, insert: String) -> some View {
        FluentCalcButton(variant: .operator, action: {
            vm.isSecondChecked = false
            vm.insertKeypadText(insert)
        }) {
            CalcGlyphText(glyph, size: 15)
        }
    }
}
