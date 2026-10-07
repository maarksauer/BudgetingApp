import SwiftUI
import SwiftData

struct CreateTransferView: View {

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.modelContext)
    private var modelContext

    @Query(sort: \Wallet.createdAt)
    private var wallets: [Wallet]

    @Query
    private var transfers: [WalletTransfer]

    let initialSourceWallet: Wallet

    @State private var sourceWallet: Wallet?
    @State private var destinationWallet: Wallet?

    @State private var sourceAmount = ""
    @State private var destinationAmount = ""

    @State private var transferDate = Date()
    @State private var note = ""

    init(
        sourceWallet: Wallet
    ) {

        self.initialSourceWallet =
            sourceWallet

        _sourceWallet = State(
            initialValue:
                sourceWallet
        )
    }

    var body: some View {

        NavigationStack {

            Form {

                Section("From") {

                    Picker(
                        "Wallet",
                        selection:
                            $sourceWallet
                    ) {

                        ForEach(
                            wallets
                        ) { wallet in

                            Text(
                                "\(wallet.name) • \(wallet.currencyCode)"
                            )
                            .tag(
                                wallet as Wallet?
                            )
                        }
                    }

                    if let sourceWallet {

                        HStack {

                            Text(
                                "Current Balance"
                            )

                            Spacer()

                            Text(
                                "\(balance(for: sourceWallet).formatted(.number)) \(sourceWallet.currencyCode)"
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }

                        if sourceWallet
                            .allowsNegativeBalance {

                            HStack {

                                Text(
                                    sourceWallet.walletType ==
                                    "Credit Card"
                                    ? "Credit Limit"
                                    : "Negative Limit"
                                )

                                Spacer()

                                Text(
                                    "\(sourceWallet.negativeBalanceLimit.formatted(.number)) \(sourceWallet.currencyCode)"
                                )
                                .foregroundStyle(
                                    .secondary
                                )
                            }
                        }

                        HStack {

                            Text(
                                "Available to Transfer"
                            )

                            Spacer()

                            Text(
                                "\(availableAmount(for: sourceWallet).formatted(.number)) \(sourceWallet.currencyCode)"
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }

                        TextField(
                            "Amount sent",
                            text:
                                $sourceAmount
                        )
                        .keyboardType(
                            .decimalPad
                        )
                    }
                }

                Section("To") {

                    Picker(
                        "Wallet",
                        selection:
                            $destinationWallet
                    ) {

                        Text(
                            "Select Wallet"
                        )
                        .tag(
                            nil as Wallet?
                        )

                        ForEach(
                            availableDestinationWallets
                        ) { wallet in

                            Text(
                                "\(wallet.name) • \(wallet.currencyCode)"
                            )
                            .tag(
                                wallet as Wallet?
                            )
                        }
                    }

                    if let destinationWallet {

                        HStack {

                            Text(
                                "Current Balance"
                            )

                            Spacer()

                            Text(
                                "\(balance(for: destinationWallet).formatted(.number)) \(destinationWallet.currencyCode)"
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }

                        if usesDifferentCurrencies {

                            TextField(
                                "Amount received",
                                text:
                                    $destinationAmount
                            )
                            .keyboardType(
                                .decimalPad
                            )

                            Text(
                                "Enter the exact amount received in the destination wallet."
                            )
                            .font(.caption)
                            .foregroundStyle(
                                .secondary
                            )

                        } else {

                            HStack {

                                Text(
                                    "Amount Received"
                                )

                                Spacer()

                                if let amount =
                                    parsedSourceAmount {

                                    Text(
                                        "\(amount.formatted(.number)) \(destinationWallet.currencyCode)"
                                    )
                                    .foregroundStyle(
                                        .secondary
                                    )

                                } else {

                                    Text(
                                        destinationWallet.currencyCode
                                    )
                                    .foregroundStyle(
                                        .secondary
                                    )
                                }
                            }
                        }
                    }
                }

                Section("Details") {

                    DatePicker(
                        "Date",
                        selection:
                            $transferDate,
                        in: ...Date(),
                        displayedComponents:
                            .date
                    )

                    TextField(
                        "Note",
                        text: $note
                    )
                }

                if exceedsAvailableBalance {

                    Section {

                        Text(
                            "This transfer would exceed the wallet's allowed balance."
                        )
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                }

                Section {

                    Button {

                        createTransfer()

                    } label: {

                        Text(
                            "Transfer Money"
                        )
                        .frame(
                            maxWidth:
                                .infinity
                        )
                    }
                    .disabled(
                        !canCreateTransfer
                    )
                }
            }

            .navigationTitle(
                "New Transfer"
            )

            .navigationBarTitleDisplayMode(
                .inline
            )

            .toolbar {

                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {

                    Button(
                        "Cancel"
                    ) {

                        dismiss()
                    }
                }
            }

            .onChange(
                of: sourceWallet
            ) {

                if
                    sourceWallet?
                        .persistentModelID
                    ==
                    destinationWallet?
                        .persistentModelID {

                    destinationWallet =
                        nil
                }

                sourceAmount = ""
                destinationAmount = ""
            }

            .onChange(
                of: destinationWallet
            ) {

                destinationAmount = ""
            }
        }
    }

    private var availableDestinationWallets:
        [Wallet] {

        guard
            let sourceWallet
        else {
            return wallets
        }

        return wallets.filter {

            $0.persistentModelID
            !=
            sourceWallet.persistentModelID
        }
    }

    private var usesDifferentCurrencies:
        Bool {

        guard
            let sourceWallet,
            let destinationWallet
        else {
            return false
        }

        return
            sourceWallet.currencyCode
            !=
            destinationWallet.currencyCode
    }

    private var parsedSourceAmount:
        Decimal? {

        parseAmount(
            sourceAmount
        )
    }

    private var parsedDestinationAmount:
        Decimal? {

        parseAmount(
            destinationAmount
        )
    }

    private var exceedsAvailableBalance:
        Bool {

        guard
            let sourceWallet,
            let amount =
                parsedSourceAmount
        else {
            return false
        }

        return
            amount >
            availableAmount(
                for: sourceWallet
            )
    }

    private var canCreateTransfer:
        Bool {

        guard
            sourceWallet != nil,
            destinationWallet != nil,
            parsedSourceAmount != nil,
            !exceedsAvailableBalance
        else {
            return false
        }

        if usesDifferentCurrencies {

            return
                parsedDestinationAmount != nil
        }

        return true
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
                    string:
                        cleaned
                ),
            amount > 0
        else {
            return nil
        }

        return amount
    }

    private func balance(
        for wallet: Wallet
    ) -> Decimal {
        wallet.balance(including: transfers)
    }

    private func availableAmount(
        for wallet: Wallet
    ) -> Decimal {

        let current =
            balance(
                for: wallet
            )

        let available =
            current
            -
            wallet.minimumAllowedBalance

        return max(
            available,
            0
        )
    }

    private func createTransfer() {

        guard
            let sourceWallet,
            let destinationWallet,
            let source =
                parsedSourceAmount,
            source <=
                availableAmount(
                    for: sourceWallet
                )
        else {
            return
        }

        let destination:
            Decimal

        if usesDifferentCurrencies {

            guard
                let received =
                    parsedDestinationAmount
            else {
                return
            }

            destination =
                received

        } else {

            destination =
                source
        }

        let transfer =
            WalletTransfer(
                sourceAmount:
                    source,
                destinationAmount:
                    destination,
                date:
                    transferDate,
                note:
                    note.trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    ),
                sourceWallet:
                    sourceWallet,
                destinationWallet:
                    destinationWallet
            )

        modelContext.insert(
            transfer
        )

        dismiss()
    }
}
