import CoreText
import Foundation

public final class ResourceProvider: @unchecked Sendable {
    public static let shared = ResourceProvider()

    private let uiStrings: [String: String]
    private let engineStrings: [String: String]
    private nonisolated(unsafe) static var fontRegistered = false
    private static let fontLock = NSLock()

    public init() {
        self.uiStrings = Self.loadResw(named: "Resources")
        self.engineStrings = Self.loadResw(named: "CEngineStrings")
    }

    public static func registerCalculatorFont() {
        fontLock.lock()
        defer { fontLock.unlock() }
        guard !fontRegistered else { return }
        fontRegistered = true

        if let url = Bundle.module.url(forResource: "CalculatorIcons", withExtension: "ttf") {
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
    }

    public func string(_ key: String, fallback: String? = nil) -> String {
        if let value = uiStrings[key] {
            return value
        }
        // XAML x:Uid lookup converts '/' to '.'
        let dotKey = key.replacingOccurrences(of: "/", with: ".")
        if let value = uiStrings[dotKey] {
            return value
        }
        return fallback ?? key
    }

    public func localizedFormat(_ key: String, _ args: String...) -> String {
        var template = string(key)
        for (idx, arg) in args.enumerated() {
            template = template.replacingOccurrences(of: "%\(idx + 1)", with: arg)
        }
        return template
    }

    public func engineString(_ id: String) -> String {
        switch id {
        case "sDecimal":
            return decimalSeparator
        case "sThousand":
            return groupingSeparator
        case "sGrouping":
            return "3;0"
        default:
            return engineStrings[id] ?? ""
        }
    }

    public var decimalSeparator: String {
        Locale.current.decimalSeparator ?? "."
    }

    public var groupingSeparator: String {
        Locale.current.groupingSeparator ?? ","
    }

    public var listSeparator: String {
        decimalSeparator == "," ? ";" : ","
    }

    public var regionCode: String {
        Locale.current.region?.identifier ?? "US"
    }

    public func removeGroupSeparators(_ value: String) -> String {
        guard !groupingSeparator.isEmpty else { return value }
        return value.replacingOccurrences(of: groupingSeparator, with: "")
    }

    private static func loadResw(named name: String) -> [String: String] {
        guard let url = Bundle.module.url(forResource: name, withExtension: "resw"),
              let data = try? Data(contentsOf: url)
        else {
            return [:]
        }
        let parserDelegate = ReswXMLParser()
        let parser = XMLParser(data: data)
        parser.delegate = parserDelegate
        parser.parse()
        return parserDelegate.entries
    }
}

private final class ReswXMLParser: NSObject, XMLParserDelegate {
    var entries: [String: String] = [:]
    private var currentName: String?
    private var inValue = false
    private var currentValue = ""

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == "data" {
            currentName = attributeDict["name"]
        } else if elementName == "value", currentName != nil {
            inValue = true
            currentValue = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inValue {
            currentValue += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "value", inValue {
            if let name = currentName {
                entries[name] = currentValue
            }
            inValue = false
            currentValue = ""
        } else if elementName == "data" {
            currentName = nil
        }
    }
}
