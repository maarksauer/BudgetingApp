import SwiftUI
import SwiftData

struct EditWalletView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let wallet: Wallet
    @State private var draft: WalletFormDraft
    @FocusState private var focusedField: WalletFormField?
    @State private var isSaving = false
    @State private var showingSaveError = false
    @State private var saveError = ""

    init(wallet: Wallet) {
        self.wallet = wallet
        _draft = State(initialValue: WalletFormDraft(wallet: wallet))
    }

    var body: some View {
        NavigationStack {
            Form {
                WalletFormFields(draft: $draft, currencyCodes: [],
                                 canChooseCurrency: false, focusedField: $focusedField)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { focusedField = nil; dismiss() }
                        .disabled(isSaving)
                        .accessibilityIdentifier("cancelWalletForm")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!draft.canSave || isSaving)
                        .accessibilityIdentifier("saveWallet")
                }
                #if os(iOS) || os(visionOS)
                ToolbarItemGroup(placement: .keyboard) {
                    if focusedField != nil {
                        Spacer()
                        Button("Done") { focusedField = nil }
                            .accessibilityIdentifier("walletFormKeyboardDone")
                    }
                }
                #endif
            }
            .onDisappear { focusedField = nil }
            .onChange(of: draft.walletType) {
                if draft.walletType == "Credit Card" {
                    draft.allowsNegativeBalance = true
                    draft.icon = "creditcard.fill"
                }
            }
            .alert("Couldn’t save wallet", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your entries are still here. \(saveError)")
            }
        }
    }

    private func save() {
        guard draft.canSave, !isSaving else { return }
        focusedField = nil
        isSaving = true
        do {
            try FormStore.updateWallet(wallet, draft: draft, context: modelContext)
            dismiss()
        } catch {
            isSaving = false
            saveError = error.localizedDescription
            showingSaveError = true
        }
    }
}
