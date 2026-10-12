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

// Display grouping never changes the stored numeric value or passes formatted
// commas to the decimal parser. Preserve partial input and decimal precision.
nonisolated enum AmountEditing {
    nonisolated struct Change: Equatable, Sendable {
        let text: String
        let display: String
        let caret: Int
    }

    static func canonicalText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if matches(trimmed, pattern: #"^[+-]?(?:[0-9]+(?:[.,][0-9]*)?|[.,][0-9]*|)$"#) || AmountInput.parse(trimmed) != nil {
            return trimmed.replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "\u{00A0}", with: "")
                .replacingOccurrences(of: "\u{202F}", with: "")
                .replacingOccurrences(of: ",", with: ".")
        }
        return text
    }

    static func displayText(_ text: String) -> String {
        let raw = canonicalText(text)
        guard isEditable(raw) else { return raw }
        var unsigned = raw
        var sign = ""
        if unsigned.hasPrefix("-") || unsigned.hasPrefix("+") {
            sign = String(unsigned.removeFirst())
        }
        if unsigned.isEmpty { return sign }
        let parts = unsigned.split(separator: ".", omittingEmptySubsequences: false)
        let digits = Array(parts[0])
        var grouped = ""
        for (index, digit) in digits.enumerated() {
            if index > 0 && (digits.count - index).isMultiple(of: 3) { grouped += "," }
            grouped.append(digit)
        }
        return sign + grouped + (parts.count == 2 ? "." + String(parts[1]) : "")
    }

    static func applying(to text: String, range: NSRange, replacement: String) -> Change? {
        let raw = canonicalText(text)
        let shown = displayText(text)
        guard range.location >= 0, range.length >= 0,
              range.location <= (shown as NSString).length,
              range.length <= (shown as NSString).length - range.location,
              Range(range, in: shown) != nil else { return nil }
        let hasGrouping = isEditable(raw)
        func rawOffset(_ displayOffset: Int) -> Int {
            let prefix = (shown as NSString).substring(to: displayOffset)
            return (hasGrouping ? prefix.replacingOccurrences(of: ",", with: "") : prefix).utf16.count
        }
        var start = rawOffset(range.location)
        var end = rawOffset(range.location + range.length)
        // Backspace next to a generated comma should delete the preceding
        // digit rather than recreating the separator and trapping the cursor.
        if replacement.isEmpty && range.length > 0 && start == end && start > 0 {
            start -= 1; end = start + 1
        }
        let inserted = normalizedReplacement(replacement)
        let edited = (raw as NSString).replacingCharacters(in: NSRange(location: start, length: end - start), with: inserted)
        let updated = canonicalText(edited)
        let prefix = (edited as NSString).substring(to: start + inserted.utf16.count)
        let position = updated == edited ? prefix.utf16.count : prefix.filter { !$0.isWhitespace }.utf16.count
        let display = displayText(updated)
        return Change(text: updated, display: display,
                      caret: displayOffset(for: position, in: display, grouped: isEditable(updated)))
    }

    private static func normalizedReplacement(_ text: String) -> String {
        if text == "," { return "." }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Pasted English grouping is unambiguous in the comma-grouped field.
        if matches(trimmed, pattern: #"^[+-]?[0-9]{1,3}(?:,[0-9]{3})+(?:\.[0-9]*)?$"#) {
            return trimmed.replacingOccurrences(of: ",", with: "")
        }
        if matches(trimmed, pattern: #"^[+-]?[0-9]{1,3}(?:\.[0-9]{3})+,[0-9]+$"#) {
            return trimmed.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        }
        return canonicalText(text)
    }

    private static func displayOffset(for rawOffset: Int, in text: String, grouped: Bool) -> Int {
        guard rawOffset > 0 else { return 0 }
        var raw = 0
        var display = 0
        for character in text {
            display += String(character).utf16.count
            if !grouped || character != "," { raw += String(character).utf16.count }
            if raw >= rawOffset { return display }
        }
        return display
    }

    private static func isEditable(_ text: String) -> Bool {
        matches(text, pattern: #"^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]*|)$"#)
    }

    private static func matches(_ text: String, pattern: String) -> Bool {
        guard text.utf16.count <= 300, let range = text.range(of: pattern, options: .regularExpression) else { return false }
        return range == (text.startIndex..<text.endIndex)
    }
}
