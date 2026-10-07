import Foundation

nonisolated struct CurrencyPreferences: Codable, Sendable, Equatable {
    static let storageKey = "currencyPreferences"
    static let defaultStorageValue = #"{"enabledCodes":["HUF","EUR","GBP","USD"],"defaultCode":"HUF"}"#
    static let defaults = CurrencyPreferences(enabledCodes: ["HUF", "EUR", "GBP", "USD"], defaultCode: "HUF")

    var enabledCodes: [String]
    var defaultCode: String

    static var availableCodes: [String] {
        Array(Set(Locale.commonISOCurrencyCodes + defaults.enabledCodes)).filter(isCurrencyCode).sorted()
    }

    static func name(for code: String, locale: Locale = .current) -> String {
        locale.localizedString(forCurrencyCode: code) ?? code
    }

    static func isCurrencyCode(_ code: String) -> Bool {
        code.utf8.count == 3 && code.utf8.allSatisfy { $0 >= 65 && $0 <= 90 }
    }

    var isValid: Bool {
        !enabledCodes.isEmpty && enabledCodes.count <= 256 &&
        Set(enabledCodes).count == enabledCodes.count &&
        enabledCodes.allSatisfy(Self.isCurrencyCode) && enabledCodes.contains(defaultCode)
    }

    static func decode(_ stored: String) -> CurrencyPreferences {
        guard let value = try? JSONDecoder().decode(Self.self, from: Data(stored.utf8)), value.isValid else {
            return defaults
        }
        return value
    }

    var storageValue: String {
        guard isValid, let data = try? JSONEncoder().encode(self), let value = String(data: data, encoding: .utf8) else {
            return Self.defaultStorageValue
        }
        return value
    }

    static func load(from defaults: UserDefaults = .standard) -> CurrencyPreferences {
        decode(defaults.string(forKey: storageKey) ?? defaultStorageValue)
    }

    func settingEnabled(_ code: String, to enabled: Bool) -> CurrencyPreferences {
        guard Self.isCurrencyCode(code) else { return self }
        var updated = self
        if enabled {
            if !updated.enabledCodes.contains(code) { updated.enabledCodes.append(code) }
        } else {
            guard updated.enabledCodes.count > 1 else { return self }
            updated.enabledCodes.removeAll { $0 == code }
            if updated.defaultCode == code { updated.defaultCode = updated.enabledCodes[0] }
        }
        return updated.isValid ? updated : self
    }

    func choosingDefault(_ code: String) -> CurrencyPreferences {
        guard enabledCodes.contains(code) else { return self }
        var updated = self
        updated.defaultCode = code
        return updated
    }

    // Existing currencies remain usable for budget edits and new budgets even
    // if hidden from new-wallet choices. No amounts or currencies are converted.
    func budgetCodes(existingCodes: [String], selectedCode: String? = nil) -> [String] {
        let extra = existingCodes + (selectedCode.map { [$0] } ?? [])
        return enabledCodes + Set(extra.filter { !$0.isEmpty && !enabledCodes.contains($0) }).sorted()
    }
}
