import SwiftUI
import SwiftData

struct TransactionFilterView: View {

    @Environment(\.dismiss)
    private var dismiss

    @Query(sort: \Wallet.createdAt)
    private var wallets: [Wallet]

    @Query(sort: \SpendingCategory.name)
    private var categories: [SpendingCategory]

    @Binding var selectedWallet: Wallet?
    @Binding var selectedCategory: SpendingCategory?

    @Binding var useDateFilter: Bool
    @Binding var startDate: Date
    @Binding var endDate: Date

    var body: some View {

        NavigationStack {

            Form {

                Section("Wallet") {

                    Picker(
                        "Wallet",
                        selection: $selectedWallet
                    ) {

                        Text("All Wallets")
                            .tag(nil as Wallet?)

                        ForEach(wallets) { wallet in

                            Text(
                                "\(wallet.name) • \(wallet.currencyCode)"
                            )
                            .tag(wallet as Wallet?)
                        }
                    }
                }

                Section("Category") {

                    Picker(
                        "Category",
                        selection: $selectedCategory
                    ) {

                        Text("All Categories")
                            .tag(nil as SpendingCategory?)

                        ForEach(categories) { category in

                            Text(category.name)
                                .tag(
                                    category
                                        as SpendingCategory?
                                )
                        }
                    }
                }

                Section("Date") {

                    Toggle(
                        "Filter by Date",
                        isOn: $useDateFilter
                    )

                    if useDateFilter {

                        DatePicker(
                            "From",
                            selection: $startDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )

                        DatePicker(
                            "To",
                            selection: $endDate,
                            in: startDate...Date(),
                            displayedComponents: .date
                        )
                    }
                }

                if hasActiveFilters {

                    Section {

                        Button(
                            "Clear Filters",
                            role: .destructive
                        ) {
                            clearFilters()
                        }
                    }
                }
            }

            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)

            .toolbar {

                ToolbarItem(
                    placement: .confirmationAction
                ) {

                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var hasActiveFilters: Bool {

        selectedWallet != nil ||
        selectedCategory != nil ||
        useDateFilter
    }

    private func clearFilters() {

        selectedWallet = nil
        selectedCategory = nil

        useDateFilter = false

        startDate =
            Calendar.current.date(
                byAdding: .month,
                value: -1,
                to: Date()
            ) ?? Date()

        endDate = Date()
    }
}
