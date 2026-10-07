import SwiftUI
import SwiftData

struct CurrenciesSettingsView: View {
    @AppStorage(CurrencyPreferences.storageKey) private var storedPreferences = CurrencyPreferences.defaultStorageValue
    @Query private var wallets: [Wallet]
    @Query private var budgets: [Budget]
    @State private var showingOtherCurrencies = false

    private var preferences: CurrencyPreferences { CurrencyPreferences.decode(storedPreferences) }

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
            Section {
                ForEach(preferences.listedCodes, id: \.self) { code in currencyRow(code) }
                Button { showingOtherCurrencies = true } label: {
                    HStack {
                        Label("Other Currencies", systemImage: "plus.circle")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .accessibilityIdentifier("otherCurrencies")
            } header: {
                Text("Added Currencies")
            } footer: {
                Text("Turn currencies on or off for new wallets. Switched-off currencies stay in this list. Existing wallets, transactions and budgets keep their currency. At least one currency must stay enabled.")
            }
        }
        .navigationTitle("Currencies")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingOtherCurrencies) {
            OtherCurrenciesView(preferences: preferences) { codes in
                storedPreferences = preferences.selectingCodes(codes).storageValue
            }
        }
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
}

private struct OtherCurrenciesView: View {
    @Environment(\.dismiss) private var dismiss
    let preferences: CurrencyPreferences
    let onSave: ([String]) -> Void
    @State private var selectedCodes: Set<String>
    @State private var searchText = ""

    init(preferences: CurrencyPreferences, onSave: @escaping ([String]) -> Void) {
        self.preferences = preferences
        self.onSave = onSave
        _selectedCodes = State(initialValue: Set(preferences.listedCodes))
    }

    private var results: [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return Set(CurrencyPreferences.availableCodes + preferences.listedCodes).sorted().filter { code in
            query.isEmpty || code.localizedStandardContains(query) ||
                CurrencyPreferences.name(for: code).localizedStandardContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(results, id: \.self) { code in
                        Button {
                            if selectedCodes.contains(code) { selectedCodes.remove(code) }
                            else { selectedCodes.insert(code) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(code).font(.headline).foregroundStyle(.primary)
                                    Text(CurrencyPreferences.name(for: code))
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: selectedCodes.contains(code) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedCodes.contains(code) ? Color.accentColor : Color.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("addCurrency-\(code)")
                        .accessibilityValue(selectedCodes.contains(code) ? "Selected" : "Not selected")
                        .accessibilityAddTraits(selectedCodes.contains(code) ? .isSelected : [])
                    }
                    if results.isEmpty {
                        Text("No currencies match your search.").foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Choose at least one currency. Tick currencies to show in Added Currencies. Untick to remove them from that list. New additions start enabled; existing records keep their currency.")
                }
            }
            .navigationTitle("Other Currencies")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Currency code or name")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let retained = preferences.listedCodes.filter { selectedCodes.contains($0) }
                        let additions = selectedCodes.subtracting(preferences.listedCodes).sorted()
                        onSave(retained + additions)
                        dismiss()
                    }
                    .disabled(selectedCodes.isEmpty)
                    .accessibilityIdentifier("saveAddedCurrencies")
                }
            }
        }
    }
}
