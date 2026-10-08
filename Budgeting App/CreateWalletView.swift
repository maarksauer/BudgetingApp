import SwiftUI
import SwiftData

struct CreateWalletView: View {
    @AppStorage(CurrencyPreferences.storageKey) private var storedCurrencyPreferences = CurrencyPreferences.defaultStorageValue
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var draft = WalletFormDraft()
    @FocusState private var focusedField: WalletFormField?
    @State private var isSaving = false
    @State private var showingSaveError = false
    @State private var saveError = ""

    private var currencies: [String] {
        let preferences = CurrencyPreferences.decode(storedCurrencyPreferences)
        return preferences.enabledCodes
    }

    var body: some View {
        NavigationStack {
            Form {
                WalletFormFields(draft: $draft, currencyCodes: currencies,
                                 canChooseCurrency: true, focusedField: $focusedField)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("New Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { focusedField = nil; dismiss() }
                        .disabled(isSaving)
                        .accessibilityIdentifier("cancelWalletForm")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: save)
                        .disabled(!draft.canSave || isSaving)
                        .accessibilityIdentifier("createWallet")
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
            .onAppear(perform: ensureAvailableCurrency)
            .onChange(of: storedCurrencyPreferences) { ensureAvailableCurrency() }
            .alert("Couldn’t create wallet", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your entries are still here. \(saveError)")
            }
        }
    }

    private func ensureAvailableCurrency() {
        let preferences = CurrencyPreferences.decode(storedCurrencyPreferences)
        let available = preferences.enabledCodes
        if !available.contains(draft.currencyCode) { draft.currencyCode = preferences.defaultCode }
    }

    private func save() {
        guard draft.canSave, !isSaving else { return }
        focusedField = nil
        isSaving = true
        do {
            try FormStore.createWallet(draft, context: modelContext)
            dismiss()
        } catch {
            isSaving = false
            saveError = error.localizedDescription
            showingSaveError = true
        }
    }
}
