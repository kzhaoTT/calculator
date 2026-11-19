import Foundation

public enum GraphTrigUnit: Int, CaseIterable, Sendable {
    case radians = 1
    case degrees = 2
    case gradians = 3
}

public enum EquationLineStyle: Int, CaseIterable, Identifiable, Sendable {
    case solid = 0
    case dash = 1
    case dot = 2

    public var id: Int { rawValue }
}

public enum GraphRelation: Equatable, Sendable {
    case expression        // e.g., x^2 (implicit y = expr)
    case equals            // y = expr OR x = const OR lhs = rhs
    case lessThan          // <
    case lessOrEqual       // <= / ≤
    case greaterThan       // >
    case greaterOrEqual    // >= / ≥

    public var isInequality: Bool {
        switch self {
        case .lessThan, .lessOrEqual, .greaterThan, .greaterOrEqual:
            return true
        default:
            return false
        }
    }

    public var isStrict: Bool {
        self == .lessThan || self == .greaterThan
    }
}

public enum ParsedEquationKind: Sendable {
    case explicitY(expr: MathAST, relation: GraphRelation)   // y <rel> f(x)
    case explicitX(expr: MathAST, relation: GraphRelation)   // x <rel> g(y)
    case implicit(lhs: MathAST, rhs: MathAST, relation: GraphRelation)
}

public struct ParsedEquation: Sendable {
    public let kind: ParsedEquationKind
    public let relation: GraphRelation
    public let parameters: [String] // free variables besides x, y

    public var isInequality: Bool { relation.isInequality }
}

public indirect enum MathAST: Sendable {
    case number(Double)
    case constant(String) // pi, e
    case variable(String)
    case unaryNeg(MathAST)
    case factorial(MathAST)
    case binary(op: BinaryOp, lhs: MathAST, rhs: MathAST)
    case call(name: String, args: [MathAST])

    public enum BinaryOp: Sendable {
        case add, sub, mul, div, pow
    }
}

public struct GraphAnalysisResult: Sendable {
    public let error: String?
    public let domain: String
    public let range: String
    public let xIntercepts: [String]
    public let yIntercept: String
    public let minima: [String]
    public let maxima: [String]
    public let inflectionPoints: [String]
    public let verticalAsymptotes: [String]
    public let horizontalAsymptotes: [String]
    public let parity: String
    public let periodicity: String?
    public let monotonicity: [(interval: String, direction: String)]
}

public enum GraphingParseError: Error, LocalizedError {
    case empty
    case syntax(String)

    public var errorDescription: String? {
        switch self {
        case .empty: return "Empty expression"
        case .syntax(let msg): return msg
        }
    }
}

/// Complete mathematical expression parser, evaluator, and Key Graph Features analyzer for Graphing mode.
public enum GraphingEngine {

    private static let knownFunctions: Set<String> = [
        "sin", "cos", "tan", "sec", "csc", "cot",
        "arcsin", "arccos", "arctan", "arcsec", "arccsc", "arccot",
        "asin", "acos", "atan", "asec", "acsc", "acot",
        "sinh", "cosh", "tanh", "sech", "csch", "coth",
        "arcsinh", "arccosh", "arctanh", "arcsech", "arccsch", "arccoth",
        "asinh", "acosh", "atanh", "asech", "acsch", "acoth",
        "sqrt", "cbrt", "root", "abs", "floor", "ceiling", "ceil", "log", "ln", "exp", "sign"
    ]

    private enum Token: Equatable {
        case number(Double)
        case ident(String)
        case plus, minus, star, slash, caret, bang
        case lparen, rparen, comma, pipe
        case eq, lt, lte, gt, gte
        case eof
    }

