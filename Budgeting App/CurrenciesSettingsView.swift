import SwiftUI
import SwiftData

struct CurrenciesSettingsView: View {
    @AppStorage(CurrencyPreferences.storageKey) private var storedPreferences = CurrencyPreferences.defaultStorageValue
    @Query private var wallets: [Wallet]
    @Query private var budgets: [Budget]
    @State private var searchText = ""

    private var preferences: CurrencyPreferences { CurrencyPreferences.decode(storedPreferences) }
    private var enabledResults: [String] { preferences.enabledCodes.filter(matchesSearch) }
    private var availableResults: [String] {
        CurrencyPreferences.availableCodes.filter { !preferences.enabledCodes.contains($0) && matchesSearch($0) }
    }

    var body: some View {
        List {
            Section {
                Picker("Default Currency", selection: Binding(
                    get: { preferences.defaultCode },
                    set: { storedPreferences = preferences.choosingDefault($0).storageValue }
                )) {
                    ForEach(preferences.enabledCodes, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
                .accessibilityIdentifier("defaultCurrencyPicker")
            } footer: {
                Text("New wallets and budgets start with this currency. Amounts in different currencies stay separate.")
            }
            if !enabledResults.isEmpty {
                Section {
                    ForEach(enabledResults, id: \.self) { code in currencyRow(code) }
                } header: {
                    Text("Enabled Currencies")
                } footer: {
                    Text("At least one currency must stay enabled. Hiding a currency keeps existing wallets, transactions and budgets unchanged. Their currency remains available for budgets.")
                }
            }
            if !availableResults.isEmpty {
                Section("Available Currencies") {
                    ForEach(availableResults, id: \.self) { code in currencyRow(code) }
                }
            }
            if enabledResults.isEmpty && availableResults.isEmpty {
                Text("No currencies match your search.").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Currencies")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Currency code or name")
    }

    private func currencyRow(_ code: String) -> some View {
        Toggle(isOn: Binding(
            get: { preferences.enabledCodes.contains(code) },
            set: { storedPreferences = preferences.settingEnabled(code, to: $0).storageValue }
        )) {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(code).font(.headline)
                    if code == preferences.defaultCode {
                        Text("Default").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text(CurrencyPreferences.name(for: code)).font(.subheadline).foregroundStyle(.secondary)
                if wallets.contains(where: { $0.currencyCode == code }) || budgets.contains(where: { $0.currencyCode == code }) {
                    Text("Used in existing records").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .disabled(preferences.enabledCodes.count == 1 && preferences.enabledCodes.contains(code))
        .accessibilityIdentifier("currencyEnabled-\(code)")
    }

    private func matchesSearch(_ code: String) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty || code.localizedStandardContains(query) ||
            CurrencyPreferences.name(for: code).localizedStandardContains(query)
    }
}
