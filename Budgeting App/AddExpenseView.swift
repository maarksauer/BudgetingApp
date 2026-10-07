import SwiftUI
import SwiftData

struct ExpenseDraft {
    var amount = ""
    var note = ""
    var transactionDate = Date()
    var selectedWallet: Wallet?
    var selectedCategory: SpendingCategory?
    var selectedSubcategoryID: PersistentIdentifier?
}

struct AddExpenseView: View {

    @Environment(\.modelContext)
    private var modelContext

    @Query(sort: \Wallet.createdAt)
    private var wallets: [Wallet]

    @Query(sort: \SpendingCategory.createdAt)
    private var categories: [SpendingCategory]

    @Query
    private var transfers: [WalletTransfer]

    @Binding private var amount: String
    @Binding private var note: String
    @Binding private var transactionDate: Date

    @Binding private var selectedWallet: Wallet?
    @Binding private var selectedCategory: SpendingCategory?

    // We store the model ID instead of the model object
    // because Picker requires a Hashable selection.
    @Binding private var selectedSubcategoryID: PersistentIdentifier?

    @State private var showingSavedConfirmation = false

    private enum Field: Hashable {
        case amount
        case note
    }

    @FocusState private var focusedField: Field?

    private let onClose: () -> Void

    init(draft: Binding<ExpenseDraft>, onClose: @escaping () -> Void) {
        _amount = draft.amount
        _note = draft.note
        _transactionDate = draft.transactionDate
        _selectedWallet = draft.selectedWallet
        _selectedCategory = draft.selectedCategory
        _selectedSubcategoryID = draft.selectedSubcategoryID
        self.onClose = onClose
    }

