import Foundation
import SwiftData

@MainActor
enum DashboardMetrics {
    struct CurrencySpending: Identifiable {
        var id: String { currencyCode }
        let currencyCode: String
        let amount: Decimal
    }

    static func monthlyTransactions(
        _ transactions: [ExpenseTransaction],
        now: Date,
        calendar: Calendar = .current
    ) -> [ExpenseTransaction] {
        guard let month = calendar.dateInterval(of: .month, for: now) else {
            return []
        }
        return transactions.filter {
            $0.date >= month.start && $0.date < month.end && $0.date <= now
        }
    }

    static func monthlySpending(
        transactions: [ExpenseTransaction],
        wallets: [Wallet],
        now: Date,
        calendar: Calendar = .current
    ) -> [CurrencySpending] {
        monthlyTotals(transactions: transactions, wallets: wallets, now: now,
                      calendar: calendar, isIncome: false)
    }

    static func monthlyIncome(
        transactions: [ExpenseTransaction], wallets: [Wallet], now: Date,
        calendar: Calendar = .current
    ) -> [CurrencySpending] {
        monthlyTotals(transactions: transactions, wallets: wallets, now: now,
                      calendar: calendar, isIncome: true)
    }

    static func monthlyNetCashFlow(
        transactions: [ExpenseTransaction], wallets: [Wallet], now: Date,
        calendar: Calendar = .current
    ) -> [CurrencySpending] {
        // Transfers move existing money; they are neither income nor spending.
        let income = monthlyIncome(transactions: transactions, wallets: wallets, now: now, calendar: calendar)
        let spending = monthlySpending(transactions: transactions, wallets: wallets, now: now, calendar: calendar)
        let spendingByCurrency = Dictionary(uniqueKeysWithValues: spending.map { ($0.currencyCode, $0.amount) })
        let incomeByCurrency = Dictionary(uniqueKeysWithValues: income.map { ($0.currencyCode, $0.amount) })
        let currencies = Set(incomeByCurrency.keys).union(spendingByCurrency.keys)
        return currencies.sorted().map {
            CurrencySpending(currencyCode: $0,
                             amount: incomeByCurrency[$0, default: 0] - spendingByCurrency[$0, default: 0])
        }
    }

    private static func monthlyTotals(
        transactions: [ExpenseTransaction], wallets: [Wallet], now: Date,
        calendar: Calendar, isIncome: Bool
    ) -> [CurrencySpending] {
        var totals: [String: Decimal] = [:]
        for wallet in wallets {
            totals[wallet.currencyCode] = 0
        }
        for transaction in monthlyTransactions(transactions, now: now, calendar: calendar) {
            guard transaction.isIncome == isIncome,
                  let currency = transaction.wallet?.currencyCode else { continue }
            totals[currency, default: 0] += transaction.amount
        }
        return totals.keys.sorted().map {
            CurrencySpending(currencyCode: $0, amount: totals[$0, default: 0])
        }
    }

    static func balance(for wallet: Wallet, transfers: [WalletTransfer]) -> Decimal {
        wallet.balance(including: transfers)
    }

    static func currentBudgets(
        _ budgets: [Budget],
        now: Date,
        calendar: Calendar = .current
    ) -> [Budget] {
        let today = calendar.startOfDay(for: now)
        return budgets.filter {
            calendar.startOfDay(for: $0.startDate) <= today &&
                calendar.startOfDay(for: $0.endDate) >= today
        }.sorted { $0.endDate < $1.endDate }
    }

    static func spent(
        for budget: Budget,
        transactions: [ExpenseTransaction],
        calendar: Calendar = .current
    ) -> Decimal {
        let start = calendar.startOfDay(for: budget.startDate)
        let end = calendar.date(
            byAdding: .day, value: 1, to: calendar.startOfDay(for: budget.endDate)
        ) ?? budget.endDate
        let categoryIDs = Set(budget.categories.map { $0.persistentModelID })
        return transactions.filter {
            guard !$0.isIncome, let category = $0.category, let wallet = $0.wallet else { return false }
            return categoryIDs.contains(category.persistentModelID) &&
                wallet.currencyCode == budget.currencyCode &&
                $0.date >= start && $0.date < end
        }.reduce(Decimal.zero) { $0 + $1.amount }
    }

    static func nextPayments(_ payments: [RecurringPayment]) -> [RecurringPayment] {
        payments.filter { $0.isActive }.sorted {
            if $0.nextPaymentDate == $1.nextPaymentDate {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return $0.nextPaymentDate < $1.nextPaymentDate
        }
    }
}
