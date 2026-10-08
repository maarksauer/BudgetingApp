import SwiftUI
import SwiftData

struct CreateRecurringPaymentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Wallet.createdAt) private var wallets: [Wallet]
    @Query(sort: \SpendingCategory.createdAt) private var categories: [SpendingCategory]
    @State private var draft = RecurringPaymentFormDraft()
    @FocusState private var focusedField: TransactionFormField?
    @State private var isSaving = false
    @State private var showingSaveError = false
    @State private var saveError = ""

    var body: some View {
        NavigationStack {
            Form {
                RecurringPaymentFormFields(draft: $draft, wallets: wallets, categories: categories,
                                           isEditing: false, focusedField: $focusedField)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("New Recurring Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { focusedField = nil; dismiss() }
                        .disabled(isSaving).accessibilityIdentifier("cancelRecurringForm")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: save).buttonStyle(.borderedProminent)
                        .disabled(!draft.canSave || isSaving).accessibilityIdentifier("createRecurringPayment")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    if focusedField != nil {
                        Spacer()
                        Button("Done") { focusedField = nil }.accessibilityIdentifier("recurringFormKeyboardDone")
                    }
                }
            }
            .onAppear {
                if draft.details.selectedWallet == nil { draft.details.selectedWallet = wallets.first }
                if draft.details.selectedCategory == nil { draft.details.selectedCategory = categories.first }
            }
            .onDisappear { focusedField = nil }
            .alert("Couldn’t create recurring payment", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: { Text("Your entries are still here. \(saveError)") }
        }
    }

    private func save() {
        guard draft.canSave, !isSaving else { return }
        focusedField = nil; isSaving = true
        do {
            try FormStore.createRecurringPayment(draft, context: modelContext)
            dismiss()
        } catch {
            isSaving = false; saveError = error.localizedDescription; showingSaveError = true
        }
    }
}
