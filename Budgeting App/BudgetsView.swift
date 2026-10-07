import SwiftUI
import SwiftData

struct BudgetsView: View {

    @Environment(\.modelContext)
    private var modelContext

    @Query(sort: \Budget.createdAt)
    private var budgets: [Budget]

    @Query
    private var transactions: [ExpenseTransaction]

    @State private var showingCreateBudget = false
    @State private var showingPastBudgets = false
    @State private var showingBudgetUpdateError = false

    var body: some View {

        NavigationStack {

            ScrollView {

                if budgets.isEmpty {

                    emptyState
                        .padding(.top, 120)

                } else {

                    LazyVStack(
                        alignment: .leading,
                        spacing: 24
                    ) {

                        if !currentBudgets.isEmpty {

                            budgetSection(
                                title: "Current",
                                systemImage: "calendar.badge.checkmark",
                                budgets: currentBudgets
                            )
                        }

                        if !upcomingBudgets.isEmpty {

                            budgetSection(
                                title: "Upcoming",
                                systemImage: "calendar",
                                budgets: upcomingBudgets
                            )
                        }

                        if !pastBudgets.isEmpty {

                            pastBudgetSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Budgets")

            .toolbar {

                ToolbarItem(
                    placement: .primaryAction
                ) {

                    Button {
                        showingCreateBudget = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }

            .sheet(
                isPresented: $showingCreateBudget
            ) {
                CreateBudgetView()
            }

            .onAppear {
                generateRecurringBudgetsIfNeeded()
            }
            .alert("Couldn’t update recurring budgets", isPresented: $showingBudgetUpdateError) {
                Button("Try Again") { generateRecurringBudgetsIfNeeded() }
                Button("Close", role: .cancel) { }
            } message: {
                Text("Your saved budgets are still available. Try again to create the current recurring periods.")
            }
        }
    }

    // MARK: - Budget Groups

    private var currentBudgets: [Budget] {

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return budgets
            .filter { budget in

                let start =
                    calendar.startOfDay(
                        for: budget.startDate
                    )

                let end =
                    calendar.startOfDay(
                        for: budget.endDate
                    )

                return today >= start &&
                    today <= end
            }
            .sorted {
                $0.endDate < $1.endDate
            }
    }

    private var upcomingBudgets: [Budget] {

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return budgets
            .filter { budget in

                let start =
                    calendar.startOfDay(
                        for: budget.startDate
                    )

                return start > today
            }
            .sorted {
                $0.startDate < $1.startDate
            }
    }

    private var pastBudgets: [Budget] {

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return budgets
            .filter { budget in

                let end =
                    calendar.startOfDay(
                        for: budget.endDate
                    )

                return end < today
            }
            .sorted {
                $0.endDate > $1.endDate
            }
    }

    // MARK: - Sections

    private func budgetSection(
        title: String,
        systemImage: String,
        budgets: [Budget]
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            Label(
                title,
                systemImage: systemImage
            )
            .font(.headline)

            ForEach(budgets) { budget in

                NavigationLink {

                    BudgetDetailView(
                        budget: budget
                    )

                } label: {

                    budgetCard(
                        budget
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var pastBudgetSection: some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            Button {

                withAnimation {
                    showingPastBudgets.toggle()
                }

            } label: {

                HStack {

                    Label(
                        "Past",
                        systemImage: "clock.arrow.circlepath"
                    )
                    .font(.headline)
                    .foregroundStyle(.primary)

                    Text(
                        "\(pastBudgets.count)"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial)
                    .clipShape(Capsule())

                    Spacer()

                    Image(
                        systemName:
                            showingPastBudgets
                            ? "chevron.up"
                            : "chevron.down"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if showingPastBudgets {

                ForEach(pastBudgets) { budget in

                    NavigationLink {

                        BudgetDetailView(
                            budget: budget
                        )

                    } label: {

                        budgetCard(
                            budget
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {

        VStack(spacing: 16) {

            Image(
                systemName: "chart.pie"
            )
            .font(.system(size: 46))
            .foregroundStyle(.secondary)

            Text("No Budgets Yet")
                .font(.title3)
                .fontWeight(.semibold)

            Text(
                "Create a budget to start planning your spending."
            )
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)

            Button("Create Budget") {
                showingCreateBudget = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Budget Card

    private func budgetCard(
        _ budget: Budget
    ) -> some View {

        let spent =
            spentAmount(
                for: budget
            )

        let remaining =
            budget.totalAmount - spent

        let actualProgress =
            progressForBudget(
                budget,
                spent: spent
            )

        let visualProgress =
            min(
                max(actualProgress, 0),
                1
            )

        let isOverBudget =
            spent > budget.totalAmount

        return VStack(
            alignment: .leading,
            spacing: 14
        ) {

            HStack(
                alignment: .top
            ) {

                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {

                    Text(budget.name)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(
                        "\(budget.startDate.formatted(date: .abbreviated, time: .omitted)) – \(budget.endDate.formatted(date: .abbreviated, time: .omitted))"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(
                    alignment: .trailing,
                    spacing: 7
                ) {

                    statusBadge(
                        for: budget
                    )

                    HStack(spacing: 4) {

                        if budget.isRecurring {

                            Image(
                                systemName:
                                    "arrow.triangle.2.circlepath"
                            )
                        }

                        Text(
                            budget.currencyCode
                        )
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }

            VStack(
                alignment: .leading,
                spacing: 8
            ) {

                HStack {

                    Text("Spent")

                    Spacer()

                    Text(
                        spent,
                        format: .number
                    )
                    .fontWeight(.medium)
                }

                ProgressView(
                    value: visualProgress
                )

                HStack {

                    Text(
                        isOverBudget
                        ? "Over Budget"
                        : "Remaining"
                    )

                    Spacer()

                    Text(
                        isOverBudget
                        ? -remaining
                        : remaining,
                        format: .number
                    )
                    .fontWeight(.semibold)
                }

                HStack {

                    Text(
                        "\(Int(actualProgress * 100))% used"
                    )
                    .foregroundStyle(
                        isOverBudget
                        ? .red
                        : .secondary
                    )

                    Spacer()

                    Text(
                        budget.totalAmount,
                        format: .number
                    )

                    Text(
                        budget.currencyCode
                    )
                }
                .font(.caption)
                .foregroundStyle(
                    isOverBudget
                    ? .red
                    : .secondary
                )
            }
            .font(.subheadline)
        }
        .padding()
        .background(.background)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20
            )
        )
        .shadow(
            color: .black.opacity(0.06),
            radius: 10,
            y: 4
        )
    }

    // MARK: - Status

    private func statusBadge(
        for budget: Budget
    ) -> some View {

        let status =
            budgetStatus(
                for: budget
            )

        return Text(status.title)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(
                status.color
            )
            .padding(
                .horizontal,
                9
            )
            .padding(
                .vertical,
                5
            )
            .background(
                status.color.opacity(0.12)
            )
            .clipShape(
                Capsule()
            )
    }

    private func budgetStatus(
        for budget: Budget
    ) -> (
        title: String,
        color: Color
    ) {

        let calendar =
            Calendar.current

        let today =
            calendar.startOfDay(
                for: Date()
            )

        let start =
            calendar.startOfDay(
                for: budget.startDate
            )

        let end =
            calendar.startOfDay(
                for: budget.endDate
            )

        if today < start {

            return (
                "Upcoming",
                .blue
            )

        } else if today > end {

            return (
                "Ended",
                .secondary
            )

        } else {

            return (
                "Active",
                .green
            )
        }
    }

    // MARK: - Recurring Budgets

    private func generateRecurringBudgetsIfNeeded() {
        do {
            try BudgetSchedule.generateIfNeeded(context: modelContext)
        } catch {
            showingBudgetUpdateError = true
        }
    }

    // MARK: - Spending Calculation

    private func matchingTransactions(
        for budget: Budget
    ) -> [ExpenseTransaction] {

        let calendar =
            Calendar.current

        let start =
            calendar.startOfDay(
                for: budget.startDate
            )

        let endStart =
            calendar.startOfDay(
                for: budget.endDate
            )

        let dayAfterEnd =
            calendar.date(
                byAdding: .day,
                value: 1,
                to: endStart
            ) ?? budget.endDate

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

            let categoryMatches =
                budget.categories.contains {
                    $0.persistentModelID ==
                    category.persistentModelID
                }

            let dateMatches =
                transaction.date >= start &&
                transaction.date < dayAfterEnd

            let currencyMatches =
                wallet.currencyCode ==
                budget.currencyCode

            return
                categoryMatches &&
                dateMatches &&
                currencyMatches
        }
    }

    private func spentAmount(
        for budget: Budget
    ) -> Decimal {

        matchingTransactions(
            for: budget
        )
        .reduce(
            Decimal.zero
        ) {
            $0 + $1.amount
        }
    }

    private func progressForBudget(
        _ budget: Budget,
        spent: Decimal
    ) -> Double {

        guard
            budget.totalAmount > 0
        else {
            return 0
        }

        let decimalProgress =
            spent /
            budget.totalAmount

        return NSDecimalNumber(
            decimal:
                decimalProgress
        ).doubleValue
    }
}
