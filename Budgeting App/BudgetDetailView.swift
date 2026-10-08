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
                Text(budget.name).font(.headline)
                BudgetProgressSummary(presentation: BudgetPresentation(budget: budget, transactions: transactions))
                    .padding(.vertical, 8)
            }
            Section("Budget") {
                ReadableDetailRow(title: "Total", value: budget.totalAmount.formatted(.currency(code: budget.currencyCode)))
                ReadableDetailRow(title: "Start", value: budget.startDate.formatted(date: .long, time: .omitted))
                ReadableDetailRow(title: "End", value: budget.endDate.formatted(date: .long, time: .omitted))
                if budget.isRecurring {
                    ReadableDetailRow(title: "Repeat", value: budget.recurrenceType)
                }
            }
            if previousPeriod != nil || nextPeriod != nil {
                Section("Other Periods") {
                    if let previousPeriod {
                        NavigationLink { BudgetDetailView(budget: previousPeriod) } label: {
                            periodLabel("Previous Period", budget: previousPeriod, symbol: "chevron.left")
                        }
                        .accessibilityIdentifier("previousBudgetPeriod")
                    }
                    if let nextPeriod {
                        NavigationLink { BudgetDetailView(budget: nextPeriod) } label: {
                            periodLabel("Next Period", budget: nextPeriod, symbol: "chevron.right")
                        }
                        .accessibilityIdentifier("nextBudgetPeriod")
                    }
                }
            }
            Section("Categories") {
                if budget.categories.isEmpty {
                    Label("Choose categories to include their spending in this budget.", systemImage: "tag")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedCategories) { category in
                        AdaptiveValueRow {
                            Label(category.name, systemImage: category.icon)
                                .foregroundStyle(FormPalette.color(category.colorName))
                        } trailing: {
                            Text(spendingForCategory(category).formatted(.currency(code: budget.currencyCode)))
                                .fontWeight(.medium).monospacedDigit()
                        }
                    }
                }
                Button { showingCategoryPicker = true } label: {
                    Label("Manage Categories", systemImage: "checklist")
                }
                .accessibilityIdentifier("manageBudgetCategories")
            }
            Section {
                Button("Delete Budget", role: .destructive) { showingDeleteOptions = true }
            } footer: {
                Text("Deleting a budget will not delete any transactions.")
            }
        }
        .listStyle(.insetGrouped)

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

    private var previousPeriod: Budget? { BudgetPresentation.adjacentPeriods(of: budget, in: allBudgets).previous }
    private var nextPeriod: Budget? { BudgetPresentation.adjacentPeriods(of: budget, in: allBudgets).next }
    private func periodLabel(_ title: String, budget: Budget, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: symbol).font(.subheadline.weight(.semibold))
            Text("\(budget.startDate.formatted(date: .abbreviated, time: .omitted)) – \(budget.endDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
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
