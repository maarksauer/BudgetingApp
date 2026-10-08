import SwiftUI
import SwiftData

struct CreateTransferView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Wallet.createdAt) private var wallets: [Wallet]
    @Query private var transfers: [WalletTransfer]
    @State private var draft: TransferFormDraft
    @FocusState private var focusedField: TransferFormField?
    @State private var isSaving = false
    @State private var showingSaveError = false
    @State private var saveError = ""

    init(sourceWallet: Wallet) {
        _draft = State(initialValue: TransferFormDraft(sourceWallet: sourceWallet))
    }

    var body: some View {
        NavigationStack {
            Form {
                TransferFormFields(draft: $draft, wallets: wallets, transfers: transfers, focusedField: $focusedField)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("New Transfer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { focusedField = nil; dismiss() }
                        .disabled(isSaving).accessibilityIdentifier("cancelTransferForm")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Transfer", action: save).buttonStyle(.borderedProminent)
                        .disabled(!draft.canSave(transfers: transfers) || isSaving)
                        .accessibilityIdentifier("createTransfer")
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
            .onChange(of: draft.sourceWallet?.persistentModelID) {
                if draft.sourceWallet?.persistentModelID == draft.destinationWallet?.persistentModelID {
                    draft.destinationWallet = nil
                }
                // Wallet changes require fresh amounts to avoid reinterpreting a draft in another currency.
                draft.sourceAmount = ""; draft.destinationAmount = ""
            }
            .onChange(of: draft.destinationWallet?.persistentModelID) { draft.destinationAmount = "" }
            .onChange(of: wallets.map(\.persistentModelID)) {
                if !wallets.contains(where: { $0.persistentModelID == draft.sourceWallet?.persistentModelID }) { draft.sourceWallet = nil }
                if !wallets.contains(where: { $0.persistentModelID == draft.destinationWallet?.persistentModelID }) { draft.destinationWallet = nil }
            }
            .alert("Couldn’t create transfer", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: { Text("Your entries are still here. \(saveError)") }
        }
    }

    private func save() {
        guard draft.canSave(transfers: transfers), !isSaving else { return }
        focusedField = nil; isSaving = true
        do {
            try FormStore.createTransfer(draft, context: modelContext)
            dismiss()
        } catch {
            isSaving = false; saveError = error.localizedDescription; showingSaveError = true
        }
    }
}
