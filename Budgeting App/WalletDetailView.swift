import SwiftUI
import SwiftData

struct WalletDetailView: View {

    let wallet: Wallet

    @Query
    private var transfers:
        [WalletTransfer]

    @State private var showingEditWallet =
        false

    @State private var showingTransfer =
        false

    private var recentTransactions:
        [ExpenseTransaction] {

        wallet.transactions
            .sorted {
                $0.date >
                $1.date
            }
    }

    private var currentBalance:
        Decimal {
        wallet.balance(including: transfers)
    }

    private var availableAmount:
        Decimal {

        let available =
            currentBalance
            -
            wallet.minimumAllowedBalance

        return max(
            available,
            0
        )
    }

    var body: some View {

        List {

            Section {

                VStack(
                    alignment:
                        .leading,
                    spacing: 10
                ) {

                    HStack {

                        Image(
                            systemName:
                                wallet.icon
                        )
                        .font(
                            .title2
                        )
                        .frame(
                            width: 46,
                            height: 46
                        )
                        .background(
                            colorFromName(
                                wallet.colorName
                            )
                            .opacity(
                                0.15
                            )
                        )
                        .foregroundStyle(
                            colorFromName(
                                wallet.colorName
                            )
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius:
                                    12
                            )
                        )

                        Spacer()

                        Text(
                            wallet.currencyCode
                        )
                        .font(
                            .subheadline
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    Text(
                        currentBalance,
                        format: .number
                    )
                    .font(
                        .largeTitle
                    )
                    .fontWeight(
                        .bold
                    )

                    Text(
                        wallet.currencyCode
                    )
                    .foregroundStyle(
                        .secondary
                    )

                    Text(
                        "Current Balance"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
                .padding(
                    .vertical,
                    8
                )
            }

            Section(
                "Wallet Details"
            ) {

                detailRow(
                    title:
                        "Starting Balance",
                    value:
                        "\(wallet.startingBalance.formatted(.number)) \(wallet.currencyCode)"
                )

                detailRow(
                    title:
                        "Wallet Type",
                    value:
                        wallet.walletType
                )

                detailRow(
                    title:
                        "Currency",
                    value:
                        wallet.currencyCode
                )

                if wallet
                    .allowsNegativeBalance {

                    detailRow(
                        title:
                            wallet.walletType ==
                            "Credit Card"
                            ? "Credit Limit"
                            : "Negative Limit",
                        value:
                            "\(wallet.negativeBalanceLimit.formatted(.number)) \(wallet.currencyCode)"
                    )

                    detailRow(
                        title:
                            wallet.walletType ==
                            "Credit Card"
                            ? "Available Credit"
                            : "Available to Spend",
                        value:
                            "\(availableAmount.formatted(.number)) \(wallet.currencyCode)"
                    )
                }
            }

            Section {

                Button {

                    showingTransfer =
                        true

                } label: {

                    Label(
                        "Transfer Money",
                        systemImage:
                            "arrow.left.arrow.right"
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )
                }
            }

            Section(
                "Recent Transactions"
            ) {

                if recentTransactions
                    .isEmpty {

                    Text(
                        "No transactions in this wallet yet."
                    )
                    .foregroundStyle(
                        .secondary
                    )

                } else {

                    ForEach(
                        recentTransactions
                    ) { transaction in

                        NavigationLink {

                            TransactionDetailView(
                                transaction:
                                    transaction
                            )

                        } label: {

                            transactionRow(
                                transaction
                            )
                        }
                    }
                }
            }
        }

        .navigationTitle(
            wallet.name
        )

        .navigationBarTitleDisplayMode(
            .inline
        )

        .toolbar {

            ToolbarItem(
                placement:
                    .primaryAction
            ) {

                Button(
                    "Edit"
                ) {

                    showingEditWallet =
                        true
                }
            }
        }

        .sheet(
            isPresented:
                $showingEditWallet
        ) {

            EditWalletView(
                wallet:
                    wallet
            )
        }

        .sheet(
            isPresented:
                $showingTransfer
        ) {

            CreateTransferView(
                sourceWallet:
                    wallet
            )
        }
    }

    private func transactionRow(
        _ transaction:
            ExpenseTransaction
    ) -> some View {

        HStack {

            VStack(
                alignment:
                    .leading,
                spacing: 4
            ) {

                Text(
                    transactionTitle(
                        transaction
                    )
                )
                .fontWeight(
                    .medium
                )

                Text(
                    transaction.date
                        .formatted(
                            date:
                                .abbreviated,
                            time:
                                .omitted
                        )
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()

            Text(
                "\(transaction.amountSign)\(transaction.amount.formatted(.number)) \(wallet.currencyCode)"
            )
            .foregroundStyle(transaction.isIncome ? Color.green : Color.primary)
            .fontWeight(
                .semibold
            )
        }
        .padding(
            .vertical,
            3
        )
    }

    private func transactionTitle(
        _ transaction:
            ExpenseTransaction
    ) -> String {

        let cleanedNote =
            transaction.note
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        if !cleanedNote.isEmpty {

            return cleanedNote
        }

        if let subcategory =
            transaction.subcategory {

            return
                subcategory.name
        }

        if let category =
            transaction.category {

            return
                category.name
        }

        return transaction.typeName
    }

    private func detailRow(
        title: String,
        value: String
    ) -> some View {

        HStack {

            Text(
                title
            )

            Spacer()

            Text(
                value
            )
            .foregroundStyle(
                .secondary
            )
        }
    }

    private func colorFromName(
        _ name: String
    ) -> Color {

        switch name {

        case "blue":
            return .blue

        case "green":
            return .green

        case "orange":
            return .orange

        case "purple":
            return .purple

        case "red":
            return .red

        case "pink":
            return .pink

        case "teal":
            return .teal

        case "gray":
            return .gray

        default:
            return .blue
        }
    }
}
