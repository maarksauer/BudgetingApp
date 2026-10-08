import SwiftUI
import SwiftData

struct CreateBudgetView: View {
    @AppStorage(CurrencyPreferences.storageKey) private var storedCurrencyPreferences = CurrencyPreferences.defaultStorageValue
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var wallets: [Wallet]
    @Query private var budgets: [Budget]
    @State private var draft = BudgetFormDraft()
    @FocusState private var focusedField: BudgetFormField?
    @State private var isSaving = false
    @State private var showingSaveError = false
    @State private var saveError = ""

    private var currencies: [String] {
        let preferences = CurrencyPreferences.decode(storedCurrencyPreferences)
        return preferences.budgetCodes(existingCodes: wallets.map(\.currencyCode) + budgets.map(\.currencyCode),
                                       selectedCode: draft.currencyCode)
    }

    var body: some View {
        NavigationStack {
            Form {
                BudgetFormFields(draft: $draft, currencyCodes: currencies,
                                 isPartOfRecurringSeries: false, focusedField: $focusedField)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("New Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { focusedField = nil; dismiss() }
                        .disabled(isSaving)
                        .accessibilityIdentifier("cancelBudgetForm")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: save)
                        .disabled(!draft.canSave || isSaving)
                        .accessibilityIdentifier("createBudget")
                }
                #if os(iOS) || os(visionOS)
                ToolbarItemGroup(placement: .keyboard) {
                    if focusedField != nil {
                        Spacer()
                        Button("Done") { focusedField = nil }
                            .accessibilityIdentifier("budgetFormKeyboardDone")
                    }
                }
                #endif
            }
            .onDisappear { focusedField = nil }
            .onAppear(perform: ensureAvailableCurrency)
            .onChange(of: storedCurrencyPreferences) { ensureAvailableCurrency() }
            .alert("Couldn’t create budget", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your entries are still here. \(saveError)")
            }
        }
    }

    private func ensureAvailableCurrency() {
        let preferences = CurrencyPreferences.decode(storedCurrencyPreferences)
        let available = preferences.budgetCodes(existingCodes: wallets.map(\.currencyCode) + budgets.map(\.currencyCode))
        if !available.contains(draft.currencyCode) { draft.currencyCode = preferences.defaultCode }
    }

    private func save() {
        guard draft.canSave, !isSaving else { return }
        focusedField = nil
        isSaving = true
        do {
            try FormStore.createBudget(draft, context: modelContext)
            dismiss()
        } catch {
            isSaving = false
            saveError = error.localizedDescription
            showingSaveError = true
        }
    }
}
