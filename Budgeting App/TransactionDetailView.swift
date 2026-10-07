import SwiftUI
import SwiftData

struct TransactionDetailView: View {

    @Environment(\.modelContext)
    private var modelContext

    @Environment(\.dismiss)
    private var dismiss

    @Query(sort: \Wallet.createdAt)
    private var wallets: [Wallet]

    @Query(sort: \SpendingCategory.createdAt)
    private var categories: [SpendingCategory]

    @Query
    private var transfers: [WalletTransfer]

    let transaction: ExpenseTransaction

    @State private var amount: String
    @State private var note: String
    @State private var date: Date

    @State private var selectedWallet: Wallet?
    @State private var selectedCategory: SpendingCategory?

    @State private var selectedSubcategoryID: PersistentIdentifier?

    @State private var isEditing = false

    @State private var showingDeleteConfirmation = false
    @State private var showingRevertConfirmation = false

    init(
        transaction: ExpenseTransaction
    ) {

        self.transaction = transaction

        _amount = State(
            initialValue:
                NSDecimalNumber(
                    decimal: transaction.amount
                ).stringValue
        )

        _note = State(
            initialValue:
                transaction.note
        )

        _date = State(
            initialValue:
                transaction.date
        )

        _selectedWallet = State(
            initialValue:
                transaction.wallet
        )

        _selectedCategory = State(
            initialValue:
                transaction.category
        )

        _selectedSubcategoryID = State(
            initialValue:
                transaction.subcategory?
                    .persistentModelID
        )
    }

