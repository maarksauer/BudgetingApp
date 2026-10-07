import SwiftUI
import SwiftData

struct BudgetDetailView: View {

    @Environment(\.modelContext)
    private var modelContext

    @Environment(\.dismiss)
    private var dismiss

    @Query
    private var transactions: [ExpenseTransaction]

    @Query
    private var allBudgets: [Budget]

    let budget: Budget

    @State private var showingCategoryPicker = false
    @State private var showingEditBudget = false
    @State private var showingDeleteOptions = false

    var body: some View {

        List {

            Section {

                VStack(
                    alignment: .leading,
                    spacing: 14
                ) {

                    HStack {

                        VStack(
                            alignment: .leading,
                            spacing: 4
                        ) {

                            Text("Spent")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(
                                spentAmount,
                                format: .number
                            )
                            .font(.title2)
                            .fontWeight(.semibold)
                        }

                        Spacer()

                        VStack(
                            alignment: .trailing,
                            spacing: 4
                        ) {

                            Text(
                                remainingAmount >= 0
                                ? "Remaining"
                                : "Over Budget"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            Text(
                                displayRemainingAmount,
                                format: .number
                            )
                            .font(.title2)
                            .fontWeight(.semibold)
                        }
                    }

                    ProgressView(
                        value: visualProgress
                    )

                    HStack {

                        Text(
                            "\(Int(actualProgress * 100))% used"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            isOverBudget
                            ? .red
                            : .secondary
                        )

                        Spacer()

                        Text(budget.currencyCode)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if isOverBudget {

                        Label(
                            "Budget exceeded by \(displayRemainingAmount.formatted(.number)) \(budget.currencyCode)",
                            systemImage:
                                "exclamationmark.triangle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Budget") {

                HStack {

                    Text("Total")

                    Spacer()

                    Text(
                        budget.totalAmount,
                        format: .number
                    )
                    .fontWeight(.semibold)

                    Text(
                        budget.currencyCode
                    )
                    .foregroundStyle(.secondary)
                }

                HStack {

                    Text("Start")

                    Spacer()

                    Text(
                        budget.startDate,
                        format:
                            .dateTime
                            .day()
                            .month()
                            .year()
                    )
                    .foregroundStyle(.secondary)
                }

                HStack {

                    Text("End")

                    Spacer()

                    Text(
                        budget.endDate,
                        format:
                            .dateTime
                            .day()
                            .month()
                            .year()
                    )
                    .foregroundStyle(.secondary)
                }

                if budget.isRecurring {

                    HStack {

                        Text("Repeat")

                        Spacer()

                        Label(
                            budget.recurrenceType,
                            systemImage:
                                "arrow.triangle.2.circlepath"
                        )
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Categories") {

                if budget.categories.isEmpty {

                    Text(
                        "No categories selected"
                    )
                    .foregroundStyle(.secondary)

                } else {

                    ForEach(
                        sortedCategories
                    ) { category in

                        HStack(spacing: 12) {

                            Image(
                                systemName:
                                    category.icon
                            )
                            .foregroundStyle(.white)
                            .frame(
                                width: 36,
                                height: 36
                            )
                            .background(
                                colorFromName(
                                    category.colorName
                                )
                            )
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 10
                                )
                            )

                            Text(
                                category.name
                            )

                            Spacer()

                            Text(
                                spendingForCategory(
                                    category
                                ),
                                format: .number
                            )
                            .fontWeight(.medium)

                            Text(
                                budget.currencyCode
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                Button {

                    showingCategoryPicker = true

                } label: {

                    Label(
                        "Manage Categories",
                        systemImage: "checklist"
                    )
                }
            }

            Section {

                Button(
                    "Delete Budget",
                    role: .destructive
                ) {
                    showingDeleteOptions = true
                }

            } footer: {

                Text(
                    "Deleting a budget will not delete any transactions."
                )
            }
        }

        .navigationTitle(
            budget.name
        )

        .navigationBarTitleDisplayMode(
            .inline
        )

        .toolbar {

            ToolbarItem(
                placement: .primaryAction
            ) {

                Button("Edit") {
                    showingEditBudget = true
                }
            }
        }

        .sheet(
            isPresented:
                $showingCategoryPicker
        ) {

            BudgetCategoryPickerView(
                budget: budget
            )
        }

        .sheet(
            isPresented:
                $showingEditBudget
        ) {

            EditBudgetView(
                budget: budget
            )
        }

        .confirmationDialog(
            "Delete \(budget.name)?",
            isPresented:
                $showingDeleteOptions,
            titleVisibility:
                .visible
        ) {

            if isPartOfRecurringSeries {

                Button(
                    "Delete This Budget",
                    role: .destructive
                ) {
                    deleteThisBudgetOnly()
                }

                Button(
                    "Delete This & Future Budgets",
                    role: .destructive
                ) {
                    deleteThisAndFutureBudgets()
                }

            } else {

                Button(
                    "Delete Budget",
                    role: .destructive
                ) {
                    deleteThisBudgetOnly()
                }
            }

            Button(
                "Cancel",
                role: .cancel
            ) { }

        } message: {

            if isPartOfRecurringSeries {

                Text(
                    "Choose whether to delete only this period or this period and all future periods in the recurring series."
                )

            } else {

                Text(
                    "Your transactions will remain unchanged."
                )
            }
        }
    }

    // MARK: - Recurring Series

    private var isPartOfRecurringSeries: Bool {

        budget.isRecurring
        ||
        allBudgets.contains {
            otherBudget in

            otherBudget.seriesID ==
                budget.seriesID
            &&
            otherBudget.persistentModelID !=
                budget.persistentModelID
        }
    }

    private func deleteThisBudgetOnly() {

        modelContext.delete(
            budget
        )

        dismiss()
    }

    private func deleteThisAndFutureBudgets() {

        let budgetsToDelete =
            allBudgets.filter {
                otherBudget in

                otherBudget.seriesID ==
                    budget.seriesID
                &&
                otherBudget.startDate >=
                    budget.startDate
            }

        let previousBudgets =
            allBudgets.filter {
                otherBudget in

                otherBudget.seriesID ==
                    budget.seriesID
                &&
                otherBudget.startDate <
                    budget.startDate
            }

        for previousBudget in previousBudgets {
            previousBudget.isRecurring = false
        }

        for item in budgetsToDelete {
            modelContext.delete(
                item
            )
        }

        dismiss()
    }

    // MARK: - Categories

    private var sortedCategories:
        [SpendingCategory] {

        budget.categories.sorted {

            $0.name
                .localizedCaseInsensitiveCompare(
                    $1.name
                )
            ==
            .orderedAscending
        }
    }

    // MARK: - Transactions

    private var matchingTransactions:
        [ExpenseTransaction] {

        let calendar =
            Calendar.current

        let start =
            calendar.startOfDay(
                for:
                    budget.startDate
            )

        let endStart =
            calendar.startOfDay(
                for:
                    budget.endDate
            )

        let dayAfterEnd =
            calendar.date(
                byAdding: .day,
                value: 1,
                to: endStart
            )
            ?? budget.endDate

        return transactions.filter {
            transaction in

            guard
                !transaction.isIncome,
                let category =
                    transaction.category,
                let wallet =
                    transaction.wallet
            else {
                return false
            }

            let categoryIsIncluded =
                budget.categories.contains {

                    $0.persistentModelID ==
                        category.persistentModelID
                }

            let dateIsIncluded =
                transaction.date >=
                    start
                &&
                transaction.date <
                    dayAfterEnd

            let currencyMatches =
                wallet.currencyCode ==
                    budget.currencyCode

            return
                categoryIsIncluded
                &&
                dateIsIncluded
                &&
                currencyMatches
        }
    }

    private var spentAmount:
        Decimal {

        matchingTransactions
            .reduce(
                Decimal.zero
            ) {
                $0 + $1.amount
            }
    }

    private var remainingAmount:
        Decimal {

        budget.totalAmount -
            spentAmount
    }

    private var displayRemainingAmount:
        Decimal {

        if remainingAmount < 0 {
            return -remainingAmount
        }

        return remainingAmount
    }

    private var actualProgress:
        Double {

        guard
            budget.totalAmount > 0
        else {
            return 0
        }

        let decimalProgress =
            spentAmount /
            budget.totalAmount

        return NSDecimalNumber(
            decimal:
                decimalProgress
        ).doubleValue
    }

    private var visualProgress:
        Double {

        min(
            max(
                actualProgress,
                0
            ),
            1
        )
    }

    private var isOverBudget:
        Bool {

        spentAmount >
            budget.totalAmount
    }

    private func spendingForCategory(
        _ category:
            SpendingCategory
    ) -> Decimal {

        matchingTransactions
            .filter {

                $0.category?
                    .persistentModelID
                ==
                category.persistentModelID
            }
            .reduce(
                Decimal.zero
            ) {
                $0 + $1.amount
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


struct BudgetCategoryPickerView: View {

    @Environment(\.dismiss)
    private var dismiss

    @Query(
        sort:
            \SpendingCategory.name
    )
    private var categories:
        [SpendingCategory]

    let budget: Budget

    var body: some View {

        NavigationStack {

            List(
                categories
            ) { category in

                Button {

                    toggleCategory(
                        category
                    )

                } label: {

                    HStack(
                        spacing: 14
                    ) {

                        Image(
                            systemName:
                                category.icon
                        )
                        .foregroundStyle(
                            colorFromName(
                                category.colorName
                            )
                        )
                        .frame(width: 28)

                        Text(
                            category.name
                        )
                        .foregroundStyle(
                            .primary
                        )

                        Spacer()

                        if isSelected(
                            category
                        ) {

                            Image(
                                systemName:
                                    "checkmark.circle.fill"
                            )
                            .foregroundStyle(
                                .tint
                            )

                        } else {

                            Image(
                                systemName:
                                    "circle"
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }
                    }
                }
            }

            .navigationTitle(
                "Budget Categories"
            )

            .navigationBarTitleDisplayMode(
                .inline
            )

            .toolbar {

                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {

                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func isSelected(
        _ category:
            SpendingCategory
    ) -> Bool {

        budget.categories.contains {

            $0.persistentModelID ==
                category.persistentModelID
        }
    }

    private func toggleCategory(
        _ category:
            SpendingCategory
    ) {

        if isSelected(
            category
        ) {

            budget.categories.removeAll {

                $0.persistentModelID ==
                    category.persistentModelID
            }

        } else {

            budget.categories.append(
                category
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
