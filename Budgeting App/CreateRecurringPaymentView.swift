import SwiftUI
import SwiftData

struct CreateRecurringPaymentView: View {

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.modelContext)
    private var modelContext

    @Query(sort: \Wallet.createdAt)
    private var wallets: [Wallet]

    @Query(sort: \SpendingCategory.createdAt)
    private var categories: [SpendingCategory]

    @State private var name = ""
    @State private var amount = ""

    @State private var selectedWallet: Wallet?
    @State private var selectedCategory: SpendingCategory?
    @State private var selectedSubcategory: SpendingSubcategory?

    @State private var frequency = "Monthly"

    @State private var nextPaymentDate =
        Date()

    @State private var note = ""

    let frequencies = [
        "Weekly",
        "Monthly",
        "Every 3 Months",
        "Every 6 Months",
        "Yearly"
    ]

    var body: some View {

        NavigationStack {

            Form {

                // MARK: - Payment

                Section("Payment") {

                    TextField(
                        "Name",
                        text: $name
                    )

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
                }

                // MARK: - Wallet

                Section("Wallet") {

                    if wallets.isEmpty {

                        Text(
                            "Create a wallet before adding a recurring payment."
                        )
                        .foregroundStyle(.secondary)

                    } else {

                        Picker(
                            "Wallet",
                            selection: $selectedWallet
                        ) {

                            Text("Select Wallet")
                                .tag(nil as Wallet?)

                            ForEach(wallets) { wallet in

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

                                Text("Currency")

                                Spacer()

                                Text(
                                    selectedWallet.currencyCode
                                )
                                .foregroundStyle(.secondary)
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
                        .foregroundStyle(.secondary)

                    } else {

                        Picker(
                            "Category",
                            selection: $selectedCategory
                        ) {

                            Text("Select Category")
                                .tag(nil as SpendingCategory?)

                            ForEach(categories) { category in

                                Text(category.name)
                                    .tag(
                                        category
                                            as SpendingCategory?
                                    )
                            }
                        }
                        .onChange(
                            of: selectedCategory
                        ) {
                            selectedSubcategory = nil
                        }

                        if let selectedCategory,
                           !selectedCategory
                            .subcategories
                            .isEmpty {

                            Picker(
                                "Subcategory",
                                selection:
                                    $selectedSubcategory
                            ) {

                                Text("None")
                                    .tag(
                                        nil
                                            as SpendingSubcategory?
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
                                            as SpendingSubcategory?
                                    )
                                }
                            }
                        }
                    }
                }

                // MARK: - Schedule

                Section("Schedule") {

                    Picker(
                        "Frequency",
                        selection: $frequency
                    ) {

                        ForEach(
                            frequencies,
                            id: \.self
                        ) { frequency in

                            Text(frequency)
                        }
                    }

                    DatePicker(
                        "Next Payment",
                        selection:
                            $nextPaymentDate,
                        in: Date()...,
                        displayedComponents:
                            .date
                    )

                    Text(
                        scheduleDescription
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                // MARK: - Note

                Section("Note") {

                    TextField(
                        "Optional note",
                        text: $note
                    )
                }

                // MARK: - Create

                Section {

                    Button {

                        createRecurringPayment()

                    } label: {

                        Text(
                            "Create Recurring Payment"
                        )
                        .frame(
                            maxWidth: .infinity
                        )
                    }
                    .disabled(
                        !canCreate
                    )
                }
            }

            .navigationTitle(
                "New Recurring Payment"
            )

            .navigationBarTitleDisplayMode(
                .inline
            )

            .toolbar {

                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {

                    Button("Cancel") {

                        dismiss()
                    }
                }
            }

            .onAppear {

                if selectedWallet == nil {
                    selectedWallet = wallets.first
                }

                if selectedCategory == nil {
                    selectedCategory = categories.first
                }
            }
        }
    }

    // MARK: - Validation

    private var cleanedName: String {

        name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var parsedAmount: Decimal? {

        let cleaned =
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
            let decimal =
                Decimal(
                    string: cleaned
                ),
            decimal > 0
        else {
            return nil
        }

        return decimal
    }

    private var canCreate: Bool {

        !cleanedName.isEmpty
        &&
        parsedAmount != nil
        &&
        selectedWallet != nil
        &&
        selectedCategory != nil
    }

    // MARK: - Schedule Description

    private var scheduleDescription: String {

        switch frequency {

        case "Weekly":

            return
                "This payment will repeat every week."

        case "Monthly":

            return
                "This payment will repeat every month."

        case "Every 3 Months":

            return
                "This payment will repeat every three months."

        case "Every 6 Months":

            return
                "This payment will repeat every six months."

        case "Yearly":

            return
                "This payment will repeat once every year."

        default:

            return ""
        }
    }

    // MARK: - Create

    private func createRecurringPayment() {

        guard
            let decimalAmount =
                parsedAmount,
            let wallet =
                selectedWallet,
            let category =
                selectedCategory
        else {
            return
        }

        let payment =
            RecurringPayment(
                name:
                    cleanedName,
                amount:
                    decimalAmount,
                frequency:
                    frequency,
                nextPaymentDate:
                    nextPaymentDate,
                note:
                    note.trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    ),
                isActive:
                    true,
                wallet:
                    wallet,
                category:
                    category,
                subcategory:
                    selectedSubcategory
            )

        modelContext.insert(
            payment
        )

        dismiss()
    }
}
