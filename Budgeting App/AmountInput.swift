import Foundation

nonisolated enum AmountInput {
    static func parse(_ text: String, allowNegative: Bool = true) -> Decimal? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Thousands may be grouped with spaces; dot and comma are decimal
        // separators. Require the entire input, never a numeric prefix.
        let pattern = #"^[+-]?(?:(?:[0-9]{1,3}(?:[ \u00A0\u202F][0-9]{3})+|[0-9]+)(?:[.,][0-9]+)?|[.,][0-9]+)$"#
        guard !cleaned.isEmpty, cleaned.count <= 200,
              let match = cleaned.range(of: pattern, options: .regularExpression),
              match == (cleaned.startIndex..<cleaned.endIndex) else { return nil }
        let normalized = cleaned.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: "\u{202F}", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")),
              !value.isNaN, allowNegative || value >= 0,
              let original = representation(normalized),
              let saved = representation(NSDecimalNumber(decimal: value).stringValue),
              original == saved else { return nil }
        return value
    }

    static func positive(_ text: String) -> Decimal? {
        guard let value = parse(text, allowNegative: false), value > 0 else { return nil }
        return value
    }

    // Compare exact decimal representations without converting through Double.
    // Foundation may serialize large/small numbers in scientific notation.
    private static func representation(_ text: String) -> String? {
        var unsigned = text
        let negative = unsigned.hasPrefix("-")
        if unsigned.hasPrefix("-") || unsigned.hasPrefix("+") { unsigned.removeFirst() }
        let components = unsigned.lowercased().split(separator: "e", omittingEmptySubsequences: false)
        guard components.count <= 2 else { return nil }
        let exponent: Int
        if components.count == 2 {
            guard let parsed = Int(components[1]) else { return nil }
            exponent = parsed
        } else { exponent = 0 }
        let parts = components[0].split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return nil }
        let fractional = parts.count == 2 ? String(parts[1]) : ""
        var digits = String(parts[0]) + fractional
        guard !digits.isEmpty, digits.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }) else { return nil }
        var power = exponent - fractional.count
        while digits.first == "0" { digits.removeFirst() }
        if digits.isEmpty { return "0" }
        while digits.last == "0" { digits.removeLast(); power += 1 }
        return "\(negative ? "-" : "")\(digits)e\(power)"
    }
}
