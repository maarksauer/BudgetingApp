import SwiftUI
import SwiftData

struct TransferDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var transfers: [WalletTransfer]
    let transfer: WalletTransfer
    @State private var draft: TransferFormDraft
    @FocusState private var focusedField: TransferFormField?
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var showingDeleteConfirmation = false
    @State private var showingSaveError = false
    @State private var saveError = ""

    init(transfer: WalletTransfer) {
        self.transfer = transfer
        _draft = State(initialValue: TransferFormDraft(transfer: transfer))
    }

    var body: some View {
        Form {
            if isEditing {
                TransferFormFields(draft: $draft, wallets: [], transfers: transfers,
                                   editingTransfer: transfer, focusedField: $focusedField)
            } else {
                Section("From") {
                    Label(transfer.sourceWallet?.name ?? "Missing wallet", systemImage: transfer.sourceWallet?.icon ?? "wallet.bifold")
                        .font(.headline)
                    TransferAmountValue(title: "Sent", amount: transfer.sourceAmount, currency: transfer.sourceCurrencyCode, tint: .orange)
                }
                Section("To") {
                    Label(transfer.destinationWallet?.name ?? "Missing wallet", systemImage: transfer.destinationWallet?.icon ?? "wallet.bifold")
                        .font(.headline)
                    TransferAmountValue(title: "Received", amount: transfer.destinationAmount, currency: transfer.destinationCurrencyCode, tint: .green)
                }
                Section("Details") {
                    LabeledContent("Date", value: transfer.date.formatted(date: .long, time: .omitted))
                    Text(transfer.note.isEmpty ? "No note" : transfer.note)
                        .foregroundStyle(transfer.note.isEmpty ? .secondary : .primary)
                }
                Section {
                    Button("Delete Transfer", role: .destructive) { showingDeleteConfirmation = true }
                        .accessibilityIdentifier("deleteTransfer")
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(isEditing ? "Edit Transfer" : "Transfer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isEditing {
                    Button("Save", action: save).buttonStyle(.borderedProminent)
                        .disabled(!draft.canSave(transfers: transfers, editing: transfer) || isSaving)
                        .accessibilityIdentifier("saveTransferEdit")
                } else {
                    Button("Edit") { draft = TransferFormDraft(transfer: transfer); isEditing = true }
                        .accessibilityIdentifier("editTransfer")
                }
            }
            if isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { focusedField = nil; draft = TransferFormDraft(transfer: transfer); isEditing = false }
                        .disabled(isSaving).accessibilityIdentifier("cancelTransferForm")
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                if focusedField != nil {
                    if focusedField == .sent && draft.differentCurrencies {
                        Button("Next") { focusedField = .received }.accessibilityIdentifier("transferKeyboardNext")
                    }
                    Spacer()
                    Button("Done") { focusedField = nil }.accessibilityIdentifier("transferKeyboardDone")
                }
            }
        }
        .onDisappear { focusedField = nil }
        .confirmationDialog("Delete Transfer?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Transfer", role: .destructive, action: delete)
            Button("Cancel", role: .cancel) { }
        } message: { Text("Deleting this transfer restores the corresponding balances in both wallets.") }
        .alert("Couldn’t save changes", isPresented: $showingSaveError) {
            Button("OK", role: .cancel) { }
        } message: { Text(isEditing ? "Your entries are still here. \(saveError)" : "Please try again. \(saveError)") }
    }

    private func save() {
        guard draft.canSave(transfers: transfers, editing: transfer), !isSaving else { return }
        focusedField = nil; isSaving = true
        defer { isSaving = false }
        do {
            try FormStore.updateTransfer(transfer, draft: draft, context: modelContext)
            isEditing = false
        } catch { saveError = error.localizedDescription; showingSaveError = true }
    }

    private func delete() {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do { try FormStore.deleteTransfer(transfer, context: modelContext); dismiss() }
        catch { saveError = error.localizedDescription; showingSaveError = true }
    }
}
