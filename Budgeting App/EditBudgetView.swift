import SwiftUI
import SwiftData

struct EditBudgetView: View {
    @AppStorage(CurrencyPreferences.storageKey) private var storedCurrencyPreferences = CurrencyPreferences.defaultStorageValue
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var wallets: [Wallet]
    @Query private var budgets: [Budget]
    let budget: Budget
    @State private var draft: BudgetFormDraft
    @FocusState private var focusedField: BudgetFormField?
    @State private var isSaving = false
    @State private var showingSaveError = false
    @State private var saveError = ""
    @State private var showingSaveOptions = false

    init(budget: Budget) {
        self.budget = budget
        _draft = State(initialValue: BudgetFormDraft(budget: budget))
    }

    private var currencies: [String] {
        let preferences = CurrencyPreferences.decode(storedCurrencyPreferences)
        return preferences.budgetCodes(existingCodes: wallets.map(\.currencyCode) + budgets.map(\.currencyCode),
                                       selectedCode: draft.currencyCode)
    }

    private var isPartOfRecurringSeries: Bool {
        budget.isRecurring || budgets.contains {
            $0.seriesID == budget.seriesID && $0.persistentModelID != budget.persistentModelID
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                BudgetFormFields(draft: $draft, currencyCodes: currencies,
                                 isPartOfRecurringSeries: isPartOfRecurringSeries, focusedField: $focusedField)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { focusedField = nil; dismiss() }
                        .disabled(isSaving)
                        .accessibilityIdentifier("cancelBudgetForm")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        focusedField = nil
                        if isPartOfRecurringSeries { showingSaveOptions = true }
                        else { save(includeFuture: false) }
                    }
                        .disabled(!draft.canSave || isSaving)
                        .accessibilityIdentifier("saveBudget")
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
            .confirmationDialog("Apply Changes", isPresented: $showingSaveOptions, titleVisibility: .visible) {
                Button("This Budget Only") { save(includeFuture: false) }
                Button("This & Future Budgets") { save(includeFuture: true) }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Choose whether to update this period or this and future periods in the recurring series. Period dates apply only to this budget.")
            }
            .alert("Couldn’t save budget", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your entries are still here. \(saveError)")
            }
        }
    }

    private func save(includeFuture: Bool) {
        guard draft.canSave, !isSaving else { return }
        focusedField = nil
        isSaving = true
        do {
            try FormStore.updateBudget(budget, draft: draft, includeFuture: includeFuture, context: modelContext)
            dismiss()
        } catch {
            isSaving = false
            saveError = error.localizedDescription
            showingSaveError = true
        }
    }
}
