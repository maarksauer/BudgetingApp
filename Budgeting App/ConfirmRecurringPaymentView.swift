import SwiftUI
import SwiftData

struct ConfirmRecurringPaymentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var transfers: [WalletTransfer]
    let payment: RecurringPayment
    @State private var draft: ExpenseDraft
    @FocusState private var focusedField: TransactionFormField?
    @State private var isSaving = false
    @State private var showingSaveError = false
    @State private var saveError = ""

    init(payment: RecurringPayment) {
        self.payment = payment
        var initial = ExpenseDraft()
        initial.amount = NSDecimalNumber(decimal: payment.amount).stringValue
        initial.selectedWallet = payment.wallet
        initial.selectedCategory = payment.category
        initial.selectedSubcategoryID = payment.subcategory?.persistentModelID
        _draft = State(initialValue: initial)
    }

    private var canConfirm: Bool { payment.isActive && RecurringSchedule.frequencies.contains(payment.frequency) && draft.canSave(transfers: transfers) }

    var body: some View {
        NavigationStack {
            Form {
                TransactionAmountSection(title: "Actual payment", symbol: "checkmark.circle.fill", tint: .green,
                                         amount: $draft.amount, currencyCode: payment.wallet?.currencyCode ?? "",
                                         focusedField: $focusedField, identifier: "confirmPaymentAmount")
                Section("Payment") {
                    LabeledContent("Recurring Payment", value: payment.name)
                    LabeledContent("Expected Amount", value: payment.amount.formatted(.number) + " " + (payment.wallet?.currencyCode ?? ""))
                    DatePicker("Payment Date", selection: $draft.transactionDate, in: ...Date(), displayedComponents: .date)
                    LabeledContent("Wallet", value: payment.wallet?.name ?? "Missing wallet")
                    LabeledContent("Category", value: payment.category?.name ?? "Missing category")
                    if let subcategory = payment.subcategory { LabeledContent("Subcategory", value: subcategory.name) }
                    if payment.wallet == nil || payment.category == nil {
                        FormValidationMessage(text: "Edit the recurring payment to choose a wallet and category first.")
                    }
                }
                if let wallet = payment.wallet {
                    Section("Balance") {
                        LabeledContent("Current Balance", value: wallet.balance(including: transfers).formatted(.currency(code: wallet.currencyCode)))
                        LabeledContent(wallet.walletType == "Credit Card" ? "Available Credit" : "Available to Spend",
                                       value: draft.availableAmount(transfers: transfers).formatted(.currency(code: wallet.currencyCode)))
                        if let total = draft.total, total > draft.availableAmount(transfers: transfers) {
                            FormValidationMessage(text: "This payment exceeds the wallet’s available balance or credit limit.")
                        }
                    }
                }
                Section {
                    Label("Confirming records one expense and advances the original schedule. Postponing does not change the repeat dates.", systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Confirm Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { focusedField = nil; dismiss() }.disabled(isSaving)
                        .accessibilityIdentifier("cancelConfirmPayment")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm", action: save).buttonStyle(.borderedProminent)
                        .disabled(!canConfirm || isSaving).accessibilityIdentifier("confirmRecurringPayment")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    if focusedField != nil {
                        Spacer()
                        Button("Done") { focusedField = nil }.accessibilityIdentifier("confirmPaymentKeyboardDone")
                    }
                }
            }
            .onDisappear { focusedField = nil }
            .alert("Couldn’t confirm payment", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: { Text("Your entries are still here. \(saveError)") }
        }
    }

    private func save() {
        guard canConfirm, !isSaving else { return }
        focusedField = nil; isSaving = true
        do {
            try FormStore.confirmRecurringPayment(payment, amount: draft.amount, date: draft.transactionDate, context: modelContext)
            dismiss()
        } catch {
            isSaving = false; saveError = error.localizedDescription; showingSaveError = true
        }
    }
}
