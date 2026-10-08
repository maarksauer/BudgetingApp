import SwiftUI
import SwiftData

struct BudgetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Budget.createdAt) private var budgets: [Budget]
    @Query private var transactions: [ExpenseTransaction]
    @State private var selectedPeriod: BudgetListPeriod = .current
    @State private var showingCreateBudget = false
    @State private var showingBudgetUpdateError = false
    private let embedded: Bool

    init(embedded: Bool = false) { self.embedded = embedded }

    var body: some View {
        if embedded { content } else { NavigationStack { content } }
    }

    private var content: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    if budgets.isEmpty {
                        budgetEmptyState(title: "No Budgets Yet", message: "Set a spending limit and choose the categories you want to track.", showAll: false)
                    } else {
                        periodButtons
                        let visible = BudgetPresentation.budgets(budgets, in: selectedPeriod, now: timeline.date)
                        Text("\(visible.count) \(visible.count == 1 ? "budget" : "budgets") · \(selectedPeriod.rawValue)")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .accessibilityIdentifier("budgetResultCount")
                        if visible.isEmpty {
                            budgetEmptyState(title: "No \(selectedPeriod.rawValue) Budgets",
                                             message: selectedPeriod.emptyMessage, showAll: true)
                        } else {
                            ForEach(visible) { budget in
                                NavigationLink { BudgetDetailView(budget: budget) } label: {
                                    BudgetSummaryCard(budget: budget, transactions: transactions, now: timeline.date)
                                }
                                .buttonStyle(.plain).accessibilityIdentifier("budgetRow-\(budget.name)")
                            }
                        }
                    }
                }
                .padding(20).frame(maxWidth: 700).frame(maxWidth: .infinity)
            }
            .background(Color.primary.opacity(0.04))
            .task(id: Calendar.current.startOfDay(for: timeline.date)) { generateRecurringBudgetsIfNeeded() }
        }
        .navigationTitle("Budgets")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingCreateBudget = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add Budget").accessibilityIdentifier("openCreateBudget")
            }
        }
        .sheet(isPresented: $showingCreateBudget) { CreateBudgetView() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { generateRecurringBudgetsIfNeeded() }
        }
        .alert("Couldn’t update recurring budgets", isPresented: $showingBudgetUpdateError) {
            Button("Try Again") { generateRecurringBudgetsIfNeeded() }
            Button("Close", role: .cancel) { }
        } message: {
            Text("Your saved budgets are still available. Try again to create the current recurring periods.")
        }
    }

    private var periodButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(BudgetListPeriod.allCases) { period in
                    Button { selectedPeriod = period } label: {
                        Text(period.rawValue)
                            .font(.subheadline.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 12)
                            .foregroundStyle(selectedPeriod == period ? Color.white : Color.primary)
                            .background(selectedPeriod == period ? Color.accentColor : Color.secondary.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain).accessibilityAddTraits(selectedPeriod == period ? .isSelected : [])
                    .accessibilityIdentifier("budgetPeriod-\(period.rawValue)")
                }
            }
        }
        .accessibilityIdentifier("budgetPeriodTabs")
    }

    private func budgetEmptyState(title: String, message: String, showAll: Bool) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: "chart.pie")
        } description: {
            Text(message)
        } actions: {
            Button("Create Budget") { showingCreateBudget = true }
                .buttonStyle(.borderedProminent).accessibilityIdentifier("createBudgetFromEmptyState")
            if showAll {
                Button("Show All Budgets") { selectedPeriod = .all }
                    .accessibilityIdentifier("showAllBudgets")
            }
        }
        .accessibilityIdentifier("budgetEmptyState")
    }

    private func generateRecurringBudgetsIfNeeded() {
        do { try BudgetSchedule.generateIfNeeded(context: modelContext) }
        catch { showingBudgetUpdateError = true }
    }
}

nonisolated enum BudgetListPeriod: String, CaseIterable, Identifiable {
    case current = "Current", upcoming = "Upcoming", past = "Past", all = "All"
    var id: String { rawValue }
    var emptyMessage: String {
        switch self {
        case .current: "No budgets cover today. Create one or browse your other periods."
        case .upcoming: "Budgets that start after today will appear here."
        case .past: "Finished budget periods will appear here."
        case .all: "Create a budget to start planning your spending."
        }
    }
}

struct BudgetPresentation {
    let budget: Budget
    let spent: Decimal
    let now: Date
    let calendar: Calendar

    init(budget: Budget, transactions: [ExpenseTransaction], now: Date = .now, calendar: Calendar = .current) {
        self.budget = budget
        self.spent = DashboardMetrics.spent(for: budget, transactions: transactions, calendar: calendar)
        self.now = now
        self.calendar = calendar
    }

