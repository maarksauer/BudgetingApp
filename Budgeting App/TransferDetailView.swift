import SwiftUI
import SwiftData

struct TransferDetailView: View {

    @Environment(\.modelContext)
    private var modelContext

    @Environment(\.dismiss)
    private var dismiss

    @Query
    private var transfers: [WalletTransfer]

    let transfer: WalletTransfer

    @State private var isEditing = false
    @State private var showingDeleteConfirmation = false

    @State private var sourceAmount: String
    @State private var destinationAmount: String
    @State private var date: Date
    @State private var note: String

    init(
        transfer: WalletTransfer
    ) {

        self.transfer = transfer

        _sourceAmount = State(
            initialValue:
                NSDecimalNumber(
                    decimal:
                        transfer.sourceAmount
                )
                .stringValue
        )

        _destinationAmount = State(
            initialValue:
                NSDecimalNumber(
                    decimal:
                        transfer.destinationAmount
                )
                .stringValue
        )

        _date = State(
            initialValue:
                transfer.date
        )

        _note = State(
            initialValue:
                transfer.note
        )
    }

    var body: some View {

        Form {

            Section("Transfer") {

                HStack {

                    VStack(
                        alignment: .leading,
                        spacing: 4
                    ) {

                        Text(
                            transfer.sourceWallet?.name
                            ?? "Unknown Wallet"
                        )
                        .fontWeight(.medium)

                        Text(
                            transfer.sourceCurrencyCode
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(
                        systemName: "arrow.right"
                    )
                    .foregroundStyle(.secondary)

                    Spacer()

                    VStack(
                        alignment: .trailing,
                        spacing: 4
                    ) {

                        Text(
                            transfer.destinationWallet?.name
                            ?? "Unknown Wallet"
                        )
                        .fontWeight(.medium)

                        Text(
                            transfer.destinationCurrencyCode
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }

            Section("Amounts") {

                if isEditing {

                    TextField(
                        "Amount sent",
                        text: $sourceAmount
                    )
                    .keyboardType(.decimalPad)

                    if differentCurrencies {

                        TextField(
                            "Amount received",
                            text: $destinationAmount
                        )
                        .keyboardType(.decimalPad)

                    } else {

                        HStack {

                            Text("Amount received")

                            Spacer()

                            if let parsedSourceAmount {

                                Text(
                                    "\(parsedSourceAmount.formatted(.number)) \(transfer.destinationCurrencyCode)"
                                )
                                .foregroundStyle(.secondary)

                            } else {

                                Text(
                                    transfer.destinationCurrencyCode
                                )
                                .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !sourceAmount.isEmpty &&
                        parsedSourceAmount == nil {

                        Text(
                            "Enter a valid amount sent."
                        )
                        .font(.caption)
                        .foregroundStyle(.red)
                    }

                    if differentCurrencies &&
                        !destinationAmount.isEmpty &&
                        parsedDestinationAmount == nil {

                        Text(
                            "Enter a valid amount received."
                        )
                        .font(.caption)
                        .foregroundStyle(.red)
                    }

                    if exceedsAvailableBalance {

                        Text(
                            "This transfer would exceed the source wallet's allowed balance."
                        )
                        .font(.caption)
                        .foregroundStyle(.red)
                    }

                } else {

                    HStack {

                        Text("Sent")

                        Spacer()

                        Text(
                            "\(transfer.sourceAmount.formatted(.number)) \(transfer.sourceCurrencyCode)"
                        )
                        .fontWeight(.semibold)
                    }

                    HStack {

                        Text("Received")

                        Spacer()

                        Text(
                            "\(transfer.destinationAmount.formatted(.number)) \(transfer.destinationCurrencyCode)"
                        )
                        .fontWeight(.semibold)
                    }

                    if differentCurrencies {

                        HStack {

                            Text("Conversion")

                            Spacer()

                            Text(
                                "\(transfer.sourceCurrencyCode) → \(transfer.destinationCurrencyCode)"
                            )
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Details") {

                if isEditing {

                    DatePicker(
                        "Date",
                        selection: $date,
                        in: ...Date(),
                        displayedComponents: .date
                    )

                    TextField(
                        "Note",
                        text: $note
                    )

                } else {

                    HStack {

                        Text("Date")

                        Spacer()

                        Text(
                            transfer.date.formatted(
                                date: .long,
                                time: .omitted
                            )
                        )
                        .foregroundStyle(.secondary)
                    }

                    HStack(
                        alignment: .top
                    ) {

                        Text("Note")

                        Spacer()

                        Text(
                            transfer.note.isEmpty
                            ? "None"
                            : transfer.note
                        )
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                    }
                }
            }

            if !isEditing {

                Section {

                    Button(
                        "Delete Transfer",
                        role: .destructive
                    ) {

                        showingDeleteConfirmation = true
                    }
                }
            }
        }

        .navigationTitle(
            isEditing
            ? "Edit Transfer"
            : "Transfer"
        )

        .navigationBarTitleDisplayMode(
            .inline
        )

        .toolbar {

            ToolbarItem(
                placement: .primaryAction
            ) {

                if isEditing {

                    Button("Save") {

                        saveChanges()
                    }
                    .disabled(!canSave)

                } else {

                    Button("Edit") {

                        isEditing = true
                    }
                }
            }

            if isEditing {

                ToolbarItem(
                    placement: .cancellationAction
                ) {

                    Button("Cancel") {

                        resetForm()
                        isEditing = false
                    }
                }
            }
        }

        .confirmationDialog(
            "Delete Transfer?",
            isPresented:
                $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {

            Button(
                "Delete Transfer",
                role: .destructive
            ) {

                deleteTransfer()
            }

            Button(
                "Cancel",
                role: .cancel
            ) { }

        } message: {

            Text(
                "Deleting this transfer will restore the corresponding balances in both wallets."
            )
        }
    }

    private var differentCurrencies: Bool {

        transfer.sourceCurrencyCode
        !=
        transfer.destinationCurrencyCode
    }

    private var parsedSourceAmount: Decimal? {

        parseAmount(
            sourceAmount
        )
    }

    private var parsedDestinationAmount: Decimal? {

        parseAmount(
            destinationAmount
        )
    }

    private func parseAmount(
        _ value: String
    ) -> Decimal? {

        let cleaned =
            value
                .replacingOccurrences(
                    of: " ",
                    with: ""
                )
                .replacingOccurrences(
                    of: ",",
                    with: "."
                )

        guard
            let amount =
                Decimal(
                    string: cleaned
                ),
            amount > 0
        else {
            return nil
        }

        return amount
    }

    private var canSave: Bool {

        guard
            parsedSourceAmount != nil,
            !exceedsAvailableBalance
        else {
            return false
        }

        if differentCurrencies {

            return
                parsedDestinationAmount != nil
        }

        return true
    }

    private var exceedsAvailableBalance: Bool {

        guard
            let sourceWallet =
                transfer.sourceWallet,
            let newAmount =
                parsedSourceAmount
        else {
            return false
        }

        return
            newAmount >
            availableAmountForEditing(
                wallet:
                    sourceWallet
            )
    }

    private func balance(
        for wallet: Wallet
    ) -> Decimal {
        wallet.balance(including: transfers)
    }

    private func availableAmountForEditing(
        wallet: Wallet
    ) -> Decimal {

        var current =
            balance(
                for: wallet
            )

        if transfer.sourceWallet?
            .persistentModelID
            ==
            wallet.persistentModelID {

            current +=
                transfer.sourceAmount
        }

        let available =
            current
            -
            wallet.minimumAllowedBalance

        return max(
            available,
            0
        )
    }

    private func saveChanges() {

        guard
            let newSourceAmount =
                parsedSourceAmount,
            !exceedsAvailableBalance
        else {
            return
        }

        let newDestinationAmount:
            Decimal

        if differentCurrencies {

            guard
                let received =
                    parsedDestinationAmount
            else {
                return
            }

            newDestinationAmount =
                received

        } else {

            newDestinationAmount =
                newSourceAmount
        }

        transfer.sourceAmount =
            newSourceAmount

        transfer.destinationAmount =
            newDestinationAmount

        transfer.date =
            date

        transfer.note =
            note.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        isEditing =
            false
    }

    private func deleteTransfer() {

        modelContext.delete(
            transfer
        )

        dismiss()
    }

    private func resetForm() {

        sourceAmount =
            NSDecimalNumber(
                decimal:
                    transfer.sourceAmount
            )
            .stringValue

        destinationAmount =
            NSDecimalNumber(
                decimal:
                    transfer.destinationAmount
            )
            .stringValue

        date =
            transfer.date

        note =
            transfer.note
    }
}
