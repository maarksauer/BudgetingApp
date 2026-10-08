import SwiftUI
import SwiftData

struct TransactionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Wallet.createdAt) private var wallets: [Wallet]
    @Query(sort: \SpendingCategory.createdAt) private var categories: [SpendingCategory]
    @Query private var transfers: [WalletTransfer]
    let transaction: ExpenseTransaction
    @State private var draft: ExpenseDraft
    @FocusState private var focusedField: TransactionFormField?
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var showingDeleteConfirmation = false
    @State private var showingRevertConfirmation = false
    @State private var showingSaveError = false
    @State private var saveError = ""

    init(transaction: ExpenseTransaction) {
        self.transaction = transaction
        _draft = State(initialValue: ExpenseDraft(transaction: transaction))
    }

    var body: some View {
        Form {
            if isEditing {
                TransactionFormFields(draft: $draft, wallets: wallets, categories: categories, transfers: transfers,
                                      editingTransaction: transaction, focusedField: $focusedField, prefix: "transactionEdit")
            } else {
                summary
                Section("Details") {
                    LabeledContent("Date", value: transaction.date.formatted(date: .long, time: .omitted))
                    LabeledContent("Wallet", value: transaction.wallet?.name ?? "None")
                    if !transaction.isIncome {
                        LabeledContent("Category", value: transaction.category?.name ?? "Uncategorized")
                        LabeledContent("Subcategory", value: transaction.subcategory?.name ?? "None")
                    }
                }
                Section(transaction.isIncome ? "Source or Note" : "Note") {
                    Text(transaction.note.isEmpty ? "No note" : transaction.note)
                        .foregroundStyle(transaction.note.isEmpty ? .secondary : .primary)
                }
                if let payment = transaction.recurringPayment, transaction.recurringScheduledDate != nil {
                    Section("Recurring Payment") {
                        LabeledContent("Payment", value: payment.name)
                        Button(role: .destructive) { showingRevertConfirmation = true } label: {
                            Label("Revert Recurring Payment", systemImage: "arrow.uturn.backward.circle")
                        }
                    }
                }
                Section {
                    Button("Delete Transaction", role: .destructive) { showingDeleteConfirmation = true }
                        .accessibilityIdentifier("deleteTransaction")
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(isEditing ? "Edit Transaction" : "Transaction")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isEditing {
                    Button("Save", action: save).buttonStyle(.borderedProminent)
                        .disabled(!draft.canSave(transfers: transfers, excluding: transaction) || isSaving)
                        .accessibilityIdentifier("saveTransactionEdit")
                } else {
                    Button("Edit") { draft = ExpenseDraft(transaction: transaction); isEditing = true }
                        .accessibilityIdentifier("editTransaction")
                }
            }
            if isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        focusedField = nil; draft = ExpenseDraft(transaction: transaction); isEditing = false
                    }
                    .disabled(isSaving).accessibilityIdentifier("cancelTransactionEdit")
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                if focusedField != nil {
                    Spacer()
                    Button("Done") { focusedField = nil }.accessibilityIdentifier("transactionEditKeyboardDone")
                }
            }
        }
        .onDisappear { focusedField = nil }
        .confirmationDialog("Delete Transaction?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Transaction", role: .destructive) {
                perform { try FormStore.deleteTransaction(transaction, context: modelContext) }
            }
            Button("Cancel", role: .cancel) { }
        } message: { Text("This cannot be undone. The wallet balance will update automatically.") }
        .confirmationDialog("Revert Recurring Payment?", isPresented: $showingRevertConfirmation, titleVisibility: .visible) {
            Button("Revert Payment", role: .destructive) {
                perform { try FormStore.revertRecurringTransaction(transaction, context: modelContext) }
            }
            Button("Cancel", role: .cancel) { }
        } message: { Text("This removes the expense and restores the recurring payment’s previous schedule and postponement.") }
        .alert("Couldn’t save changes", isPresented: $showingSaveError) {
            Button("OK", role: .cancel) { }
        } message: { Text(isEditing ? "Your entries are still here. \(saveError)" : "Please try again. \(saveError)") }
    }

    private var summary: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label(transaction.typeName, systemImage: transaction.isIncome ? "arrow.down.left.circle.fill" : (transaction.category?.icon ?? "arrow.up.right.circle.fill"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(transaction.isIncome ? .green : FormPalette.color(transaction.category?.colorName ?? "orange"))
                Text("\(transaction.amountSign)\(transaction.amount.formatted(.number)) \(transaction.wallet?.currencyCode ?? "")")
                    .font(.largeTitle.weight(.semibold)).monospacedDigit()
            }
            .padding(.vertical, 8)
        }
    }

    private func save() {
        guard draft.canSave(transfers: transfers, excluding: transaction), !isSaving else { return }
        focusedField = nil; isSaving = true
        defer { isSaving = false }
        do {
            try FormStore.updateTransaction(transaction, draft: draft, context: modelContext)
            isEditing = false
        } catch { saveError = error.localizedDescription; showingSaveError = true }
    }

    private func perform(_ action: () throws -> Void) {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do { try action(); dismiss() }
        catch { saveError = error.localizedDescription; showingSaveError = true }
    }
}
