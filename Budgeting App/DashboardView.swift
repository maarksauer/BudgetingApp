import SwiftUI
import SwiftData
import Foundation

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \Wallet.createdAt) private var wallets: [Wallet]
    @Query private var transactions: [ExpenseTransaction]
    @Query private var transfers: [WalletTransfer]
    @Query private var budgets: [Budget]
    @Query private var payments: [RecurringPayment]

    let openTransactions: () -> Void
    let openBudgets: () -> Void
    let openWallets: () -> Void

    @State private var showingCreateWallet = false
    @State private var showingBudgetUpdateError = false

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        monthlySpendingCard(now: timeline.date)
                        monthlyIncomeCard(now: timeline.date)
                        walletSection
                        recentActivitySection(now: timeline.date)
                        categorySpendingSection(now: timeline.date)
                        budgetSection(now: timeline.date)
                        paymentSection(now: timeline.date)
                    }
                    .padding(20)
                    .frame(maxWidth: 700)
                    .frame(maxWidth: .infinity)
                }
                .background(Color.primary.opacity(0.04))
                .task(id: Calendar.current.startOfDay(for: timeline.date)) {
                    refreshRecurringBudgets(now: timeline.date)
                }
            }
            .navigationTitle("Overview")
            .sheet(isPresented: $showingCreateWallet) {
                CreateWalletView()
            }
            .alert("Couldn’t update recurring budgets", isPresented: $showingBudgetUpdateError) {
                Button("Try Again") { refreshRecurringBudgets(now: .now) }
                Button("Close", role: .cancel) { }
            } message: {
                Text("Your saved budgets are still available. Try again to create the current recurring periods.")
            }
            .onChange(of: scenePhase) {
                if scenePhase == .active {
                    refreshRecurringBudgets(now: .now)
                }
            }
        }
    }

    private func monthlySpendingCard(now: Date) -> some View {
        let totals = DashboardMetrics.monthlySpending(
            transactions: transactions, wallets: wallets, now: now
        )
        let unassignedCount = DashboardMetrics.monthlyTransactions(transactions, now: now)
            .filter { !$0.isIncome && $0.wallet == nil }.count

        return DashboardCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Spent this month", systemImage: "chart.bar.fill")
                        .font(.headline)
                        .foregroundStyle(.blue)
                    Spacer()
                    Button(action: openTransactions) {
                        Image(systemName: "arrow.up.right")
                    }
                    .accessibilityLabel("View transactions")
                }

                Text(now.formatted(.dateTime.month(.wide).year()))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if totals.isEmpty {
                    Text(unassignedCount == 0 ? "No expenses this month" : "No wallet totals available")
                        .font(.title2.weight(.semibold))
                } else {
                    ForEach(totals) { total in
                        AdaptiveValueRow {
                            Text(total.amount, format: .currency(code: total.currencyCode))
                                .font(.largeTitle.weight(.bold))
                                .monospacedDigit()
                        } trailing: {
                            Text(total.currencyCode)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if unassignedCount > 0 {
                    Text("\(unassignedCount) expenses have no wallet and are excluded from these totals.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier("monthlySpendingSummary")
    }

    private func monthlyIncomeCard(now: Date) -> some View {
        let income = DashboardMetrics.monthlyIncome(
            transactions: transactions, wallets: wallets, now: now
        )
        let cashFlow = DashboardMetrics.monthlyNetCashFlow(
            transactions: transactions, wallets: wallets, now: now
        )
        let unassignedCount = DashboardMetrics.monthlyTransactions(transactions, now: now)
            .filter { $0.isIncome && $0.wallet == nil }.count

        return DashboardCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Income this month", systemImage: "arrow.down.left.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)

                if income.isEmpty {
                    Text(unassignedCount == 0 ? "No income this month" : "No wallet totals available")
                        .font(.title2.weight(.semibold))
                } else {
                    ForEach(income) { total in
                        AdaptiveValueRow {
                            Text(total.amount, format: .currency(code: total.currencyCode))
                                .font(.title.weight(.bold))
                                .monospacedDigit()
                        } trailing: {
                            Text(total.currencyCode)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Divider()
                    Text("Net cash flow")
                        .font(.subheadline.weight(.semibold))
                    ForEach(cashFlow) { total in
                        AdaptiveValueRow {
                            Text(total.currencyCode)
                                .foregroundStyle(.secondary)
                        } trailing: {
                            Text(total.amount, format: .currency(code: total.currencyCode))
                                .fontWeight(.semibold)
                                .monospacedDigit()
                                .foregroundStyle(total.amount < 0 ? Color.red : Color.green)
                        }
                    }
                    Text("Income minus expenses. Wallet transfers are excluded.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if unassignedCount > 0 {
                    Text("\(unassignedCount) income transactions have no wallet and are excluded from these totals.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier("monthlyIncomeSummary")
    }

    private var walletSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("Wallets", action: openWallets)
            DashboardCard {
                if wallets.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Start with a wallet", systemImage: "wallet.bifold")
                            .font(.headline)
                        Text("Add your cash or bank account to start tracking your income and spending.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Create Wallet") { showingCreateWallet = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    VStack(spacing: 16) {
                        ForEach(Array(wallets.prefix(4))) { wallet in
                            NavigationLink {
                                WalletDetailView(wallet: wallet)
                            } label: {
                                AdaptiveValueRow {
                                    Label(wallet.name, systemImage: wallet.icon)
                                        .foregroundStyle(color(named: wallet.colorName))
                                } trailing: {
                                    Text(DashboardMetrics.balance(for: wallet, transfers: transfers),
                                         format: .currency(code: wallet.currencyCode))
                                        .fontWeight(.semibold).monospacedDigit()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func budgetSection(now: Date) -> some View {
        let current = DashboardMetrics.currentBudgets(budgets, now: now)
        return VStack(alignment: .leading, spacing: 12) {
            sectionHeading("Current budgets", action: openBudgets)
            if current.isEmpty {
                DashboardCard {
                    Text("No active budgets. Create one to set a spending limit.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(Array(current.prefix(3))) { budget in
                    NavigationLink {
                        BudgetDetailView(budget: budget)
                    } label: {
                        budgetCard(budget, now: now)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func recentActivitySection(now: Date) -> some View {
        let recent = DashboardMetrics.recentActivity(
            transactions: transactions, transfers: transfers, now: now
        )
        return VStack(alignment: .leading, spacing: 12) {
            sectionHeading("Recent transactions", action: openTransactions)
            DashboardCard {
                if recent.isEmpty {
                    Text("Your income, expenses, and transfers will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 16) {
                        ForEach(recent) { activity in
                            recentActivityLink(activity)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("recentTransactionsSection")
    }

    @ViewBuilder
    private func recentActivityLink(_ activity: DashboardMetrics.RecentActivity) -> some View {
        switch activity {
        case .transaction(let transaction):
            NavigationLink {
                TransactionDetailView(transaction: transaction)
            } label: {
                recentTransactionRow(transaction)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("recentTransactionLink")
        case .transfer(let transfer):
            NavigationLink {
                TransferDetailView(transfer: transfer)
            } label: {
                recentTransferRow(transfer)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("recentTransferLink")
        }
    }

    private func recentTransactionRow(_ transaction: ExpenseTransaction) -> some View {
        let note = transaction.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = note.isEmpty ? (transaction.isIncome ? "Income" : transaction.subcategory?.name ?? transaction.category?.name ?? "Expense") : note
        return TransactionSummaryRow(
            title: title, subtitle: "\(transaction.typeName) · \(transaction.wallet?.name ?? "No wallet")",
            detail: transaction.date.formatted(date: .abbreviated, time: .omitted),
            symbol: transaction.isIncome ? "arrow.down.left" : transaction.category?.icon ?? "tag",
            tint: transaction.isIncome ? .green : color(named: transaction.category?.colorName ?? "gray"),
            amount: "\(transaction.amountSign)\(transaction.amount.formatted(.number))",
            currency: transaction.wallet?.currencyCode ?? "", secondaryAmount: nil)
    }

    private func recentTransferRow(_ transfer: WalletTransfer) -> some View {
        let note = transfer.note.trimmingCharacters(in: .whitespacesAndNewlines)
        return TransactionSummaryRow(
            title: note.isEmpty ? "Wallet transfer" : note,
            subtitle: "\(transfer.sourceWallet?.name ?? "Deleted wallet") → \(transfer.destinationWallet?.name ?? "Deleted wallet")",
            detail: "Transfer · \(transfer.date.formatted(date: .abbreviated, time: .omitted))",
            symbol: "arrow.left.arrow.right", tint: .blue,
            amount: "−\(transfer.sourceAmount.formatted(.number))", currency: transfer.sourceCurrencyCode,
            secondaryAmount: "+\(transfer.destinationAmount.formatted(.number)) \(transfer.destinationCurrencyCode)")
    }

    private func categorySpendingSection(now: Date) -> some View {
        let groups = DashboardMetrics.monthlyCategorySpending(transactions: transactions, now: now)
        let unassignedCount = DashboardMetrics.monthlyTransactions(transactions, now: now)
            .filter { !$0.isIncome && $0.wallet == nil }.count
        return VStack(alignment: .leading, spacing: 12) {
            Text("Spending by category").font(.title3.weight(.semibold))
            Text(now.formatted(.dateTime.month(.wide).year()))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if groups.isEmpty {
                DashboardCard {
                    Text(unassignedCount == 0 ? "No expenses this month." : "No wallet totals available.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(groups) { group in
                    DashboardCard {
                        VStack(alignment: .leading, spacing: 18) {
                            AdaptiveValueRow {
                                Text(group.currencyCode).font(.headline)
                            } trailing: {
                                Text(group.totalAmount, format: .currency(code: group.currencyCode))
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                            }
                            ForEach(group.categories) { category in
                                categorySpendingRow(category, currency: group.currencyCode, total: group.totalAmount)
                            }
                        }
                    }
                    .accessibilityIdentifier("categorySpending-\(group.currencyCode)")
                }
            }
            if unassignedCount > 0 {
                Text("\(unassignedCount) expenses have no wallet and are excluded from this breakdown.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("categorySpendingSection")
    }

    private func categorySpendingRow(
        _ category: DashboardMetrics.CategorySpending, currency: String, total: Decimal
    ) -> some View {
        let share = total > 0 ? NSDecimalNumber(decimal: category.amount / total).doubleValue : 0
        let tint = color(named: category.colorName)
        return VStack(alignment: .leading, spacing: 8) {
            AdaptiveValueRow {
                Label(category.name, systemImage: category.icon)
                    .foregroundStyle(tint)
            } trailing: {
                Text(category.amount, format: .currency(code: currency))
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            .font(.subheadline)
            HStack(spacing: 12) {
                ProgressView(value: min(max(share, 0), 1))
                    .tint(tint)
                    .accessibilityLabel("\(category.name) share of \(currency) spending")
                Text(share, format: .percent.precision(.fractionLength(0)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private func budgetCard(_ budget: Budget, now: Date) -> some View {
        BudgetSummaryCard(budget: budget, transactions: transactions, now: now)
    }

    private func paymentSection(now: Date) -> some View {
        let nextPayments = DashboardMetrics.nextPayments(payments)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming bills").font(.title3.weight(.semibold))
                Spacer()
                NavigationLink("See all") { RecurringPaymentsView() }
                    .font(.subheadline)
            }
            DashboardCard {
                if nextPayments.isEmpty {
                    Text("No active recurring payments.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 16) {
                        ForEach(Array(nextPayments.prefix(4))) { payment in
                            NavigationLink {
                                RecurringPaymentDetailView(payment: payment)
                            } label: {
                                paymentRow(payment, now: now)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func paymentRow(_ payment: RecurringPayment, now: Date) -> some View {
        let today = Calendar.current.startOfDay(for: now)
        return AdaptiveValueRow {
            VStack(alignment: .leading, spacing: 5) {
                Label(payment.name, systemImage: "calendar").fontWeight(.medium)
                Text(paymentDateText(payment, today: today)).font(.caption).foregroundStyle(.secondary)
            }
        } trailing: {
            VStack(alignment: .leading, spacing: 4) {
                Text(payment.amount.formatted(.number)).fontWeight(.semibold).monospacedDigit()
                Text(payment.wallet?.currencyCode ?? "No wallet selected").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func paymentDateText(_ payment: RecurringPayment, today: Date) -> String {
        let due = Calendar.current.startOfDay(for: payment.nextPaymentDate)
        if due < today { return "Overdue · \(payment.nextPaymentDate.formatted(date: .abbreviated, time: .omitted))" }
        if due == today { return "Due today" }
        let date = payment.nextPaymentDate.formatted(date: .abbreviated, time: .omitted)
        return payment.isPostponed ? "Postponed to \(date)" : "Due \(date)"
    }

    private func sectionHeading(_ title: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title).font(.title3.weight(.semibold))
            Spacer()
            Button("See all", action: action).font(.subheadline)
                .accessibilityLabel("See all \(title.lowercased())")
        }
    }

    private func refreshRecurringBudgets(now: Date) {
        do {
            try BudgetSchedule.generateIfNeeded(context: modelContext, now: now)
        } catch {
            showingBudgetUpdateError = true
        }
    }

    private func color(named name: String) -> Color {
        switch name {
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "red": return .red
        case "pink": return .pink
        case "teal": return .teal
        case "gray": return .gray
        default: return .blue
        }
    }
}

private struct DashboardCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(.background, in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
    }
}
