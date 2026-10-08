import SwiftUI
import SwiftData

struct TransactionFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Wallet.createdAt) private var wallets: [Wallet]
    @Query(sort: \SpendingCategory.name) private var categories: [SpendingCategory]
    @State private var draft: TransactionFilters
    let apply: (TransactionFilters) -> Void

    init(filters: TransactionFilters, apply: @escaping (TransactionFilters) -> Void) {
        _draft = State(initialValue: filters)
        self.apply = apply
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Transaction Type", selection: $draft.kind) {
                        ForEach(TransactionActivityKind.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu).accessibilityIdentifier("transactionFilterType")
                }
                Section("Wallet") {
                    Picker("Wallet", selection: $draft.walletID) {
                        Text("All Wallets").tag(nil as PersistentIdentifier?)
                        ForEach(wallets) { wallet in
                            Label("\(wallet.name) • \(wallet.currencyCode)", systemImage: wallet.icon)
                                .tag(wallet.persistentModelID as PersistentIdentifier?)
                        }
                    }
                    .pickerStyle(.menu).accessibilityIdentifier("transactionFilterWallet")
                }
                Section {
                    Picker("Category", selection: $draft.categoryID) {
                        Text("All Categories").tag(nil as PersistentIdentifier?)
                        ForEach(categories) { category in
                            Label(category.name, systemImage: category.icon)
                                .tag(category.persistentModelID as PersistentIdentifier?)
                        }
                    }
                    .pickerStyle(.menu).disabled(draft.kind == .transfers)
                    .accessibilityIdentifier("transactionFilterCategory")
                } header: {
                    Text("Category")
                } footer: {
                    Text("Transfers have no category. Choosing a category shows matching income and expenses only.")
                }
                Section("Date") {
                    Picker("Period", selection: $draft.period) {
                        ForEach(TransactionDatePeriod.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu).accessibilityIdentifier("transactionFilterPeriod")
                    if draft.period == .custom {
                        DatePicker("From", selection: $draft.startDate, displayedComponents: .date)
                            .accessibilityIdentifier("transactionFilterStart")
                        DatePicker("To", selection: $draft.endDate, in: draft.startDate..., displayedComponents: .date)
                            .accessibilityIdentifier("transactionFilterEnd")
                        Text("Includes every transaction on both selected days.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if draft.hasActiveFilters {
                    Section {
                        Button("Reset Filters") { draft = TransactionFilters() }
                            .accessibilityIdentifier("resetTransactionFilterDraft")
                    }
                }
            }
            .navigationTitle("Filters").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.accessibilityIdentifier("cancelTransactionFilters")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        if let id = draft.walletID, !wallets.contains(where: { $0.persistentModelID == id }) { draft.walletID = nil }
                        if let id = draft.categoryID, !categories.contains(where: { $0.persistentModelID == id }) { draft.categoryID = nil }
                        apply(draft)
                        dismiss()
                    }
                    .accessibilityIdentifier("applyTransactionFilters")
                }
            }
            .onChange(of: draft.kind) { _, kind in
                if kind == .transfers { draft.categoryID = nil }
            }
            .onChange(of: draft.startDate) { _, start in
                if draft.endDate < start { draft.endDate = start }
            }
        }
    }
}
