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
                        walletSection
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
            .navigationTitle("Home")
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
            .filter { $0.wallet == nil }.count

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
                        HStack(alignment: .firstTextBaseline) {
                            Text(total.amount, format: .currency(code: total.currencyCode))
                                .font(.largeTitle.weight(.bold))
                                .monospacedDigit()
                                .minimumScaleFactor(0.7)
                            Spacer()
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

    private var walletSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("Wallets", action: openWallets)
            DashboardCard {
                if wallets.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Start with a wallet", systemImage: "wallet.bifold")
                            .font(.headline)
                        Text("Add your cash or bank account to start tracking your spending.")
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
                                HStack(spacing: 12) {
                                    Image(systemName: wallet.icon)
                                        .font(.title3)
                                        .foregroundStyle(color(named: wallet.colorName))
                                        .frame(width: 40, height: 40)
                                        .background(color(named: wallet.colorName).opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(wallet.name).fontWeight(.medium)
                                        Text(wallet.currencyCode)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(DashboardMetrics.balance(for: wallet, transfers: transfers),
                                         format: .currency(code: wallet.currencyCode))
                                        .fontWeight(.semibold)
                                        .monospacedDigit()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
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
                        budgetCard(budget)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func budgetCard(_ budget: Budget) -> some View {
        let spent = DashboardMetrics.spent(for: budget, transactions: transactions)
        let remaining = budget.totalAmount - spent
        let overBudget = remaining < 0
        let progress = budget.totalAmount > 0
            ? NSDecimalNumber(decimal: spent / budget.totalAmount).doubleValue : 0

        return DashboardCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(budget.name).font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: min(max(progress, 0), 1))
                    .tint(overBudget ? .red : .blue)
                HStack {
                    Text(overBudget ? "Over budget" : "Remaining")
                        .foregroundStyle(overBudget ? Color.red : Color.secondary)
                    Spacer()
                    Text(overBudget ? -remaining : remaining,
                         format: .currency(code: budget.currencyCode))
                        .fontWeight(.semibold)
                        .foregroundStyle(overBudget ? Color.red : Color.primary)
                }
                .font(.subheadline)
                Text("\(spent.formatted(.currency(code: budget.currencyCode))) of \(budget.totalAmount.formatted(.currency(code: budget.currencyCode))) used")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let dueDate = calendar.startOfDay(for: payment.nextPaymentDate)

        return HStack(spacing: 12) {
            Image(systemName: "calendar")
                .foregroundStyle(dueDate <= today ? Color.orange : Color.blue)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(payment.name).fontWeight(.medium)
                Text(paymentDateText(payment, today: today))
                    .font(.caption)
                    .foregroundStyle(dueDate <= today ? Color.orange : Color.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if let wallet = payment.wallet {
                    Text(payment.amount, format: .currency(code: wallet.currencyCode))
                        .fontWeight(.semibold)
                } else {
                    Text(payment.amount, format: .number).fontWeight(.semibold)
                    Text("No wallet selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
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