    var body: some View {

        NavigationStack {

            Form {

                // MARK: - Expense

                Section("Expense") {

                    TextField(
                        "Amount",
                        text: $amount
                    )
                    .focused($focusedField, equals: .amount)
                    .accessibilityIdentifier("expenseAmount")
                    #if os(iOS) || os(visionOS)
                    .keyboardType(.decimalPad)
                    #endif

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
                        selection: $transactionDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )

                    TextField(
                        "Note",
                        text: $note
                    )
                    .focused($focusedField, equals: .note)
                    .submitLabel(.done)
                    .accessibilityIdentifier("expenseNote")
                }

                // MARK: - Wallet

                Section("Wallet") {

                    if wallets.isEmpty {

                        Text(
                            "Create a wallet before adding an expense."
                        )
                        .foregroundStyle(.secondary)

                    } else {

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
                                    "\(balance(for: selectedWallet).formatted(.number)) \(selectedWallet.currencyCode)"
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
                                    "\(availableAmount(for: selectedWallet).formatted(.number)) \(selectedWallet.currencyCode)"
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
                    }
                }

                // MARK: - Category

                Section("Category") {

                    if categories.isEmpty {

                        Text(
                            "No categories available."
                        )
                        .foregroundStyle(
                            .secondary
                        )

                    } else {

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
                    }
                }

                // MARK: - Add Expense

                Section {

                    Button {

                        addExpense()

                    } label: {

                        Text(
                            "Add Expense"
                        )
                        .frame(
                            maxWidth:
                                .infinity
                        )
                    }
                    .disabled(
                        !canAddExpense
                    )
                }
            }

            .scrollDismissesKeyboard(.interactively)
            .onSubmit {
                focusedField = nil
            }

            #if os(iOS) || os(visionOS)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if focusedField != nil {
                        Spacer()
                        Button("Done") {
                            focusedField = nil
                        }
                        .accessibilityIdentifier("dismissExpenseKeyboard")
                    }
                }
            }
            #endif

            .navigationTitle(
                "Add Expense"
            )

            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        focusedField = nil
                        onClose()
                    }
                    .accessibilityIdentifier("closeAddExpense")
                }
            }

            .onAppear {

                createDefaultCategoriesIfNeeded()

                setDefaultSelections()
            }

            .onDisappear {
                focusedField = nil
            }

            .alert(
                "Expense Added",
                isPresented:
                    $showingSavedConfirmation
            ) {

                Button(
                    "OK"
                ) { }

            } message: {

                Text(
                    "The transaction was saved successfully."
                )
            }
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

    // MARK: - Amount

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

    // MARK: - Balance Validation

    private var exceedsAvailableBalance:
        Bool {

        guard
            let amount =
                parsedAmount,
            let wallet =
                selectedWallet
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

    private var canAddExpense:
        Bool {

        guard
            parsedAmount != nil,
            selectedWallet != nil,
            selectedCategory != nil
        else {

            return false
        }

        return
            !exceedsAvailableBalance
    }

    private func limitWarningMessage(
        for wallet: Wallet
    ) -> String {

        let available =
            availableAmount(
                for: wallet
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

    // MARK: - Wallet Balance

    private func balance(
        for wallet: Wallet
    ) -> Decimal {

        let transfersOut =
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

        let transfersIn =
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
            transfersOut
            +
            transfersIn
    }

    private func availableAmount(
        for wallet: Wallet
    ) -> Decimal {

        let available =
            balance(
                for: wallet
            )
            -
            wallet.minimumAllowedBalance

        return max(
            available,
            0
        )
    }

    // MARK: - Defaults

    private func setDefaultSelections() {

        if !wallets.contains(where: { $0.persistentModelID == selectedWallet?.persistentModelID }) {

            selectedWallet =
                wallets.first
        }

        if !categories.contains(where: { $0.persistentModelID == selectedCategory?.persistentModelID }) {

            selectedCategory =
                categories.first

            selectedSubcategoryID = nil
        }
    }

    // MARK: - Add Expense

    private func addExpense() {

        guard
            let decimalAmount =
                parsedAmount,
            let wallet =
                selectedWallet,
            let category =
                selectedCategory,
            decimalAmount
            <=
            availableAmount(
                for: wallet
            )
        else {

            return
        }

        let transaction =
            ExpenseTransaction(
                amount:
                    decimalAmount,
                date:
                    transactionDate,
                note:
                    note
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        ),
                wallet:
                    wallet,
                category:
                    category,
                subcategory:
                    selectedSubcategory
            )

        modelContext.insert(
            transaction
        )

        focusedField = nil

        amount = ""
        note = ""
        transactionDate =
            Date()

        selectedSubcategoryID =
            nil

        showingSavedConfirmation =
            true
    }

    // MARK: - Default Categories

    private func createDefaultCategoriesIfNeeded() {

        guard
            categories.isEmpty
        else {

            return
        }

        // FOOD

        let food =
            SpendingCategory(
                name: "Food",
                icon: "fork.knife",
                colorName: "orange"
            )

        let groceries =
            SpendingSubcategory(
                name: "Groceries",
                category: food
            )

        let restaurants =
            SpendingSubcategory(
                name: "Restaurants",
                category: food
            )

        food.subcategories = [
            groceries,
            restaurants
        ]

        // TRANSPORT

        let transport =
            SpendingCategory(
                name: "Transport",
                icon: "car.fill",
                colorName: "blue"
            )

        let fuel =
            SpendingSubcategory(
                name: "Fuel",
                category:
                    transport
            )

        let publicTransport =
            SpendingSubcategory(
                name:
                    "Public Transport",
                category:
                    transport
            )

        transport.subcategories = [
            fuel,
            publicTransport
        ]

        // BILLS

        let bills =
            SpendingCategory(
                name: "Bills",
                icon:
                    "doc.text.fill",
                colorName:
                    "red"
            )

        let utilities =
            SpendingSubcategory(
                name:
                    "Utilities",
                category:
                    bills
            )

        let subscriptions =
            SpendingSubcategory(
                name:
                    "Subscriptions",
                category:
                    bills
            )

        bills.subcategories = [
            utilities,
            subscriptions
        ]

        // SHOPPING

        let shopping =
            SpendingCategory(
                name:
                    "Shopping",
                icon:
                    "bag.fill",
                colorName:
                    "purple"
            )

        let clothing =
            SpendingSubcategory(
                name:
                    "Clothing",
                category:
                    shopping
            )

        let electronics =
            SpendingSubcategory(
                name:
                    "Electronics",
                category:
                    shopping
            )

        shopping.subcategories = [
            clothing,
            electronics
        ]

        modelContext.insert(
            food
        )

        modelContext.insert(
            transport
        )

        modelContext.insert(
            bills
        )

        modelContext.insert(
            shopping
        )
    }
}
