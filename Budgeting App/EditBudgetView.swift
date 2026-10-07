import SwiftUI
import SwiftData

struct EditBudgetView: View {

    @Environment(\.dismiss)
    private var dismiss

    @Query
    private var allBudgets: [Budget]

    let budget: Budget

    @State private var name: String
    @State private var amount: String
    @State private var currency: String
    @State private var startDate: Date
    @State private var endDate: Date

    @State private var isRecurring: Bool
    @State private var recurrenceType: String

    @State private var showingSaveOptions = false

    let currencies = [
        "HUF",
        "EUR",
        "GBP",
        "USD"
    ]

    let recurrenceTypes = [
        "Monthly"
    ]

    init(
        budget: Budget
    ) {
        self.budget = budget

        _name = State(
            initialValue: budget.name
        )

        _amount = State(
            initialValue:
                NSDecimalNumber(
                    decimal: budget.totalAmount
                ).stringValue
        )

        _currency = State(
            initialValue: budget.currencyCode
        )

        _startDate = State(
            initialValue: budget.startDate
        )

        _endDate = State(
            initialValue: budget.endDate
        )

        _isRecurring = State(
            initialValue: budget.isRecurring
        )

        _recurrenceType = State(
            initialValue: budget.recurrenceType
        )
    }

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

                    Picker(
                        "Currency",
                        selection: $currency
                    ) {
                        ForEach(
                            currencies,
                            id: \.self
                        ) {
                            Text($0)
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

                    if isPartOfRecurringSeries {
                        Text(
                            "Period dates only apply to this individual budget."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
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
                    }
                }
            }

            .navigationTitle("Edit Budget")
            .navigationBarTitleDisplayMode(.inline)

            .toolbar {

                ToolbarItem(
                    placement: .cancellationAction
                ) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(
                    placement: .confirmationAction
                ) {
                    Button("Save") {

                        if isPartOfRecurringSeries {
                            showingSaveOptions = true
                        } else {
                            saveThisBudgetOnly()
                        }
                    }
                    .disabled(
                        name
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                            .isEmpty
                        ||
                        amount.isEmpty
                    )
                }
            }

            .confirmationDialog(
                "Apply Changes",
                isPresented: $showingSaveOptions,
                titleVisibility: .visible
            ) {

                Button("This Budget Only") {
                    saveThisBudgetOnly()
                }

                Button("This & Future Budgets") {
                    saveThisAndFutureBudgets()
                }

                Button(
                    "Cancel",
                    role: .cancel
                ) { }

            } message: {

                Text(
                    "Choose whether these changes should affect only this period or this period and future periods in the recurring series."
                )
            }
        }
    }

    private var isPartOfRecurringSeries: Bool {

        allBudgets.contains {
            otherBudget in

            otherBudget.seriesID ==
                budget.seriesID
            &&
            otherBudget.persistentModelID !=
                budget.persistentModelID
        }
        ||
        budget.isRecurring
    }

    private func parsedAmount() -> Decimal? {

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

    private func saveThisBudgetOnly() {

        guard
            let decimalAmount =
                parsedAmount()
        else {
            return
        }

        budget.name =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        budget.totalAmount =
            decimalAmount

        budget.currencyCode =
            currency

        budget.startDate =
            startDate

        budget.endDate =
            endDate

        budget.isRecurring =
            isRecurring

        budget.recurrenceType =
            recurrenceType

        dismiss()
    }

    private func saveThisAndFutureBudgets() {

        guard
            let decimalAmount =
                parsedAmount()
        else {
            return
        }

        let cleanedName =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let futureBudgets =
            allBudgets.filter {
                otherBudget in

                otherBudget.seriesID ==
                    budget.seriesID
                &&
                otherBudget.startDate >=
                    budget.startDate
            }

        for item in futureBudgets {

            item.name =
                cleanedName

            item.totalAmount =
                decimalAmount

            item.currencyCode =
                currency

            item.isRecurring =
                isRecurring

            item.recurrenceType =
                recurrenceType
        }

        // Dates belong only to the period currently being edited.
        budget.startDate =
            startDate

        budget.endDate =
            endDate

        dismiss()
    }
}
