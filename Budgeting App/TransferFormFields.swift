import SwiftUI
import SwiftData

nonisolated enum TransferFormField: Hashable { case sent, received, note }

@MainActor
struct TransferFormDraft {
    var sourceWallet: Wallet?
    var destinationWallet: Wallet?
    var sourceAmount = ""
    var destinationAmount = ""
    var date = Date()
    var note = ""
    private var originalSourceCode: String?
    private var originalDestinationCode: String?

    var sourceCode: String { originalSourceCode ?? sourceWallet?.currencyCode ?? "" }
    var destinationCode: String { originalDestinationCode ?? destinationWallet?.currencyCode ?? "" }
    var differentCurrencies: Bool { !sourceCode.isEmpty && !destinationCode.isEmpty && sourceCode != destinationCode }
    var sent: Decimal? { AmountInput.positive(sourceAmount) }
    var received: Decimal? { differentCurrencies ? AmountInput.positive(destinationAmount) : sent }
    var cleanedNote: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }

    init(sourceWallet: Wallet? = nil) { self.sourceWallet = sourceWallet }
    init(transfer: WalletTransfer) {
        sourceWallet = transfer.sourceWallet
        destinationWallet = transfer.destinationWallet
        sourceAmount = NSDecimalNumber(decimal: transfer.sourceAmount).stringValue
        destinationAmount = NSDecimalNumber(decimal: transfer.destinationAmount).stringValue
        date = transfer.date
        note = transfer.note
        originalSourceCode = transfer.sourceCurrencyCode
        originalDestinationCode = transfer.destinationCurrencyCode
    }

    func balanceBeforeTransfer(_ wallet: Wallet, transfers: [WalletTransfer], editing: WalletTransfer? = nil) -> Decimal {
        var balance = wallet.balance(including: transfers)
        if let editing {
            if editing.sourceWallet?.persistentModelID == wallet.persistentModelID { balance += editing.sourceAmount }
            if editing.destinationWallet?.persistentModelID == wallet.persistentModelID { balance -= editing.destinationAmount }
        }
        return balance
    }

    func availableAmount(transfers: [WalletTransfer], editing: WalletTransfer? = nil) -> Decimal {
        guard let wallet = sourceWallet else { return 0 }
        return max(balanceBeforeTransfer(wallet, transfers: transfers, editing: editing) - wallet.minimumAllowedBalance, 0)
    }

    func exceedsLimit(transfers: [WalletTransfer], editing: WalletTransfer? = nil) -> Bool {
        guard sourceWallet != nil, let sent else { return false }
        return sent > availableAmount(transfers: transfers, editing: editing)
    }

    func canSave(transfers: [WalletTransfer], editing: WalletTransfer? = nil) -> Bool {
        guard sent != nil, received != nil, !sourceCode.isEmpty, !destinationCode.isEmpty,
              date.timeIntervalSinceReferenceDate.isFinite, !exceedsLimit(transfers: transfers, editing: editing)
        else { return false }
        if let editing {
            // Preserve the original wallets and currency snapshots, including missing relationships in old history.
            return sourceWallet?.persistentModelID == editing.sourceWallet?.persistentModelID &&
                   destinationWallet?.persistentModelID == editing.destinationWallet?.persistentModelID &&
                   sourceCode == editing.sourceCurrencyCode && destinationCode == editing.destinationCurrencyCode
        }
        guard let sourceWallet, let destinationWallet else { return false }
        return sourceWallet.persistentModelID != destinationWallet.persistentModelID
    }
}

struct TransferFormFields: View {
    @Binding var draft: TransferFormDraft
    let wallets: [Wallet]
    let transfers: [WalletTransfer]
    var editingTransfer: WalletTransfer? = nil
    var focusedField: FocusState<TransferFormField?>.Binding

    private var destinationWallets: [Wallet] {
        wallets.filter { $0.persistentModelID != draft.sourceWallet?.persistentModelID }
    }

