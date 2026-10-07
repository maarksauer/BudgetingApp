import SwiftUI
import SwiftData

struct ConfirmRecurringPaymentView: View {

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.modelContext)
    private var modelContext

    @Query
    private var transfers: [WalletTransfer]

    let payment: RecurringPayment

    @State private var actualAmount: String
    @State private var paymentDate: Date = Date()

    init(payment: RecurringPayment) {

        self.payment = payment

        _actualAmount = State(
            initialValue:
                payment.amount.formatted(
                    .number
                )
        )
    }

    var body: some View {

        NavigationStack {

            Form {

                // MARK: - Payment

                Section("Payment") {

                    LabeledContent(
                        "Recurring Payment",
                        value: payment.name
                    )

                    if let wallet = payment.wallet {

                        LabeledContent(
                            "Wallet",
                            value: wallet.name
                        )
                    }

                    if let category = payment.category {

                        LabeledContent(
                            "Category",
                            value: category.name
                        )
                    }

                    if let subcategory = payment.subcategory {

                        LabeledContent(
                            "Subcategory",
                            value: subcategory.name
                        )
                    }

                    LabeledContent(
                        "Expected Amount"
                    ) {

                        Text(
                            "\(payment.amount.formatted(.number)) \(payment.wallet?.currencyCode ?? "")"
                        )
                    }
                }

                // MARK: - Actual Payment

                Section("Actual Payment") {

                    TextField(
                        "Actual Amount",
                        text: $actualAmount
                    )
                    .keyboardType(
                        .decimalPad
                    )

                    DatePicker(
                        "Payment Date",
                        selection: $paymentDate,
                        in: ...Date(),
                        displayedComponents:
                            .date
                    )
                }

                // MARK: - Wallet

                if let wallet = payment.wallet {

                    Section("Wallet Balance") {

                        LabeledContent(
                            "Current Balance"
                        ) {

                            Text(
                                "\(currentBalance(for: wallet).formatted(.number)) \(wallet.currencyCode)"
                            )
                        }

                        if wallet.walletType == "Credit Card" {

                            LabeledContent(
                                "Credit Limit"
                            ) {

                                Text(
                                    "\(wallet.negativeBalanceLimit.formatted(.number)) \(wallet.currencyCode)"
                                )
                            }

                            LabeledContent(
                                "Available Credit"
                            ) {

                                Text(
                                    "\(availableAmount(for: wallet).formatted(.number)) \(wallet.currencyCode)"
                                )
                            }

                        } else {

                            LabeledContent(
                                "Available to Spend"
                            ) {

                                Text(
                                    "\(availableAmount(for: wallet).formatted(.number)) \(wallet.currencyCode)"
                                )
                            }
                        }

                        if exceedsWalletLimit {

                            Text(
                                warningMessage
                            )
                            .font(
                                .caption
                            )
                            .foregroundStyle(
                                .red
                            )
                        }
                    }
                }

                // MARK: - Confirmation

                Section {

                    Button {

                        confirmPayment()

                    } label: {

                        Text(
                            "Confirm Payment"
                        )
                        .frame(
                            maxWidth:
                                .infinity
                        )
                    }
                    .disabled(
                        !canConfirm
                    )
                }
            }

            .navigationTitle(
                "Confirm Payment"
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
        }
    }

    // MARK: - Amount

    private var parsedAmount: Decimal? {

        let cleaned =
            actualAmount
                .replacingOccurrences(
                    of: " ",
                    with: ""
                )
                .replacingOccurrences(
                    of: ",",
                    with: "."
                )

        guard
            let value =
                Decimal(
                    string:
                        cleaned
                ),
            value > 0
        else {

            return nil
        }

        return value
    }

    // MARK: - Wallet Balance

    private func currentBalance(
        for wallet: Wallet
    ) -> Decimal {

        let outgoing =
            transfers
                .filter {

                    $0.sourceWallet?
                        .persistentModelID
                    ==
                    wallet
                        .persistentModelID
                }
                .reduce(
                    Decimal.zero
                ) {

                    $0
                    +
                    $1.sourceAmount
                }

        let incoming =
            transfers
                .filter {

                    $0.destinationWallet?
                        .persistentModelID
                    ==
                    wallet
                        .persistentModelID
                }
                .reduce(
                    Decimal.zero
                ) {

                    $0
                    +
                    $1.destinationAmount
                }

        return
            wallet.currentBalance
            -
            outgoing
            +
            incoming
    }

    private func availableAmount(
        for wallet: Wallet
    ) -> Decimal {

        let balance =
            currentBalance(
                for: wallet
            )

        return max(
            balance
            -
            wallet.minimumAllowedBalance,
            0
        )
    }

    // MARK: - Wallet Limit

    private var exceedsWalletLimit: Bool {

        guard
            let wallet =
                payment.wallet,
            let amount =
                parsedAmount
        else {

            return false
        }

        return
            amount
            >
            availableAmount(
                for: wallet
            )
    }

    private var warningMessage: String {

        guard
            let wallet =
                payment.wallet
        else {

            return ""
        }

        let available =
            availableAmount(
                for: wallet
            )

        if wallet.walletType
            ==
            "Credit Card" {

            return
                "This payment exceeds the available credit of \(available.formatted(.number)) \(wallet.currencyCode)."
        }

        if wallet.allowsNegativeBalance {

            return
                "This payment would exceed the wallet's negative balance limit. You can spend up to \(available.formatted(.number)) \(wallet.currencyCode)."
        }

        return
            "Insufficient balance. You can spend up to \(available.formatted(.number)) \(wallet.currencyCode)."
    }

    // MARK: - Validation

    private var canConfirm: Bool {

        parsedAmount != nil
        &&
        payment.wallet != nil
        &&
        payment.category != nil
        &&
        !exceedsWalletLimit
    }

    // MARK: - Confirm Payment

    private func confirmPayment() {

        guard
            let amount =
                parsedAmount,
            let wallet =
                payment.wallet,
            let category =
                payment.category
        else {

            return
        }

        // Save the exact state of the recurring payment
        // before we advance it.
        //
        // This allows us to revert an accidental
        // "Paid" action later.

        let originalScheduledDate =
            payment.scheduledPaymentDate

        let originalPostponedUntil =
            payment.postponedUntil

        let transaction =
            ExpenseTransaction(
                amount:
                    amount,
                date:
                    paymentDate,
                note:
                    payment.note,
                wallet:
                    wallet,
                category:
                    category,
                subcategory:
                    payment.subcategory,
                recurringPayment:
                    payment,
                recurringScheduledDate:
                    originalScheduledDate,
                recurringPostponedUntil:
                    originalPostponedUntil
            )

        modelContext.insert(
            transaction
        )

        // Advance from the ORIGINAL scheduled date,
        // not from the postponed date.

        payment.scheduledPaymentDate =
            nextScheduledDate(
                from:
                    originalScheduledDate
            )

        // The completed occurrence is no longer postponed.

        payment.postponedUntil =
            nil

        dismiss()
    }

    // MARK: - Next Scheduled Date

    private func nextScheduledDate(
        from date: Date
    ) -> Date {

        let calendar =
            Calendar.current

        switch payment.frequency {

        case "Weekly":

            return calendar.date(
                byAdding:
                    .weekOfYear,
                value:
                    1,
                to:
                    date
            )
            ??
            date

        case "Monthly":

            return calendar.date(
                byAdding:
                    .month,
                value:
                    1,
                to:
                    date
            )
            ??
            date

        case "Every 3 Months":

            return calendar.date(
                byAdding:
                    .month,
                value:
                    3,
                to:
                    date
            )
            ??
            date

        case "Every 6 Months":

            return calendar.date(
                byAdding:
                    .month,
                value:
                    6,
                to:
                    date
            )
            ??
            date

        case "Yearly":

            return calendar.date(
                byAdding:
                    .year,
                value:
                    1,
                to:
                    date
            )
            ??
            date

        default:

            return date
        }
    }
}