    var body: some View {

        Form {

            // MARK: - Expense

            Section(transaction.typeName) {

                if isEditing {

                    TextField(
                        "Amount",
                        text: $amount
                    )
                    .keyboardType(.decimalPad)

                    if !amount.isEmpty &&
                        parsedAmount == nil {

                        Text(
                            "Enter a valid amount."
                        )
                        .font(.caption)
                        .foregroundStyle(.red)
                    }

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

                    detailRow(
                        title: "Amount",
                        value:
                            "\(transaction.amount.formatted(.number)) \(transaction.wallet?.currencyCode ?? "")"
                    )

                    detailRow(
                        title: "Date",
                        value:
                            transaction.date.formatted(
                                date: .abbreviated,
                                time: .omitted
                            )
                    )

                    detailRow(
                        title: "Note",
                        value:
                            transaction.note.isEmpty
                            ? "None"
                            : transaction.note
                    )
                }
            }

            // MARK: - Wallet

            Section("Wallet") {

                if isEditing {

                    Picker(
                        "Wallet",
                        selection: $selectedWallet
                    ) {

                        Text(
                            "Select Wallet"
                        )
                        .tag(
                            nil as Wallet?
                        )

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

                    if let selectedWallet {

                        HStack {

                            Text(
                                "Current Balance"
                            )

                            Spacer()

                            Text(
                                "\(balanceForEditing(wallet: selectedWallet).formatted(.number)) \(selectedWallet.currencyCode)"
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }

                        HStack {

                            Text(
                                selectedWallet.walletType
                                ==
                                "Credit Card"
                                ? "Available Credit"
                                : "Available to Spend"
                            )

                            Spacer()

                            Text(
                                "\(availableAmountForEditing(wallet: selectedWallet).formatted(.number)) \(selectedWallet.currencyCode)"
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }

                        if selectedWallet.walletType
                            ==
                            "Credit Card" {

                            HStack {

                                Text(
                                    "Credit Limit"
                                )

                                Spacer()

                                Text(
                                    "\(selectedWallet.negativeBalanceLimit.formatted(.number)) \(selectedWallet.currencyCode)"
                                )
                                .foregroundStyle(
                                    .secondary
                                )
                            }
                        }

                        if exceedsAvailableBalance {

                            Text(
                                limitWarningMessage(
                                    for: selectedWallet
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.red)
                        }
                    }

                } else {

                    detailRow(
                        title: "Wallet",
                        value:
                            transaction.wallet?.name
                            ?? "None"
                    )
                }
            }

            // MARK: - Category

            if !transaction.isIncome {
                Section("Category") {

                    if isEditing {

                        Picker(
                            "Category",
                            selection:
                                $selectedCategory
                        ) {

                            Text(
                                "Select Category"
                            )
                            .tag(
                                nil as SpendingCategory?
                            )

                            ForEach(
                                categories
                            ) { category in

                                Text(
                                    category.name
                                )
                                .tag(
                                    category
                                        as SpendingCategory?
                                )
                            }
                        }
                        .onChange(
                            of: selectedCategory
                        ) {

                            selectedSubcategoryID =
                                nil
                        }

                        if let selectedCategory,
                           !selectedCategory
                            .subcategories
                            .isEmpty {

                            Picker(
                                "Subcategory",
                                selection:
                                    $selectedSubcategoryID
                            ) {

                                Text(
                                    "None"
                                )
                                .tag(
                                    nil
                                        as PersistentIdentifier?
                                )

                                ForEach(
                                    selectedCategory
                                        .subcategories
                                        .sorted {

                                            $0.name
                                                .localizedCaseInsensitiveCompare(
                                                    $1.name
                                                )
                                            ==
                                            .orderedAscending
                                        }
                                ) { subcategory in

                                    Text(
                                        subcategory.name
                                    )
                                    .tag(
                                        subcategory
                                            .persistentModelID
                                            as PersistentIdentifier?
                                    )
                                }
                            }
                        }

                    } else {

                        detailRow(
                            title: "Category",
                            value:
                                transaction.category?.name
                                ?? "None"
                        )

                        detailRow(
                            title: "Subcategory",
                            value:
                                transaction.subcategory?.name
                                ?? "None"
                        )
                    }
                }
            }

            // MARK: - Recurring Payment

            if !isEditing,
               transaction.recurringPayment != nil,
               transaction.recurringScheduledDate != nil {

                Section(
                    "Recurring Payment"
                ) {

                    if let recurringPayment =
                        transaction.recurringPayment {

                        detailRow(
                            title:
                                "Recurring Payment",
                            value:
                                recurringPayment.name
                        )
                    }

                    Button(
                        role: .destructive
                    ) {

                        showingRevertConfirmation =
                            true

                    } label: {

                        Label(
                            "Revert Recurring Payment",
                            systemImage:
                                "arrow.uturn.backward.circle"
                        )
                    }
                }
            }

            // MARK: - Delete

            if !isEditing {

                Section {

                    Button(
                        "Delete Transaction",
                        role: .destructive
                    ) {

                        showingDeleteConfirmation =
                            true
                    }
                }
            }
        }

        .navigationTitle(
            isEditing
            ? "Edit Transaction"
            : "Transaction"
        )

        .navigationBarTitleDisplayMode(
            .inline
        )

        .toolbar {

            ToolbarItem(
                placement:
                    .primaryAction
            ) {

                if isEditing {

                    Button(
                        "Save"
                    ) {

                        saveChanges()
                    }
                    .disabled(
                        !canSave
                    )

                } else {

                    Button(
                        "Edit"
                    ) {

                        isEditing =
                            true
                    }
                }
            }

            if isEditing {

                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {

                    Button(
                        "Cancel"
                    ) {

                        resetForm()

                        isEditing =
                            false
                    }
                }
            }
        }

        // MARK: - Delete Confirmation

        .confirmationDialog(
            "Delete Transaction?",
            isPresented:
                $showingDeleteConfirmation,
            titleVisibility:
                .visible
        ) {

            Button(
                "Delete Transaction",
                role: .destructive
            ) {

                deleteTransaction()
            }

            Button(
                "Cancel",
                role: .cancel
            ) { }

        } message: {

            Text(
                "This cannot be undone. The wallet balance will be updated automatically."
            )
        }

        // MARK: - Revert Confirmation

        .confirmationDialog(
            "Revert Recurring Payment?",
            isPresented:
                $showingRevertConfirmation,
            titleVisibility:
                .visible
        ) {

            Button(
                "Revert Payment",
                role: .destructive
            ) {

                revertRecurringPayment()
            }

            Button(
                "Cancel",
                role: .cancel
            ) { }

        } message: {

            Text(
                "This transaction will be deleted and the recurring payment will return to its previous due or postponed state. The wallet balance will be restored automatically."
            )
        }
    }

    // MARK: - Selected Subcategory

    private var selectedSubcategory:
        SpendingSubcategory? {

        guard
            let selectedSubcategoryID,
            let selectedCategory
        else {

            return nil
        }

        return selectedCategory
            .subcategories
            .first {

                $0.persistentModelID
                ==
                selectedSubcategoryID
            }
    }

    // MARK: - Amount Parsing

    private var parsedAmount:
        Decimal? {

        let cleanedAmount =
            amount
                .replacingOccurrences(
                    of: " ",
                    with: ""
                )
                .replacingOccurrences(
                    of: ",",
                    with: "."
                )

        guard
            let decimalAmount =
                Decimal(
                    string:
                        cleanedAmount
                ),
            decimalAmount > 0
        else {

            return nil
        }

        return decimalAmount
    }

    // MARK: - Validation

    private var exceedsAvailableBalance:
        Bool {

        guard !transaction.isIncome else { return false }

        guard
            let wallet =
                selectedWallet,
            let newAmount =
                parsedAmount
        else {

            return false
        }

        return
            newAmount
            >
            availableAmountForEditing(
                wallet:
                    wallet
            )
    }

    private var canSave:
        Bool {

        guard
            parsedAmount != nil,
            selectedWallet != nil,
            (transaction.isIncome || selectedCategory != nil)
        else {

            return false
        }

        return
            !exceedsAvailableBalance
    }

    // MARK: - Wallet Balance

    private func walletBalance(
        for wallet: Wallet
    ) -> Decimal {
        wallet.balance(including: transfers)
    }

    // MARK: - Editing Balance

    private func balanceForEditing(
        wallet: Wallet
    ) -> Decimal {

        var current =
            walletBalance(
                for: wallet
            )

        /*
         If the transaction already belongs to this
         wallet, temporarily restore its current amount
         before validating the edited amount.
        */

        if transaction.wallet?
            .persistentModelID
            ==
            wallet
                .persistentModelID {

            current -= transaction.balanceImpact
        }

        return current
    }

    private func availableAmountForEditing(
        wallet: Wallet
    ) -> Decimal {

        let available =
            balanceForEditing(
                wallet:
                    wallet
            )
            -
            wallet.minimumAllowedBalance

        return max(
            available,
            0
        )
    }

    // MARK: - Warning

    private func limitWarningMessage(
        for wallet: Wallet
    ) -> String {

        let available =
            availableAmountForEditing(
                wallet:
                    wallet
            )

        if wallet.walletType
            ==
            "Credit Card" {

            return
                "This expense exceeds the available credit of \(available.formatted(.number)) \(wallet.currencyCode)."
        }

        if wallet.allowsNegativeBalance {

            return
                "This expense would exceed the wallet's negative balance limit. You can spend up to \(available.formatted(.number)) \(wallet.currencyCode)."
        }

        return
            "Insufficient balance. You can spend up to \(available.formatted(.number)) \(wallet.currencyCode)."
    }

    // MARK: - Save

    private func saveChanges() {

        guard canSave,
              let decimalAmount = parsedAmount,
              let wallet = selectedWallet else { return }

        transaction.amount =
            decimalAmount

        transaction.date =
            date

        transaction.note =
            note.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        transaction.wallet =
            wallet

        transaction.category =
            transaction.isIncome ? nil : selectedCategory

        transaction.subcategory =
            transaction.isIncome ? nil : selectedSubcategory

        isEditing =
            false
    }

    // MARK: - Revert Recurring Payment

    private func revertRecurringPayment() {

        guard
            let recurringPayment =
                transaction.recurringPayment,
            let originalScheduledDate =
                transaction.recurringScheduledDate
        else {

            return
        }

        // Restore the recurring payment to exactly
        // where it was before "Paid" was confirmed.

        recurringPayment.scheduledPaymentDate =
            originalScheduledDate

        recurringPayment.postponedUntil =
            transaction
                .recurringPostponedUntil

        // Remove the expense.
        // Wallet balance and budget spending will
        // update automatically.

        modelContext.delete(
            transaction
        )

        dismiss()
    }

    // MARK: - Delete

    private func deleteTransaction() {

        modelContext.delete(
            transaction
        )

        dismiss()
    }

    // MARK: - Cancel Editing

    private func resetForm() {

        amount =
            NSDecimalNumber(
                decimal:
                    transaction.amount
            )
            .stringValue

        note =
            transaction.note

        date =
            transaction.date

        selectedWallet =
            transaction.wallet

        selectedCategory =
            transaction.category

        selectedSubcategoryID =
            transaction
                .subcategory?
                .persistentModelID
    }

    // MARK: - Detail Row

    @ViewBuilder
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
            .multilineTextAlignment(
                .trailing
            )
        }
    }
}