    public static func parse(_ rawInput: String) throws -> ParsedEquation {
        let trimmed = rawInput
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "𝑥", with: "x")
            .replacingOccurrences(of: "𝑦", with: "y")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GraphingParseError.empty }

        let tokens = try tokenize(trimmed)
        let relIndices = tokens.enumerated().compactMap { idx, tok -> (Int, GraphRelation)? in
            switch tok {
            case .eq: return (idx, .equals)
            case .lt: return (idx, .lessThan)
            case .lte: return (idx, .lessOrEqual)
            case .gt: return (idx, .greaterThan)
            case .gte: return (idx, .greaterOrEqual)
            default: return nil
            }
        }

        if relIndices.count > 1 {
            throw GraphingParseError.syntax("Too many comparison operators")
        }

        if let (relIdx, relation) = relIndices.first {
            let lhsTokens = Array(tokens[0..<relIdx]) + [.eof]
            let rhsTokens = Array(tokens[(relIdx + 1)..<tokens.count])
            guard lhsTokens.count > 1 && rhsTokens.count > 1 else {
                throw GraphingParseError.syntax("Incomplete equation")
            }
            let lhs = try Parser(tokens: lhsTokens).parseAll()
            let rhs = try Parser(tokens: rhsTokens).parseAll()

            let vars = collectVariables(lhs).union(collectVariables(rhs))
            let params = vars.subtracting(["x", "y"]).sorted()

            if case .variable("y") = lhs, !collectVariables(rhs).contains("y") {
                return ParsedEquation(kind: .explicitY(expr: rhs, relation: relation), relation: relation, parameters: params)
            }
            if case .variable("y") = rhs, !collectVariables(lhs).contains("y") {
                let flipped = flipRelation(relation)
                return ParsedEquation(kind: .explicitY(expr: lhs, relation: flipped), relation: flipped, parameters: params)
            }
            if case .variable("x") = lhs, !collectVariables(rhs).contains("x") {
                return ParsedEquation(kind: .explicitX(expr: rhs, relation: relation), relation: relation, parameters: params)
            }
            if case .variable("x") = rhs, !collectVariables(lhs).contains("x") {
                let flipped = flipRelation(relation)
                return ParsedEquation(kind: .explicitX(expr: lhs, relation: flipped), relation: flipped, parameters: params)
            }
            return ParsedEquation(kind: .implicit(lhs: lhs, rhs: rhs, relation: relation), relation: relation, parameters: params)
        } else {
            let expr = try Parser(tokens: tokens).parseAll()
            let vars = collectVariables(expr)
            let params = vars.subtracting(["x", "y"]).sorted()
            if vars.contains("y") && !vars.contains("x") {
                return ParsedEquation(kind: .explicitX(expr: expr, relation: .expression), relation: .expression, parameters: params)
            }
            return ParsedEquation(kind: .explicitY(expr: expr, relation: .expression), relation: .expression, parameters: params)
        }
    }

    private static func flipRelation(_ r: GraphRelation) -> GraphRelation {
        switch r {
        case .lessThan: return .greaterThan
        case .lessOrEqual: return .greaterOrEqual
        case .greaterThan: return .lessThan
        case .greaterOrEqual: return .lessOrEqual
        default: return r
        }
    }

    private static func tokenize(_ s: String) throws -> [Token] {
        var tokens: [Token] = []
        let chars = Array(s)
        var i = 0

        func needsImplicitMul(before next: Token) -> Bool {
            guard let prev = tokens.last else { return false }
            switch prev {
            case .number, .ident, .rparen, .bang:
                switch next {
                case .ident, .lparen, .number:
                    return true
                default:
                    return false
                }
            default:
                return false
            }
        }

        while i < chars.count {
            let c = chars[i]
            if c.isWhitespace {
                i += 1
                continue
            }
            if c.isNumber || (c == "." && i + 1 < chars.count && chars[i + 1].isNumber) {
                var numStr = ""
                var hasDot = false
                while i < chars.count && (chars[i].isNumber || (chars[i] == "." && !hasDot)) {
                    if chars[i] == "." { hasDot = true }
                    numStr.append(chars[i])
                    i += 1
                }
                guard let val = Double(numStr) else {
                    throw GraphingParseError.syntax("Invalid number: \(numStr)")
                }
                let tok = Token.number(val)
                if needsImplicitMul(before: tok) { tokens.append(.star) }
                tokens.append(tok)
                continue
            }
            if c == "π" {
                let tok = Token.ident("pi")
                if needsImplicitMul(before: tok) { tokens.append(.star) }
                tokens.append(tok)
                i += 1
                continue
            }
            if c.isLetter {
                var word = ""
                while i < chars.count && chars[i].isLetter {
                    word.append(chars[i])
                    i += 1
                }
                let lower = word.lowercased()
                if knownFunctions.contains(lower) || lower == "pi" {
                    let tok = Token.ident(lower)
                    if needsImplicitMul(before: tok) { tokens.append(.star) }
                    tokens.append(tok)
                } else {
                    // Check if word ends with a known function like "xsin" or splits into single-letter vars like "ax"
                    var remaining = lower
                    while !remaining.isEmpty {
                        if let matchedFn = knownFunctions.first(where: { remaining.hasPrefix($0) && remaining.count == $0.count }) {
                            let tok = Token.ident(matchedFn)
                            if needsImplicitMul(before: tok) { tokens.append(.star) }
                            tokens.append(tok)
                            remaining = ""
                        } else if remaining.hasPrefix("pi") {
                            let tok = Token.ident("pi")
                            if needsImplicitMul(before: tok) { tokens.append(.star) }
                            tokens.append(tok)
                            remaining.removeFirst(2)
                        } else {
                            let ch = String(remaining.removeFirst())
                            let tok = Token.ident(ch)
                            if needsImplicitMul(before: tok) { tokens.append(.star) }
                            tokens.append(tok)
                        }
                    }
                }
                continue
            }

            switch c {
            case "+": tokens.append(.plus); i += 1
            case "-": tokens.append(.minus); i += 1
            case "*": tokens.append(.star); i += 1
            case "/": tokens.append(.slash); i += 1
            case "^": tokens.append(.caret); i += 1
            case "!": tokens.append(.bang); i += 1
            case "(":
                if needsImplicitMul(before: .lparen) {
                    // Do not insert '*' if previous token is a known function name!
                    if case .ident(let name) = tokens.last, knownFunctions.contains(name) {
                        // function call
                    } else {
                        tokens.append(.star)
                    }
                }
                tokens.append(.lparen); i += 1
            case ")": tokens.append(.rparen); i += 1
            case ",": tokens.append(.comma); i += 1
            case "|": tokens.append(.pipe); i += 1
            case "=": tokens.append(.eq); i += 1
            case "≤": tokens.append(.lte); i += 1
            case "≥": tokens.append(.gte); i += 1
            case "<":
                if i + 1 < chars.count && chars[i + 1] == "=" {
                    tokens.append(.lte); i += 2
                } else {
                    tokens.append(.lt); i += 1
                }
            case ">":
                if i + 1 < chars.count && chars[i + 1] == "=" {
                    tokens.append(.gte); i += 2
                } else {
                    tokens.append(.gt); i += 1
                }
            default:
                throw GraphingParseError.syntax("Unexpected character '\(c)'")
            }
        }
        tokens.append(.eof)
        return tokens
    }

    private final class Parser {
        private let tokens: [Token]
        private var pos = 0

        init(tokens: [Token]) { self.tokens = tokens }
        private var current: Token { tokens[min(pos, tokens.count - 1)] }

        private func advance() -> Token {
            let t = current
            if pos < tokens.count - 1 { pos += 1 }
            return t
        }

        func parseAll() throws -> MathAST {
            let node = try parseAddSub()
            guard current == .eof else {
                throw GraphingParseError.syntax("Unexpected token")
            }
            return node
        }

        private func parseAddSub() throws -> MathAST {
            var left = try parseMulDiv()
            while true {
                if current == .plus {
                    _ = advance()
                    left = .binary(op: .add, lhs: left, rhs: try parseMulDiv())
                } else if current == .minus {
                    _ = advance()
                    left = .binary(op: .sub, lhs: left, rhs: try parseMulDiv())
                } else {
                    break
                }
            }
            return left
        }

        private func parseMulDiv() throws -> MathAST {
            var left = try parseUnary()
            while true {
                if current == .star {
                    _ = advance()
                    left = .binary(op: .mul, lhs: left, rhs: try parseUnary())
                } else if current == .slash {
                    _ = advance()
                    left = .binary(op: .div, lhs: left, rhs: try parseUnary())
                } else {
                    break
                }
            }
            return left
        }

        private func parseUnary() throws -> MathAST {
            if current == .minus {
                _ = advance()
                return .unaryNeg(try parseUnary())
            }
            if current == .plus {
                _ = advance()
                return try parseUnary()
            }
            return try parsePower()
        }

        private func parsePower() throws -> MathAST {
            let base = try parsePostfix()
            if current == .caret {
                _ = advance()
                let exp = try parseUnary()
                return .binary(op: .pow, lhs: base, rhs: exp)
            }
            return base
        }

        private func parsePostfix() throws -> MathAST {
            var node = try parsePrimary()
            while current == .bang {
                _ = advance()
                node = .factorial(node)
            }
            return node
        }

        private func parsePrimary() throws -> MathAST {
            switch current {
            case .number(let val):
                _ = advance()
                return .number(val)
            case .ident(let name):
                _ = advance()
                if name == "pi" || name == "e" {
                    return .constant(name)
                }
                if GraphingEngine.knownFunctions.contains(name) {
                    if current == .lparen {
                        _ = advance()
                        var args: [MathAST] = []
                        if current != .rparen {
                            args.append(try parseAddSub())
                            while current == .comma {
                                _ = advance()
                                args.append(try parseAddSub())
                            }
                        }
                        guard current == .rparen else {
                            throw GraphingParseError.syntax("Expected ')'")
                        }
                        _ = advance()
                        return .call(name: name, args: args)
                    } else {
                        // Allow shorthand like sin x
                        let arg = try parseUnary()
                        return .call(name: name, args: [arg])
                    }
                }
                return .variable(name)
            case .lparen:
                _ = advance()
                let inner = try parseAddSub()
                guard current == .rparen else {
                    throw GraphingParseError.syntax("Unmatched '('")
                }
                _ = advance()
                return inner
            case .pipe:
                _ = advance()
                let inner = try parseAddSub()
                guard current == .pipe else {
                    throw GraphingParseError.syntax("Unmatched '|'")
                }
                _ = advance()
                return .call(name: "abs", args: [inner])
            default:
                throw GraphingParseError.syntax("Expected expression")
            }
        }
    }

    private static func collectVariables(_ ast: MathAST) -> Set<String> {
        switch ast {
        case .number, .constant: return []
        case .variable(let name): return [name]
        case .unaryNeg(let inner), .factorial(let inner): return collectVariables(inner)
        case .binary(_, let l, let r): return collectVariables(l).union(collectVariables(r))
        case .call(_, let args): return args.reduce(into: Set<String>()) { $0.formUnion(collectVariables($1)) }
        }
    }

    // MARK: - Evaluator

    public static func evaluate(
        _ ast: MathAST,
        x: Double = 0,
        y: Double = 0,
        variables: [String: Double] = [:],
        trigUnit: GraphTrigUnit = .radians
    ) -> Double {
        let toRad: (Double) -> Double = { angle in
            switch trigUnit {
            case .radians: return angle
            case .degrees: return angle * .pi / 180.0
            case .gradians: return angle * .pi / 200.0
            }
        }
        let fromRad: (Double) -> Double = { rad in
            switch trigUnit {
            case .radians: return rad
            case .degrees: return rad * 180.0 / .pi
            case .gradians: return rad * 200.0 / .pi
            }
        }

        func eval(_ node: MathAST) -> Double {
            switch node {
            case .number(let v): return v
            case .constant(let name):
                return name == "pi" ? .pi : M_E
            case .variable(let name):
                if name == "x" { return x }
                if name == "y" { return y }
                return variables[name] ?? 1.0
            case .unaryNeg(let inner):
                return -eval(inner)
            case .factorial(let inner):
                let v = eval(inner)
                guard v.isFinite, v >= -170, v <= 170 else { return .nan }
                if v < 0 && v.rounded() == v { return .nan }
                return tgamma(v + 1.0)
            case .binary(let op, let lhs, let rhs):
                let a = eval(lhs)
                let b = eval(rhs)
                switch op {
                case .add: return a + b
                case .sub: return a - b
                case .mul: return a * b
                case .div: return b == 0 ? .nan : a / b
                case .pow:
                    if a < 0 && b.rounded() != b {
                        // Handle odd rational roots like x^(1/3)
                        let inv = 1.0 / b
                        if abs(inv - inv.rounded()) < 1e-9 && Int(inv.rounded()) % 2 != 0 {
                            return -Foundation.pow(-a, b)
                        }
                    }
                    return Foundation.pow(a, b)
                }
            case .call(let name, let args):
                let a = args.isEmpty ? .nan : eval(args[0])
                switch name {
                case "sin": return Foundation.sin(toRad(a))
                case "cos": return Foundation.cos(toRad(a))
                case "tan": return Foundation.tan(toRad(a))
                case "sec": let c = Foundation.cos(toRad(a)); return abs(c) < 1e-12 ? .nan : 1.0 / c
                case "csc": let s = Foundation.sin(toRad(a)); return abs(s) < 1e-12 ? .nan : 1.0 / s
                case "cot": let t = Foundation.tan(toRad(a)); return abs(t) < 1e-12 ? .nan : 1.0 / t
                case "arcsin", "asin": return fromRad(Foundation.asin(a))
                case "arccos", "acos": return fromRad(Foundation.acos(a))
                case "arctan", "atan": return fromRad(Foundation.atan(a))
                case "arcsec", "asec": return abs(a) < 1 ? .nan : fromRad(Foundation.acos(1.0 / a))
                case "arccsc", "acsc": return abs(a) < 1 ? .nan : fromRad(Foundation.asin(1.0 / a))
                case "arccot", "acot": return a == 0 ? fromRad(.pi / 2) : fromRad(Foundation.atan(1.0 / a))
                case "sinh": return Foundation.sinh(a)
                case "cosh": return Foundation.cosh(a)
                case "tanh": return Foundation.tanh(a)
                case "sech": return 1.0 / Foundation.cosh(a)
                case "csch": return a == 0 ? .nan : 1.0 / Foundation.sinh(a)
                case "coth": return a == 0 ? .nan : 1.0 / Foundation.tanh(a)
                case "arcsinh", "asinh": return Foundation.asinh(a)
                case "arccosh", "acosh": return Foundation.acosh(a)
                case "arctanh", "atanh": return Foundation.atanh(a)
                case "arcsech", "asech": return (a <= 0 || a > 1) ? .nan : Foundation.acosh(1.0 / a)
                case "arccsch", "acsch": return a == 0 ? .nan : Foundation.asinh(1.0 / a)
                case "arccoth", "acoth": return abs(a) <= 1 ? .nan : Foundation.atanh(1.0 / a)
                case "sqrt": return a < 0 ? .nan : Foundation.sqrt(a)
                case "cbrt": return Foundation.cbrt(a)
                case "root":
                    guard args.count >= 2 else { return .nan }
                    let n = eval(args[1])
                    guard n != 0 else { return .nan }
                    if a < 0 && n.rounded() == n && Int(n) % 2 != 0 {
                        return -Foundation.pow(-a, 1.0 / n)
                    }
                    return Foundation.pow(a, 1.0 / n)
                case "abs": return Swift.abs(a)
                case "floor": return Foundation.floor(a)
                case "ceiling", "ceil": return Foundation.ceil(a)
                case "log":
                    if args.count >= 2 {
                        let b = eval(args[0])
                        let val = eval(args[1])
                        return (b > 0 && b != 1 && val > 0) ? Foundation.log(val) / Foundation.log(b) : .nan
                    }
                    return a > 0 ? Foundation.log10(a) : .nan
                case "ln": return a > 0 ? Foundation.log(a) : .nan
                case "exp": return Foundation.exp(a)
                case "sign": return a > 0 ? 1 : (a < 0 ? -1 : 0)
                default: return .nan
                }
            }
        }

        return eval(ast)
    }

    // MARK: - Numerical Key Graph Features Analyzer

    public static func analyze(
        _ parsed: ParsedEquation,
        variables: [String: Double],
        trigUnit: GraphTrigUnit,
        xMin: Double = -10,
        xMax: Double = 10
    ) -> GraphAnalysisResult {
        guard case .explicitY(let expr, let rel) = parsed.kind, !rel.isInequality else {
            return GraphAnalysisResult(
                error: ResourceProvider.shared.string("KGFAnalysisNotSupported", fallback: "Function analysis is not supported for this equation."),
                domain: "", range: "", xIntercepts: [], yIntercept: "",
                minima: [], maxima: [], inflectionPoints: [],
                verticalAsymptotes: [], horizontalAsymptotes: [],
                parity: "", periodicity: nil, monotonicity: []
            )
        }

        func f(_ x: Double) -> Double {
            evaluate(expr, x: x, variables: variables, trigUnit: trigUnit)
        }

        let scanMin = min(xMin, -20)
        let scanMax = max(xMax, 20)
        let steps = 2000
        let dx = (scanMax - scanMin) / Double(steps)

        var xs: [Double] = []
        var ys: [Double] = []
        xs.reserveCapacity(steps + 1)
        ys.reserveCapacity(steps + 1)
        for i in 0...steps {
            let x = scanMin + Double(i) * dx
            xs.append(x)
            ys.append(f(x))
        }

        // Y-intercept
        let y0 = f(0)
        let yIntStr = y0.isFinite ? "(0, \(fmt(y0)))" : ResourceProvider.shared.string("KGFYInterceptNone", fallback: "None")

        // X-intercepts (roots via sign changes + bisection)
        var roots: [Double] = []
        for i in 0..<steps {
            let y1 = ys[i], y2 = ys[i + 1]
            guard y1.isFinite, y2.isFinite else { continue }
            if abs(y1 - y2) > 50 { continue } // skip vertical asymptote jump
            if abs(y1) < 1e-6 {
                appendUnique(&roots, xs[i])
            } else if y1 * y2 < 0 {
                let r = bisect(f, xs[i], xs[i + 1])
                if abs(f(r)) < 1e-2 {
                    appendUnique(&roots, r)
                }
            }
        }
        let xIntercepts = roots.prefix(8).map { "(\(fmt($0)), 0)" }

        // Local minima, maxima & vertical asymptotes
        var minima: [(Double, Double)] = []
        var maxima: [(Double, Double)] = []
        var vAsym: [Double] = []
        for i in 1..<steps {
            let yPrev = ys[i - 1], yCur = ys[i], yNext = ys[i + 1]
            if (!yCur.isFinite || abs(yCur) > 1e5) && (yPrev.isFinite || yNext.isFinite) {
                appendUnique(&vAsym, xs[i], tol: 0.15)
                continue
            }
            guard yPrev.isFinite, yCur.isFinite, yNext.isFinite else { continue }
            if abs(yCur - yPrev) > 50 || abs(yNext - yCur) > 50 {
                appendUnique(&vAsym, xs[i], tol: 0.15)
                continue
            }
            if yCur < yPrev && yCur < yNext {
                let xStar = goldenSectionMin(f, xs[i - 1], xs[i + 1])
                let yStar = f(xStar)
                if yStar.isFinite && !minima.contains(where: { abs($0.0 - xStar) < 0.05 }) {
                    minima.append((xStar, yStar))
                }
            } else if yCur > yPrev && yCur > yNext {
                let xStar = goldenSectionMin({ -f($0) }, xs[i - 1], xs[i + 1])
                let yStar = f(xStar)
                if yStar.isFinite && !maxima.contains(where: { abs($0.0 - xStar) < 0.05 }) {
                    maxima.append((xStar, yStar))
                }
            }
        }

        // Inflection points (f'' sign change)
        var inflections: [(Double, Double)] = []
        let h = 1e-3
        var prevD2: Double?
        for i in stride(from: 4, to: steps - 4, by: 2) {
            let x = xs[i]
            let d2 = (f(x + h) - 2 * f(x) + f(x - h)) / (h * h)
            guard d2.isFinite, abs(d2) < 1e4 else { prevD2 = nil; continue }
            if let p = prevD2, p * d2 < 0 {
                let yVal = f(x)
                if yVal.isFinite && !inflections.contains(where: { abs($0.0 - x) < 0.1 }) {
                    inflections.append((x, yVal))
                }
            }
            prevD2 = d2
        }

        // Horizontal asymptotes
        var hAsym: [Double] = []
        let posInf1 = f(1e4), posInf2 = f(1e5)
        if posInf1.isFinite && posInf2.isFinite && abs(posInf1 - posInf2) < 1e-3 && abs(posInf2) < 1e5 {
            appendUnique(&hAsym, posInf2, tol: 1e-2)
        }
        let negInf1 = f(-1e4), negInf2 = f(-1e5)
        if negInf1.isFinite && negInf2.isFinite && abs(negInf1 - negInf2) < 1e-3 && abs(negInf2) < 1e5 {
            appendUnique(&hAsym, negInf2, tol: 1e-2)
        }

        // Parity check
        var isEven = true
        var isOdd = true
        let samplePoints = [0.37, 1.13, 2.41, 3.79, 5.17]
        var validParitySamples = 0
        for sp in samplePoints {
            let fp = f(sp), fn = f(-sp)
            if fp.isFinite && fn.isFinite {
                validParitySamples += 1
                if abs(fp - fn) > 1e-4 { isEven = false }
                if abs(fp + fn) > 1e-4 { isOdd = false }
            } else if fp.isFinite != fn.isFinite {
                isEven = false
                isOdd = false
            }
        }
        let parityStr: String
        if validParitySamples == 0 {
            parityStr = ResourceProvider.shared.string("KGFParityUnknown", fallback: "Unknown")
        } else if isEven && !isOdd {
            parityStr = ResourceProvider.shared.string("KGFParityEven", fallback: "Even")
        } else if isOdd && !isEven {
            parityStr = ResourceProvider.shared.string("KGFParityOdd", fallback: "Odd")
        } else if isEven && isOdd {
            parityStr = ResourceProvider.shared.string("KGFParityEven", fallback: "Even")
        } else {
            parityStr = ResourceProvider.shared.string("KGFParityNeither", fallback: "Neither")
        }

        // Domain & Range summary
        let finiteYs = ys.filter { $0.isFinite && abs($0) < 1e6 }
        let domainStr: String
        let nonNegOnly = f(-1).isNaN && f(-5).isNaN && f(1).isFinite
        if nonNegOnly {
            domainStr = f(0).isFinite ? "x ≥ 0" : "x > 0"
        } else if vAsym.isEmpty {
            domainStr = "ℝ  (-∞, ∞)"
        } else {
            let ex = vAsym.prefix(4).map { fmt($0) }.joined(separator: ", ")
            domainStr = "x ≠ \(ex)"
        }

        let rangeStr: String
        if let lo = finiteYs.min(), let hi = finiteYs.max() {
            if abs(lo - hi) < 1e-6 {
                rangeStr = "y = \(fmt(lo))"
            } else if hi - lo > 1000 && lo < -100 && hi > 100 {
                rangeStr = "ℝ  (-∞, ∞)"
            } else if lo > -1e-4 && lo < 1e-4 && hi > 100 {
                rangeStr = "y ≥ 0"
            } else {
                rangeStr = "[\(fmt(lo)), \(fmt(hi))]"
            }
        } else {
            rangeStr = ResourceProvider.shared.string("KGFRangeNone", fallback: "None")
        }

        // Monotonicity summary over visible critical points
        let crits = (minima.map(\.0) + maxima.map(\.0) + vAsym)
            .filter { $0 > xMin && $0 < xMax }
            .sorted()
        var monoIntervals: [(String, String)] = []
        let bounds = [xMin] + crits + [xMax]
        for idx in 0..<(bounds.count - 1) {
            let a = bounds[idx], b = bounds[idx + 1]
            guard b - a > 0.05 else { continue }
            let mid = (a + b) / 2
            let d = (f(mid + 1e-4) - f(mid - 1e-4)) / 2e-4
            guard d.isFinite else { continue }
            let dir: String
            if abs(d) < 1e-6 {
                dir = ResourceProvider.shared.string("KGFMonotonicityConstant", fallback: "Constant")
            } else if d > 0 {
                dir = ResourceProvider.shared.string("KGFMonotonicityIncreasing", fallback: "Increasing")
            } else {
                dir = ResourceProvider.shared.string("KGFMonotonicityDecreasing", fallback: "Decreasing")
            }
            let leftStr = idx == 0 ? "-∞" : fmt(a)
            let rightStr = idx == bounds.count - 2 ? "∞" : fmt(b)
            monoIntervals.append(("(\(leftStr), \(rightStr))", dir))
        }

        return GraphAnalysisResult(
            error: nil,
            domain: domainStr,
            range: rangeStr,
            xIntercepts: Array(xIntercepts),
            yIntercept: yIntStr,
            minima: minima.prefix(6).map { "(\(fmt($0.0)), \(fmt($0.1)))" },
            maxima: maxima.prefix(6).map { "(\(fmt($0.0)), \(fmt($0.1)))" },
            inflectionPoints: inflections.prefix(6).map { "(\(fmt($0.0)), \(fmt($0.1)))" },
            verticalAsymptotes: vAsym.prefix(6).map { "x = \(fmt($0))" },
            horizontalAsymptotes: hAsym.prefix(4).map { "y = \(fmt($0))" },
            parity: parityStr,
            periodicity: nil,
            monotonicity: Array(monoIntervals.prefix(6))
        )
    }

    private static func bisect(_ f: (Double) -> Double, _ a0: Double, _ b0: Double) -> Double {
        var a = a0, b = b0
        var fa = f(a)
        for _ in 0..<40 {
            let m = 0.5 * (a + b)
            let fm = f(m)
            if abs(fm) < 1e-10 { return m }
            if fa * fm <= 0 { b = m } else { a = m; fa = fm }
        }
        return 0.5 * (a + b)
    }

    private static func goldenSectionMin(_ f: (Double) -> Double, _ a0: Double, _ b0: Double) -> Double {
        var a = a0, b = b0
        let phi = (Foundation.sqrt(5.0) - 1.0) / 2.0
        var c = b - phi * (b - a)
        var d = a + phi * (b - a)
        for _ in 0..<35 {
            if f(c) < f(d) {
                b = d; d = c; c = b - phi * (b - a)
            } else {
                a = c; c = d; d = a + phi * (b - a)
            }
        }
        return 0.5 * (a + b)
    }

    private static func appendUnique(_ arr: inout [Double], _ val: Double, tol: Double = 0.02) {
        let cleaned = abs(val) < 1e-6 ? 0.0 : val
        if !arr.contains(where: { abs($0 - cleaned) < tol }) {
            arr.append(cleaned)
        }
    }

    public static func fmt(_ v: Double) -> String {
        let cleaned = abs(v) < 1e-9 ? 0.0 : v
        if cleaned == cleaned.rounded() && abs(cleaned) < 1e9 {
            return String(Int(cleaned))
        }
        return String(format: "%.4g", cleaned)
    }
}