    var remaining: Decimal { budget.totalAmount - spent }
    var isOverBudget: Bool { remaining < 0 }
    var displayRemaining: Decimal { isOverBudget ? -remaining : remaining }
    var progress: Double {
        guard budget.totalAmount > 0 else { return 0 }
        let ratio = NSDecimalNumber(decimal: spent / budget.totalAmount).doubleValue
        return ratio.isFinite ? max(ratio, 0) : 0
    }
    var visualProgress: Double { min(progress, 1) }
    var spendingStatus: String {
        if isOverBudget { return "Over Budget" }
        if remaining == 0 { return "Limit Reached" }
        if progress >= 0.8 { return "Near Limit" }
        return "Within Budget"
    }
    var tint: Color {
        if isOverBudget { return .red }
        if remaining == 0 || progress >= 0.8 { return .orange }
        return .blue
    }
    var period: BudgetListPeriod { Self.period(for: budget, now: now, calendar: calendar) }
    var timingLabel: String {
        switch period {
        case .upcoming: return "Starts \(budget.startDate.formatted(date: .abbreviated, time: .omitted))"
        case .past: return "Ended \(budget.endDate.formatted(date: .abbreviated, time: .omitted))"
        case .current, .all:
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: budget.endDate)).day ?? 0
            return days == 0 ? "Ends today" : (days == 1 ? "1 day left" : "\(days) days left")
        }
    }

    static func period(for budget: Budget, now: Date, calendar: Calendar = .current) -> BudgetListPeriod {
        let today = calendar.startOfDay(for: now)
        if today < calendar.startOfDay(for: budget.startDate) { return .upcoming }
        if today > calendar.startOfDay(for: budget.endDate) { return .past }
        return .current
    }

    static func adjacentPeriods(of budget: Budget, in budgets: [Budget]) -> (previous: Budget?, next: Budget?) {
        let periods = budgets.filter { $0.seriesID == budget.seriesID }.sorted {
            if $0.startDate == $1.startDate { return String(describing: $0.persistentModelID) < String(describing: $1.persistentModelID) }
            return $0.startDate < $1.startDate
        }
        guard let index = periods.firstIndex(where: { $0.persistentModelID == budget.persistentModelID }) else { return (nil, nil) }
        return (index > 0 ? periods[index - 1] : nil, index + 1 < periods.count ? periods[index + 1] : nil)
    }

    static func budgets(_ budgets: [Budget], in period: BudgetListPeriod, now: Date, calendar: Calendar = .current) -> [Budget] {
        budgets.filter { period == .all || Self.period(for: $0, now: now, calendar: calendar) == period }
            .sorted { lhs, rhs in
                let left = period == .upcoming ? lhs.startDate : lhs.endDate
                let right = period == .upcoming ? rhs.startDate : rhs.endDate
                if left == right { return String(describing: lhs.persistentModelID) < String(describing: rhs.persistentModelID) }
                return period == .past || period == .all ? left > right : left < right
            }
    }
}

struct BudgetSummaryCard: View {
    let budget: Budget
    let transactions: [ExpenseTransaction]
    var now: Date = .now

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AdaptiveValueRow {
                VStack(alignment: .leading, spacing: 5) {
                    Text(budget.name).font(.headline)
                    Text("\(budget.startDate.formatted(date: .abbreviated, time: .omitted)) – \(budget.endDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } trailing: {
                Label(budget.currencyCode, systemImage: budget.isRecurring ? "arrow.triangle.2.circlepath" : "banknote")
                    .font(.caption).foregroundStyle(.secondary)
            }
            BudgetProgressSummary(presentation: BudgetPresentation(budget: budget, transactions: transactions, now: now))
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(Color.primary.opacity(0.1), lineWidth: 1) }
    }
}

struct BudgetProgressSummary: View {
    let presentation: BudgetPresentation
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AdaptiveValueRow {
                Label(presentation.spendingStatus, systemImage: presentation.isOverBudget ? "exclamationmark.triangle.fill" : "chart.pie.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(presentation.tint)
            } trailing: {
                Text(presentation.timingLabel).font(.caption).foregroundStyle(.secondary)
            }
            ProgressView(value: presentation.visualProgress).tint(presentation.tint)
                .accessibilityLabel("Budget used").accessibilityValue(presentation.progress.formatted(.percent.precision(.fractionLength(0))))
            AdaptiveValueRow {
                amount("Spent", value: presentation.spent)
            } trailing: {
                amount(presentation.isOverBudget ? "Over Budget" : "Remaining", value: presentation.displayRemaining)
            }
            Text("\(presentation.progress.formatted(.percent.precision(.fractionLength(0)))) of \(presentation.budget.totalAmount.formatted(.currency(code: presentation.budget.currencyCode))) used")
                .font(.caption).foregroundStyle(.secondary)
            if presentation.isOverBudget {
                Label("Exceeded by \(presentation.displayRemaining.formatted(.currency(code: presentation.budget.currencyCode)))", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.medium)).foregroundStyle(.red)
                    .accessibilityIdentifier("budgetOverspendingWarning")
            }
            if presentation.budget.categories.isEmpty {
                Label("Choose categories to track spending.", systemImage: "tag")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func amount(_ title: String, value: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value.formatted(.currency(code: presentation.budget.currencyCode)))
                .font(.title3.weight(.semibold)).monospacedDigit()
                .foregroundStyle(presentation.isOverBudget && title == "Over Budget" ? Color.red : Color.primary)
        }
    }
}