    var body: some View {
        Section {
            if editingTransfer == nil {
                Picker(selection: $draft.sourceWallet) {
                    Text("Select Wallet").tag(nil as Wallet?)
                    ForEach(wallets) { wallet in
                        Label("\(wallet.name) • \(wallet.currencyCode)", systemImage: wallet.icon).tag(wallet as Wallet?)
                    }
                } label: { Label("From", systemImage: "arrow.up.right") }
                .pickerStyle(.menu).accessibilityIdentifier("transferSourceWallet")
            } else {
                LabeledContent("From", value: draft.sourceWallet?.name ?? "Missing wallet")
            }
            TransferAmountInput(title: "Amount sent", currency: draft.sourceCode, tint: .orange,
                                text: $draft.sourceAmount, field: .sent, advances: draft.differentCurrencies, focusedField: focusedField,
                                submit: { focusNext() }, identifier: "transferSentAmount")
        } header: {
            Text("From")
        } footer: { Text("Use a decimal point or comma, and spaces for thousands.") }

        Section {
            if editingTransfer == nil {
                Picker(selection: $draft.destinationWallet) {
                    Text("Select Wallet").tag(nil as Wallet?)
                    ForEach(destinationWallets) { wallet in
                        Label("\(wallet.name) • \(wallet.currencyCode)", systemImage: wallet.icon).tag(wallet as Wallet?)
                    }
                } label: { Label("To", systemImage: "arrow.down.left") }
                .pickerStyle(.menu).accessibilityIdentifier("transferDestinationWallet")
                if destinationWallets.isEmpty {
                    Label("Create another wallet to transfer money.", systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                LabeledContent("To", value: draft.destinationWallet?.name ?? "Missing wallet")
            }
            if draft.differentCurrencies {
                TransferAmountInput(title: "Amount received", currency: draft.destinationCode, tint: .green,
                                    text: $draft.destinationAmount, field: .received, advances: false, focusedField: focusedField,
                                    submit: { focusedField.wrappedValue = nil }, identifier: "transferReceivedAmount")
            } else {
                TransferAmountValue(title: "Amount received", amount: draft.sent, currency: draft.destinationCode, tint: .green)
                    .accessibilityIdentifier("transferReceivedPreview")
            }
        } header: {
            Text("To")
        } footer: {
            if draft.differentCurrencies {
                Text("Enter the exact amount received in \(draft.destinationCode).")
            } else if draft.destinationWallet != nil || editingTransfer != nil {
                Text("The received amount matches the sent amount for this currency.")
            }
        }

        Section("Details") {
            DatePicker("Date", selection: $draft.date, in: ...Date(), displayedComponents: .date)
            TextField("Note (optional)", text: $draft.note)
                .focused(focusedField, equals: .note).submitLabel(.done)
                .onSubmit { focusedField.wrappedValue = nil }
                .accessibilityIdentifier("transferNote")
        }

        balancePreview
    }

    private var balancePreview: some View {
        Section {
            if let source = draft.sourceWallet {
                let available = draft.availableAmount(transfers: transfers, editing: editingTransfer)
                LabeledContent("Available to Transfer", value: available.formatted(.currency(code: draft.sourceCode)))
                if draft.exceedsLimit(transfers: transfers, editing: editingTransfer) {
                    FormValidationMessage(text: "This transfer exceeds the available amount of \(available.formatted(.currency(code: draft.sourceCode))).")
                }
                if let sent = draft.sent {
                    let after = draft.balanceBeforeTransfer(source, transfers: transfers, editing: editingTransfer) - sent
                    LabeledContent("\(source.name) after transfer", value: after.formatted(.currency(code: draft.sourceCode)))
                }
            }
            if let destination = draft.destinationWallet, let received = draft.received {
                let after = draft.balanceBeforeTransfer(destination, transfers: transfers, editing: editingTransfer) + received
                LabeledContent("\(destination.name) after transfer", value: after.formatted(.currency(code: draft.destinationCode)))
            }
            if editingTransfer != nil && (draft.sourceWallet == nil || draft.destinationWallet == nil) {
                Text("A wallet from this transfer no longer exists. Its saved currency is retained in the history.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } header: {
            Text("Balance Preview")
        } footer: {
            if editingTransfer != nil {
                Text("The preview replaces the original transfer. Wallets and currencies stay fixed for this transfer.")
            } else {
                Text("Your wallets update only after the transfer is saved.")
            }
        }
    }

    private func focusNext() {
        focusedField.wrappedValue = draft.differentCurrencies ? .received : nil
    }
}

private struct TransferAmountInput: View {
    let title: String
    let currency: String
    let tint: Color
    @Binding var text: String
    let field: TransferFormField
    let advances: Bool
    var focusedField: FocusState<TransferFormField?>.Binding
    let submit: () -> Void
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: field == .sent ? "arrow.up.right.circle.fill" : "arrow.down.left.circle.fill")
                .font(.subheadline.weight(.semibold)).foregroundStyle(tint)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                TextField("0", text: $text)
                    .font(.largeTitle.weight(.semibold)).monospacedDigit().keyboardType(.decimalPad)
                    .focused(focusedField, equals: field).submitLabel(advances ? .next : .done).onSubmit(submit)
                    .accessibilityLabel(title).accessibilityIdentifier(identifier)
                if !currency.isEmpty { Text(currency).font(.headline).foregroundStyle(.secondary) }
            }
            if !text.isEmpty && AmountInput.positive(text) == nil {
                FormValidationMessage(text: "Enter a complete amount greater than zero.")
            }
        }
        .padding(.vertical, 8)
    }
}

struct TransferAmountValue: View {
    let title: String
    let amount: Decimal?
    let currency: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: title == "Sent" ? "arrow.up.right.circle.fill" : "arrow.down.left.circle.fill")
                .font(.subheadline.weight(.semibold)).foregroundStyle(tint)
            Text(amount.map { $0.formatted(.number) } ?? "—")
                .font(.largeTitle.weight(.semibold)).monospacedDigit()
            Text(currency).font(.headline).foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}
