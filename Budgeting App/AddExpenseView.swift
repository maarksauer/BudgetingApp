import SwiftUI
import SwiftData

struct AddExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Wallet.createdAt) private var wallets: [Wallet]
    @Query(sort: \SpendingCategory.createdAt) private var categories: [SpendingCategory]
    @Query private var transfers: [WalletTransfer]
    @Binding var draft: ExpenseDraft
    @FocusState private var focusedField: TransactionFormField?
    @State private var isSaving = false
    @State private var showingSavedConfirmation = false
    @State private var showingSaveError = false
    @State private var saveError = ""
    @State private var showingCreateWallet = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $draft.isIncome) {
                        Label("Expense", systemImage: "arrow.up.right").tag(false)
                        Label("Income", systemImage: "arrow.down.left").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("transactionType")
                }
                TransactionFormFields(draft: $draft, wallets: wallets, categories: categories,
                                      transfers: transfers, focusedField: $focusedField, prefix: "expense")
                if wallets.isEmpty {
                    Section {
                        Button { focusedField = nil; showingCreateWallet = true } label: {
                            Label("Create Your First Wallet", systemImage: "plus.circle")
                        }
                        .accessibilityIdentifier("createFirstWallet")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(draft.isIncome ? "Add Income" : "Add Expense", action: save)
                        .buttonStyle(.borderedProminent)
                        .disabled(!draft.canSave(transfers: transfers) || isSaving)
                        .accessibilityIdentifier("saveTransaction")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    if focusedField != nil {
                        Spacer()
                        Button("Done") { focusedField = nil }
                            .accessibilityIdentifier("dismissExpenseKeyboard")
                    }
                }
            }
            .onDisappear { focusedField = nil }
            .onAppear {
                createDefaultCategoriesIfNeeded()
                setDefaultSelections()
            }
            .onChange(of: wallets.map(\.persistentModelID)) { setDefaultSelections() }
            .onChange(of: categories.map(\.persistentModelID)) { setDefaultSelections() }
            .sheet(isPresented: $showingCreateWallet) { CreateWalletView() }
            .alert("Couldn’t save transaction", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: { Text("Your entries are still here. \(saveError)") }
            .alert("Transaction Added", isPresented: $showingSavedConfirmation) {
                Button("OK", role: .cancel) { }
            } message: { Text("Your transaction has been saved.") }
        }
    }

    private func setDefaultSelections() {
        if !wallets.contains(where: { $0.persistentModelID == draft.selectedWallet?.persistentModelID }) {
            draft.selectedWallet = wallets.first
        }
        if !categories.contains(where: { $0.persistentModelID == draft.selectedCategory?.persistentModelID }) {
            draft.selectedCategory = categories.first
            draft.selectedSubcategoryID = nil
        }
    }

    private func save() {
        guard draft.canSave(transfers: transfers), !isSaving else { return }
        focusedField = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try FormStore.createTransaction(draft, context: modelContext)
            draft.amount = ""; draft.note = ""; draft.transactionDate = Date()
            draft.selectedSubcategoryID = nil
            showingSavedConfirmation = true
        } catch {
            saveError = error.localizedDescription
            showingSaveError = true
        }
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
