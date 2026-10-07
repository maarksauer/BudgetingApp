import SwiftUI
import SwiftData

struct CreateBudgetView: View {
    @AppStorage(CurrencyPreferences.storageKey) private var storedCurrencyPreferences = CurrencyPreferences.defaultStorageValue

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.modelContext)
    private var modelContext

    @State private var name = ""
    @State private var amount = ""
    @State private var currency = CurrencyPreferences.load().defaultCode

    @State private var startDate = Date()

    @State private var endDate =
        Calendar.current.date(
            byAdding: .month,
            value: 1,
            to: Date()
        ) ?? Date()

    @State private var isRecurring = false
    @State private var recurrenceType = "Monthly"

    @Query private var wallets: [Wallet]
    @Query private var existingBudgets: [Budget]

    private var currencies: [String] {
        CurrencyPreferences.decode(storedCurrencyPreferences).budgetCodes(
            existingCodes: wallets.map(\.currencyCode) + existingBudgets.map(\.currencyCode),
            selectedCode: currency
        )
    }

    let recurrenceTypes = [
        "Monthly"
    ]

    var body: some View {

        NavigationStack {

            Form {

                Section("Budget Details") {

                    TextField(
                        "Budget name",
                        text: $name
                    )

                    TextField(
                        "Total amount",
                        text: $amount
                    )
                    .keyboardType(.decimalPad)

                    if !amount.isEmpty && parsedAmount == nil {
                        Text("Enter a valid amount.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Picker(
                        "Currency",
                        selection: $currency
                    ) {
                        ForEach(
                            currencies,
                            id: \.self
                        ) {
                            Text($0).tag($0)
                        }
                    }
                }

                Section("Period") {

                    DatePicker(
                        "Start Date",
                        selection: $startDate,
                        displayedComponents: .date
                    )

                    DatePicker(
                        "End Date",
                        selection: $endDate,
                        in: startDate...,
                        displayedComponents: .date
                    )
                }

                Section("Repeat") {

                    Toggle(
                        "Recurring Budget",
                        isOn: $isRecurring
                    )

                    if isRecurring {

                        Picker(
                            "Repeat",
                            selection: $recurrenceType
                        ) {

                            ForEach(
                                recurrenceTypes,
                                id: \.self
                            ) {
                                Text($0)
                            }
                        }

                        Text(
                            "A new budget period will be created automatically when this one ends."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Section {

                    Button {
                        createBudget()
                    } label: {

                        Text("Create Budget")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!canCreateBudget)
                }
            }

            .onChange(of: storedCurrencyPreferences) {
                let preferences = CurrencyPreferences.decode(storedCurrencyPreferences)
                let available = preferences.budgetCodes(existingCodes: wallets.map(\.currencyCode) + existingBudgets.map(\.currencyCode))
                if !available.contains(currency) { currency = preferences.defaultCode }
            }
            .navigationTitle("New Budget")
            .navigationBarTitleDisplayMode(.inline)

            .toolbar {

                ToolbarItem(
                    placement: .cancellationAction
                ) {

                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var cleanedName: String {

        name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var parsedAmount: Decimal? {

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
                    string: cleanedAmount
                ),
            decimalAmount > 0
        else {
            return nil
        }

        return decimalAmount
    }

    private var canCreateBudget: Bool {

        !cleanedName.isEmpty &&
        parsedAmount != nil
    }

    private func createBudget() {

        guard
            let decimalAmount =
                parsedAmount
        else {
            return
        }

        let budget =
            Budget(
                name:
                    cleanedName,
                totalAmount:
                    decimalAmount,
                currencyCode:
                    currency,
                startDate:
                    startDate,
                endDate:
                    endDate,
                isRecurring:
                    isRecurring,
                recurrenceType:
                    recurrenceType
            )

        modelContext.insert(
            budget
        )

        dismiss()
    }
}
