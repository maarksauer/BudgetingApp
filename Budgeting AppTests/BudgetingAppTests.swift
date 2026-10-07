import Foundation
import SwiftData
import XCTest
@testable import BudgetingApp

final class BudgetingAppTests: XCTestCase {
    @MainActor
    func testWalletBalanceSubtractsExpensesExactly() {
        let wallet = Wallet(name: "Cash", startingBalance: 100, currencyCode: "EUR", walletType: "Cash")
        wallet.transactions = [
            ExpenseTransaction(amount: Decimal(string: "12.30")!, wallet: wallet),
            ExpenseTransaction(amount: Decimal(string: "7.45")!, wallet: wallet)
        ]

        XCTAssertEqual(wallet.currentBalance, Decimal(string: "80.25")!)
    }

    @MainActor
    func testWalletOverdraftLimit() {
        let wallet = Wallet(name: "Bank", startingBalance: 0, currencyCode: "EUR", walletType: "Bank")
        XCTAssertEqual(wallet.minimumAllowedBalance, 0)

        wallet.allowsNegativeBalance = true
        wallet.negativeBalanceLimit = 250
        XCTAssertEqual(wallet.minimumAllowedBalance, -250)
    }

    @MainActor
    func testReschedulingClearsPostponement() {
        let scheduled = Date(timeIntervalSince1970: 1_000_000)
        let postponed = scheduled.addingTimeInterval(86_400)
        let rescheduled = scheduled.addingTimeInterval(172_800)
        let payment = RecurringPayment(name: "Rent", amount: 500, frequency: "Monthly", nextPaymentDate: scheduled)
        payment.postponedUntil = postponed
        XCTAssertEqual(payment.nextPaymentDate, postponed)
        XCTAssertTrue(payment.isPostponed)
        XCTAssertEqual(payment.scheduledPaymentDate, scheduled)

        payment.nextPaymentDate = rescheduled
        XCTAssertEqual(payment.scheduledPaymentDate, rescheduled)
        XCTAssertNil(payment.postponedUntil)
        XCTAssertFalse(payment.isPostponed)
    }

    @MainActor
    func testPausedPaymentIsNotDueEvenWhenOverdue() {
        let payment = RecurringPayment(name: "Subscription", amount: 10, frequency: "Monthly", nextPaymentDate: .distantPast, isActive: false)
        XCTAssertFalse(payment.isDue)
        XCTAssertEqual(payment.statusText, "Paused")
    }

    @MainActor
    func testMonthlySpendingKeepsCurrenciesSeparateAndExcludesOtherDates() {
        let eur = Wallet(name: "Euro", startingBalance: 0, currencyCode: "EUR", walletType: "Cash")
        let huf = Wallet(name: "Forint", startingBalance: 0, currencyCode: "HUF", walletType: "Cash")
        let gbp = Wallet(name: "Pounds", startingBalance: 0, currencyCode: "GBP", walletType: "Cash")
        let transactions = [
            ExpenseTransaction(amount: Decimal(string: "12.30")!, date: date(2026, 10, 1), wallet: eur),
            ExpenseTransaction(amount: Decimal(string: "7.45")!, date: date(2026, 10, 7), wallet: eur),
            ExpenseTransaction(amount: 1500, date: date(2026, 10, 3), wallet: huf),
            ExpenseTransaction(amount: 685000, isIncome: true, date: date(2026, 10, 3), wallet: huf),
            ExpenseTransaction(amount: 99, date: date(2026, 9, 30), wallet: eur),
            ExpenseTransaction(amount: 44, date: date(2026, 10, 8), wallet: eur),
            ExpenseTransaction(amount: 5000, date: date(2026, 11, 1), wallet: huf),
            ExpenseTransaction(amount: 100, date: date(2026, 10, 2))
        ]

        let totals = DashboardMetrics.monthlySpending(
            transactions: transactions, wallets: [eur, huf, gbp],
            now: date(2026, 10, 7, hour: 12), calendar: utcCalendar
        )
        XCTAssertEqual(totals.map(\.currencyCode), ["EUR", "GBP", "HUF"])
        XCTAssertEqual(totals.map(\.amount), [Decimal(string: "19.75")!, 0, 1500])
    }

    @MainActor
    func testDashboardWalletBalanceUsesEachSideOfTransfers() {
        let eur = Wallet(name: "Euro", startingBalance: 100, currencyCode: "EUR", walletType: "Cash")
        let other = Wallet(name: "Other", startingBalance: 0, currencyCode: "EUR", walletType: "Cash")
        let usd = Wallet(name: "Dollar", startingBalance: 100, currencyCode: "USD", walletType: "Cash")
        eur.transactions = [ExpenseTransaction(amount: Decimal(string: "12.30")!, wallet: eur)]
        let transfers = [
            WalletTransfer(sourceAmount: 20, destinationAmount: 20, sourceWallet: eur, destinationWallet: other),
            WalletTransfer(sourceAmount: 10, destinationAmount: Decimal(string: "7.25")!, sourceWallet: usd, destinationWallet: eur),
            WalletTransfer(sourceAmount: 50, destinationAmount: 45, sourceWallet: usd, destinationWallet: other)
        ]

        XCTAssertEqual(DashboardMetrics.balance(for: eur, transfers: transfers), Decimal(string: "74.95")!)
    }

    @MainActor
    func testDashboardBudgetMatchesCategoryCurrencyAndEntireEndDay() {
        let food = SpendingCategory(name: "Food", icon: "fork.knife", colorName: "orange")
        let travel = SpendingCategory(name: "Travel", icon: "car", colorName: "blue")
        let eur = Wallet(name: "Euro", startingBalance: 1000, currencyCode: "EUR", walletType: "Cash")
        let huf = Wallet(name: "Forint", startingBalance: 10000, currencyCode: "HUF", walletType: "Cash")
        let budget = Budget(name: "Food", totalAmount: 100, currencyCode: "EUR",
                            startDate: date(2026, 10, 1), endDate: date(2026, 10, 7))
        budget.categories = [food]
        let transactions = [
            ExpenseTransaction(amount: Decimal(string: "0.05")!, date: date(2026, 10, 1), wallet: eur, category: food),
            ExpenseTransaction(amount: 120, date: date(2026, 10, 7, hour: 23, minute: 59), wallet: eur, category: food),
            ExpenseTransaction(amount: 30, date: date(2026, 10, 4), wallet: eur, category: travel),
            ExpenseTransaction(amount: 200, date: date(2026, 10, 4), wallet: huf, category: food),
            ExpenseTransaction(amount: 50, date: date(2026, 9, 30), wallet: eur, category: food),
            ExpenseTransaction(amount: 60, date: date(2026, 10, 8), wallet: eur, category: food),
            ExpenseTransaction(amount: 70, date: date(2026, 10, 4), category: food),
            ExpenseTransaction(amount: 80, date: date(2026, 10, 4), wallet: eur),
            // Even income with an expense category must never use up a budget.
            ExpenseTransaction(amount: 500, isIncome: true, date: date(2026, 10, 4), wallet: eur, category: food)
        ]

        XCTAssertEqual(DashboardMetrics.spent(for: budget, transactions: transactions, calendar: utcCalendar),
                       Decimal(string: "120.05")!)
        XCTAssertEqual(DashboardMetrics.currentBudgets([budget], now: date(2026, 10, 7, hour: 23), calendar: utcCalendar).count, 1)
        XCTAssertTrue(DashboardMetrics.currentBudgets([budget], now: date(2026, 10, 8), calendar: utcCalendar).isEmpty)
    }

    @MainActor
    func testDashboardBillsRespectPostponementAndExcludePausedPayments() {
        let overdue = RecurringPayment(name: "Rent", amount: 500, frequency: "Monthly", nextPaymentDate: date(2026, 10, 1))
        let upcoming = RecurringPayment(name: "Internet", amount: 20, frequency: "Monthly", nextPaymentDate: date(2026, 10, 9))
        let postponed = RecurringPayment(name: "Insurance", amount: 30, frequency: "Monthly", nextPaymentDate: date(2026, 9, 29))
        postponed.postponedUntil = date(2026, 10, 20)
        let paused = RecurringPayment(name: "Paused", amount: 10, frequency: "Monthly", nextPaymentDate: .distantPast, isActive: false)

        XCTAssertEqual(DashboardMetrics.nextPayments([postponed, paused, upcoming, overdue]).map(\.name),
                       ["Rent", "Internet", "Insurance"])
    }

    @MainActor
    func testRecurringBudgetsCatchUpAcrossShortMonthsWithoutDuplicates() {
        let budget = Budget(name: "Monthly", totalAmount: 250, currencyCode: "EUR",
                            startDate: date(2026, 1, 1), endDate: date(2026, 1, 31), isRecurring: true)
        let category = SpendingCategory(name: "Food", icon: "fork.knife", colorName: "orange")
        budget.categories = [category]
        let now = date(2026, 3, 2)
        let generated = BudgetSchedule.missingMonthlyBudgets(from: [budget], through: now, calendar: utcCalendar)

        XCTAssertEqual(generated.count, 2)
        XCTAssertEqual(generated.map(\.startDate), [date(2026, 2, 1), date(2026, 3, 1)])
        XCTAssertEqual(generated.map(\.endDate), [date(2026, 2, 28), date(2026, 3, 31)])
        XCTAssertTrue(generated.allSatisfy {
            $0.seriesID == budget.seriesID && $0.totalAmount == 250 && $0.currencyCode == "EUR" &&
                $0.categories.first?.persistentModelID == category.persistentModelID
        })
        XCTAssertTrue(BudgetSchedule.missingMonthlyBudgets(from: [budget] + generated, through: now, calendar: utcCalendar).isEmpty)
        generated.last?.isRecurring = false
        XCTAssertTrue(BudgetSchedule.missingMonthlyBudgets(from: [budget] + generated, through: date(2026, 4, 2), calendar: utcCalendar).isEmpty)
    }

    @MainActor
    func testRecurringBudgetRefreshIncludesPendingPeriodsFromAnotherScreen() throws {
        let schema = Schema([
            Item.self, Wallet.self, ExpenseTransaction.self, SpendingCategory.self,
            SpendingSubcategory.self, Budget.self, WalletTransfer.self, RecurringPayment.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let budget = Budget(name: "Monthly", totalAmount: 250, currencyCode: "EUR",
                            startDate: date(2026, 1, 1), endDate: date(2026, 1, 31), isRecurring: true)
        context.insert(budget)

        try BudgetSchedule.generateIfNeeded(context: context, now: date(2026, 3, 2), calendar: utcCalendar)
        try BudgetSchedule.generateIfNeeded(context: context, now: date(2026, 3, 2), calendar: utcCalendar)

        let periods = try context.fetch(FetchDescriptor<Budget>())
        XCTAssertEqual(periods.count, 3)
        XCTAssertEqual(Set(periods.map(\.startDate)).count, 3)
    }

    @MainActor
    func testExistingTransactionInitializersStillCreateExpenses() {
        let expense = ExpenseTransaction(amount: 25)
        XCTAssertFalse(expense.isIncome)
        XCTAssertEqual(expense.balanceImpact, -25)
        let payment = RecurringPayment(name: "Rent", amount: 500, frequency: "Monthly", nextPaymentDate: .now)
        let paid = ExpenseTransaction(amount: 500, recurringPayment: payment)
        XCTAssertFalse(paid.isIncome)
        XCTAssertEqual(paid.balanceImpact, -500)
    }

    @MainActor
    func testIncomeAndExpensesUseExactDecimalBalanceWithTransfers() {
        let wallet = Wallet(name: "Bank", startingBalance: 0, currencyCode: "EUR", walletType: "Bank Account")
        let other = Wallet(name: "Cash", startingBalance: 0, currencyCode: "EUR", walletType: "Cash")
        wallet.transactions = [
            ExpenseTransaction(amount: Decimal(string: "100.10")!, isIncome: true, wallet: wallet),
            ExpenseTransaction(amount: Decimal(string: "20.05")!, wallet: wallet)
        ]
        let transfers = [
            WalletTransfer(sourceAmount: 10, destinationAmount: 10, sourceWallet: wallet, destinationWallet: other),
            WalletTransfer(sourceAmount: 5, destinationAmount: 5, sourceWallet: other, destinationWallet: wallet)
        ]
        XCTAssertEqual(wallet.currentBalance, Decimal(string: "80.05")!)
        XCTAssertEqual(wallet.balance(including: transfers), Decimal(string: "75.05")!)
        XCTAssertEqual(DashboardMetrics.balance(for: wallet, transfers: transfers), wallet.balance(including: transfers))
        XCTAssertGreaterThanOrEqual(wallet.balance(including: transfers) - 75, wallet.minimumAllowedBalance)
    }

    @MainActor
    func testMonthlyIncomeAndCashFlowSeparateCurrenciesAndExcludeOtherDates() {
        let eur = Wallet(name: "Euro", startingBalance: 1000, currencyCode: "EUR", walletType: "Cash")
        let huf = Wallet(name: "Forint", startingBalance: 0, currencyCode: "HUF", walletType: "Bank Account")
        let gbp = Wallet(name: "Pounds", startingBalance: 0, currencyCode: "GBP", walletType: "Cash")
        let transactions = [
            ExpenseTransaction(amount: Decimal(string: "50.25")!, isIncome: true, date: date(2026, 10, 1), wallet: eur),
            ExpenseTransaction(amount: 100, date: date(2026, 10, 2), wallet: eur),
            ExpenseTransaction(amount: 685000, isIncome: true, date: date(2026, 10, 3), wallet: huf),
            ExpenseTransaction(amount: 5000, date: date(2026, 10, 4), wallet: huf),
            ExpenseTransaction(amount: 20, date: date(2026, 10, 5), wallet: gbp),
            ExpenseTransaction(amount: 300, isIncome: true, date: date(2026, 9, 30), wallet: eur),
            ExpenseTransaction(amount: 400, isIncome: true, date: date(2026, 10, 8), wallet: eur),
            ExpenseTransaction(amount: 500, isIncome: true, date: date(2026, 11, 1), wallet: eur),
            ExpenseTransaction(amount: 900, isIncome: true, date: date(2026, 10, 2))
        ]
        let now = date(2026, 10, 7, hour: 12)
        let income = DashboardMetrics.monthlyIncome(transactions: transactions, wallets: [eur, huf, gbp], now: now, calendar: utcCalendar)
        let net = DashboardMetrics.monthlyNetCashFlow(transactions: transactions, wallets: [eur, huf, gbp], now: now, calendar: utcCalendar)
        XCTAssertEqual(income.map(\.currencyCode), ["EUR", "GBP", "HUF"])
        XCTAssertEqual(income.map(\.amount), [Decimal(string: "50.25")!, 0, 685000])
        XCTAssertEqual(net.map(\.amount), [Decimal(string: "-49.75")!, -20, 680000])
        XCTAssertTrue(DashboardMetrics.monthlyIncome(transactions: [], wallets: [], now: now).isEmpty)
    }

    @MainActor
    func testIncomeEditingMovingAndDeletionUpdatePersistedWallets() throws {
        let schema = Schema([
            Item.self, Wallet.self, ExpenseTransaction.self, SpendingCategory.self,
            SpendingSubcategory.self, Budget.self, WalletTransfer.self, RecurringPayment.self
        ])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let bank = Wallet(name: "Bank", startingBalance: 0, currencyCode: "EUR", walletType: "Bank Account")
        let cash = Wallet(name: "Cash", startingBalance: 10, currencyCode: "EUR", walletType: "Cash")
        context.insert(bank)
        context.insert(cash)
        let income = ExpenseTransaction(amount: 100, isIncome: true, wallet: bank)
        context.insert(income)
        try context.save()
        XCTAssertEqual(bank.currentBalance, 100)
        XCTAssertNil(income.category)

        income.amount = 150
        try context.save()
        XCTAssertEqual(bank.currentBalance, 150)

        income.wallet = cash
        try context.save()
        XCTAssertEqual(bank.currentBalance, 0)
        XCTAssertEqual(cash.currentBalance, 160)

        context.delete(income)
        try context.save()
        XCTAssertEqual(bank.currentBalance, 0)
        XCTAssertEqual(cash.currentBalance, 10)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExpenseTransaction>()).isEmpty)
    }

    @MainActor
    func testIncomeTypeSurvivesStoreReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let schema = Schema([
            Item.self, Wallet.self, ExpenseTransaction.self, SpendingCategory.self,
            SpendingSubcategory.self, Budget.self, WalletTransfer.self, RecurringPayment.self
        ])
        let configuration = ModelConfiguration(schema: schema, url: directory.appendingPathComponent("income.store"), cloudKitDatabase: .none)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            context.autosaveEnabled = false
            let wallet = Wallet(name: "Bank", startingBalance: 10, currencyCode: "EUR", walletType: "Bank Account")
            context.insert(wallet)
            context.insert(ExpenseTransaction(amount: 100, isIncome: true, note: "Salary", wallet: wallet))
            context.insert(ExpenseTransaction(amount: 20, note: "Lunch", wallet: wallet))
            try context.save()
        }
        let reopened = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(reopened)
        let transactions = try context.fetch(FetchDescriptor<ExpenseTransaction>())
        XCTAssertEqual(transactions.filter { $0.isIncome }.count, 1)
        XCTAssertEqual(transactions.filter { !$0.isIncome }.count, 1)
        let wallet = try XCTUnwrap(context.fetch(FetchDescriptor<Wallet>()).first)
        XCTAssertEqual(wallet.currentBalance, 90)
    }

    @MainActor
    func testMonthlyCategorySpendingUsesCategoryIdentityAndSeparateCurrencies() throws {
        let food = SpendingCategory(name: "Food", icon: "fork.knife", colorName: "orange")
        let otherFood = SpendingCategory(name: "Food", icon: "basket", colorName: "green")
        let groceries = SpendingSubcategory(name: "Groceries", category: food)
        let eur = Wallet(name: "Euro", startingBalance: 1000, currencyCode: "EUR", walletType: "Cash")
        let huf = Wallet(name: "Forint", startingBalance: 10000, currencyCode: "HUF", walletType: "Cash")
        let otherHuf = Wallet(name: "Bank", startingBalance: 10000, currencyCode: "HUF", walletType: "Bank Account")
        let transactions = [
            ExpenseTransaction(amount: Decimal(string: "12.30")!, date: date(2026, 10, 1), wallet: eur, category: food),
            ExpenseTransaction(amount: Decimal(string: "7.45")!, date: date(2026, 10, 3), wallet: eur, category: food, subcategory: groceries),
            ExpenseTransaction(amount: 5, date: date(2026, 10, 3), wallet: eur, category: otherFood),
            ExpenseTransaction(amount: 2, date: date(2026, 10, 4), wallet: eur),
            ExpenseTransaction(amount: 1500, date: date(2026, 10, 3), wallet: huf, category: food),
            ExpenseTransaction(amount: 3500, date: date(2026, 10, 3), wallet: otherHuf, category: food),
            ExpenseTransaction(amount: 99, date: date(2026, 9, 30), wallet: eur, category: food),
            ExpenseTransaction(amount: 44, date: date(2026, 10, 8), wallet: eur, category: food),
            ExpenseTransaction(amount: 50, date: date(2026, 11, 1), wallet: eur, category: food),
            ExpenseTransaction(amount: 100, date: date(2026, 10, 3), category: food),
            ExpenseTransaction(amount: 685000, isIncome: true, date: date(2026, 10, 3), wallet: huf, category: food)
        ]
        let now = date(2026, 10, 7, hour: 12)
        let groups = DashboardMetrics.monthlyCategorySpending(transactions: transactions, now: now, calendar: utcCalendar)
        XCTAssertEqual(groups.map(\.currencyCode), ["EUR", "HUF"])
        XCTAssertEqual(groups.map(\.totalAmount), [Decimal(string: "26.75")!, 5000])
        let euros = try XCTUnwrap(groups.first)
        XCTAssertEqual(euros.categories.map(\.name), ["Food", "Food", "Uncategorized"])
        XCTAssertEqual(euros.categories.map(\.amount), [Decimal(string: "19.75")!, 5, 2])
        XCTAssertEqual(Set(euros.categories.map(\.id)).count, 3)
        XCTAssertEqual(euros.categories.first?.icon, "fork.knife")
        XCTAssertEqual(euros.categories.first?.colorName, "orange")
        let spending = DashboardMetrics.monthlySpending(transactions: transactions, wallets: [eur, huf, otherHuf], now: now, calendar: utcCalendar)
        XCTAssertEqual(groups.map(\.totalAmount), spending.map(\.amount))
    }

    @MainActor
    func testCategoryBreakdownHasNoGroupsWithoutMonthlyExpenses() {
        let wallet = Wallet(name: "Bank", startingBalance: 0, currencyCode: "EUR", walletType: "Bank Account")
        let income = ExpenseTransaction(amount: 100, isIncome: true, date: date(2026, 10, 3), wallet: wallet)
        let oldExpense = ExpenseTransaction(amount: 50, date: date(2026, 9, 30), wallet: wallet)
        XCTAssertTrue(DashboardMetrics.monthlyCategorySpending(transactions: [], now: date(2026, 10, 7), calendar: utcCalendar).isEmpty)
        XCTAssertTrue(DashboardMetrics.monthlyCategorySpending(transactions: [income, oldExpense], now: date(2026, 10, 7), calendar: utcCalendar).isEmpty)
    }

    @MainActor
    func testRecentActivityCombinesIncomeExpensesAndTransfersNewestFirst() {
        let bank = Wallet(name: "Bank", startingBalance: 1000, currencyCode: "EUR", walletType: "Bank Account")
        let cash = Wallet(name: "Cash", startingBalance: 0, currencyCode: "EUR", walletType: "Cash")
        let expense = ExpenseTransaction(amount: 20, date: date(2026, 10, 5), wallet: bank)
        let income = ExpenseTransaction(amount: 100, isIncome: true, date: date(2026, 10, 6), wallet: bank)
        let transfer = WalletTransfer(sourceAmount: 10, destinationAmount: 10, date: date(2026, 10, 7), sourceWallet: bank, destinationWallet: cash)
        let future = ExpenseTransaction(amount: 200, date: date(2026, 10, 8), wallet: bank)
        let old = ExpenseTransaction(amount: 5, date: date(2026, 9, 30), wallet: bank)
        let recent = DashboardMetrics.recentActivity(transactions: [expense, future, income, old], transfers: [transfer], now: date(2026, 10, 7, hour: 12))
        XCTAssertEqual(recent.map(\.date), [transfer.date, income.date, expense.date, old.date])
        XCTAssertEqual(Set(recent.map(\.id)).count, 4)
        if case .transfer(let first) = recent[0] {
            XCTAssertEqual(first.persistentModelID, transfer.persistentModelID)
        } else { XCTFail("The newest transfer should be first.") }
        if case .transaction(let second) = recent[1] {
            XCTAssertTrue(second.isIncome)
        } else { XCTFail("Income should appear in recent transactions.") }
    }

    @MainActor
    func testRecentActivityLimitAndEqualDateOrderingAreStable() {
        let now = date(2026, 10, 7)
        let transactions = (1...7).map { ExpenseTransaction(amount: Decimal($0), date: now) }
        let first = DashboardMetrics.recentActivity(transactions: transactions, transfers: [], now: now)
        let reversed = DashboardMetrics.recentActivity(transactions: Array(transactions.reversed()), transfers: [], now: now)
        XCTAssertEqual(first.count, 5)
        XCTAssertEqual(first.map(\.id), reversed.map(\.id))
        XCTAssertEqual(first.map(\.id), first.map(\.id).sorted())
        XCTAssertTrue(DashboardMetrics.recentActivity(transactions: transactions, transfers: [], now: now, limit: 0).isEmpty)
        XCTAssertTrue(DashboardMetrics.recentActivity(transactions: transactions, transfers: [], now: now, limit: -1).isEmpty)
        XCTAssertTrue(DashboardMetrics.recentActivity(transactions: [], transfers: [], now: now).isEmpty)
    }

    @MainActor
    func testCategoryBreakdownReflectsEditsAndDeletedCategories() throws {
        let category = SpendingCategory(name: "Food", icon: "fork.knife", colorName: "orange")
        let wallet = Wallet(name: "Cash", startingBalance: 1000, currencyCode: "EUR", walletType: "Cash")
        let expense = ExpenseTransaction(amount: 10, date: date(2026, 10, 3), wallet: wallet, category: category)
        let now = date(2026, 10, 7)
        expense.amount = 15
        expense.category = nil
        let group = try XCTUnwrap(DashboardMetrics.monthlyCategorySpending(transactions: [expense], now: now, calendar: utcCalendar).first)
        XCTAssertEqual(group.totalAmount, 15)
        XCTAssertEqual(group.categories.first?.name, "Uncategorized")
        XCTAssertTrue(DashboardMetrics.monthlyCategorySpending(transactions: [], now: now, calendar: utcCalendar).isEmpty)
    }

    @MainActor
    func testCSVExportCombinesSignedAmountsCurrenciesAndRecurringMetadata() throws {
        let euro = Wallet(name: "Euro", startingBalance: 100, currencyCode: "EUR", walletType: "Cash")
        let forint = Wallet(name: "Forint", startingBalance: 0, currencyCode: "HUF", walletType: "Bank Account")
        let food = SpendingCategory(name: "Food", icon: "fork.knife", colorName: "orange")
        let lunch = SpendingSubcategory(name: "Lunch", category: food)
        let bill = RecurringPayment(name: "Subscription", amount: 12, frequency: "Monthly", nextPaymentDate: date(2026, 10, 1))
        let expense = ExpenseTransaction(amount: Decimal(string: "12.30")!, date: date(2026, 10, 1), note: "Meal", wallet: euro, category: food, subcategory: lunch, recurringPayment: bill)
        let income = ExpenseTransaction(amount: 685000, isIncome: true, date: date(2026, 10, 2), note: "Salary", wallet: forint)
        let transfer = WalletTransfer(sourceAmount: 20, destinationAmount: 8000, date: date(2026, 10, 3), note: "Top up", sourceWallet: euro, destinationWallet: forint)
        let export = TransactionCSVExport.makeExport(transactions: [income, expense], transfers: [transfer])
        let text = try XCTUnwrap(String(data: export.data, encoding: .utf8))
        XCTAssertEqual(export.rowCount, 3)
        XCTAssertTrue(text.contains("\"Expense\",\"Euro\",-12.3,\"EUR\",\"Food\",\"Lunch\",\"Meal\",\"\",\"\",\"\",\"Subscription\""))
        XCTAssertTrue(text.contains("\"Income\",\"Forint\",685000,\"HUF\""))
        XCTAssertTrue(text.contains("\"Transfer\",\"Euro\",-20,\"EUR\",\"\",\"\",\"Top up\",\"Forint\",8000,\"HUF\",\"\""))
        let lines = text.components(separatedBy: "\r\n")
        XCTAssertTrue(lines[1].hasPrefix("\"2026-10-01T00:00:00.000Z\""))
        XCTAssertTrue(lines[2].contains("\"Income\""))
        XCTAssertTrue(lines[3].contains("\"Transfer\""))
        XCTAssertEqual(euro.startingBalance, 100)
        XCTAssertEqual(expense.amount, Decimal(string: "12.30")!)
    }

    @MainActor
    func testCSVExportEscapesQuotesNewlinesAndPreservesHungarianText() throws {
        let wallet = Wallet(name: "Bank, account", startingBalance: 0, currencyCode: "HUF", walletType: "Bank Account")
        let income = ExpenseTransaction(amount: 10, isIncome: true, note: "Árvíztűrő, \"tükör\"\nMásodik sor", wallet: wallet)
        let export = TransactionCSVExport.makeExport(transactions: [income], transfers: [])
        let text = try XCTUnwrap(String(data: export.data, encoding: .utf8))
        XCTAssertEqual(export.data.prefix(3), Data([0xEF, 0xBB, 0xBF]))
        XCTAssertTrue(text.contains("\"Bank, account\""))
        XCTAssertTrue(text.contains("\"Árvíztűrő, \"\"tükör\"\"\nMásodik sor\""))
        XCTAssertTrue(text.hasSuffix("\r\n"))
        XCTAssertEqual(export.rowCount, 1)
    }

    @MainActor
    func testCSVSemicolonFormatUsesDecimalCommasAndSupportsTransferExclusion() throws {
        let wallet = Wallet(name: "Bank; savings", startingBalance: 100, currencyCode: "EUR", walletType: "Bank Account")
        let cash = Wallet(name: "Cash", startingBalance: 0, currencyCode: "EUR", walletType: "Cash")
        let expense = ExpenseTransaction(amount: Decimal(string: "0.05")!, wallet: wallet)
        let transfer = WalletTransfer(sourceAmount: 10, destinationAmount: 10, sourceWallet: wallet, destinationWallet: cash)
        let options = TransactionCSVExport.Options(separator: .semicolon, includeTransfers: false)
        let export = TransactionCSVExport.makeExport(transactions: [expense], transfers: [transfer], options: options)
        let text = try XCTUnwrap(String(data: export.data, encoding: .utf8))
        XCTAssertTrue(text.contains("\"Expense\";\"Bank; savings\";-0,05;\"EUR\""))
        XCTAssertFalse(text.contains("\"Transfer\";"))
        XCTAssertEqual(export.rowCount, 1)
        XCTAssertEqual(TransactionCSVExport.rowCount(transactions: [expense], transfers: [transfer], options: options), 1)
    }

    @MainActor
    func testCSVDateRangeIncludesWholeBoundaryDaysAndCountsTransfers() throws {
        let wallet = Wallet(name: "Bank", startingBalance: 100, currencyCode: "EUR", walletType: "Bank Account")
        let cash = Wallet(name: "Cash", startingBalance: 0, currencyCode: "EUR", walletType: "Cash")
        let transactions = [
            ExpenseTransaction(amount: 1, date: date(2026, 10, 1, hour: 23, minute: 59)),
            ExpenseTransaction(amount: 2, date: date(2026, 10, 2)),
            ExpenseTransaction(amount: 3, date: date(2026, 10, 3, hour: 23, minute: 59)),
            ExpenseTransaction(amount: 4, date: date(2026, 10, 4))
        ]
        let transfer = WalletTransfer(sourceAmount: 10, destinationAmount: 10, date: date(2026, 10, 3, hour: 23, minute: 59), sourceWallet: wallet, destinationWallet: cash)
        var options = TransactionCSVExport.Options(startDate: date(2026, 10, 2, hour: 12), endDate: date(2026, 10, 3, hour: 12))
        let export = TransactionCSVExport.makeExport(transactions: transactions, transfers: [transfer], options: options, calendar: utcCalendar)
        XCTAssertEqual(export.rowCount, 3)
        XCTAssertEqual(TransactionCSVExport.rowCount(transactions: transactions, transfers: [transfer], options: options, calendar: utcCalendar), 3)
        options.startDate = date(2026, 10, 5)
        XCTAssertEqual(TransactionCSVExport.makeExport(transactions: transactions, transfers: [transfer], options: options, calendar: utcCalendar).rowCount, 0)
        let empty = TransactionCSVExport.makeExport(transactions: [], transfers: [])
        let text = try XCTUnwrap(String(data: empty.data, encoding: .utf8))
        XCTAssertEqual(empty.rowCount, 0)
        XCTAssertEqual(text.components(separatedBy: "\r\n").count, 2)
        XCTAssertTrue(text.contains("\"Destination Currency\""))
    }

    @MainActor
    func testCSVExportRetainsTransferCurrenciesWhenWalletsAreMissing() throws {
        let euro = Wallet(name: "Euro", startingBalance: 100, currencyCode: "EUR", walletType: "Cash")
        let dollar = Wallet(name: "Dollar", startingBalance: 0, currencyCode: "USD", walletType: "Cash")
        let transfer = WalletTransfer(sourceAmount: 20, destinationAmount: 22, sourceWallet: euro, destinationWallet: dollar)
        transfer.sourceWallet = nil
        transfer.destinationWallet = nil
        let missingWalletExpense = ExpenseTransaction(amount: 5)
        let export = TransactionCSVExport.makeExport(transactions: [missingWalletExpense], transfers: [transfer])
        let text = try XCTUnwrap(String(data: export.data, encoding: .utf8))
        XCTAssertEqual(export.rowCount, 2)
        XCTAssertTrue(text.contains("\"Transfer\",\"\",-20,\"EUR\",\"\",\"\",\"\",\"\",22,\"USD\",\"\""))
        XCTAssertTrue(text.contains("\"Expense\",\"\",-5,\"\""))
    }

    @MainActor
    func testCSVTreatsFormulaLikeNamesAsTextAndOrdersEqualDatesConsistently() throws {
        let wallet = Wallet(name: "=1+1", startingBalance: 100, currencyCode: "EUR", walletType: "Cash")
        let transactions = ["=SUM(A1)", "+note", "-note", "@note", " \t=1"].map {
            ExpenseTransaction(amount: Decimal(string: "12.30")!, date: date(2026, 10, 7), note: $0, wallet: wallet)
        }
        let export = TransactionCSVExport.makeExport(transactions: transactions, transfers: [])
        let reversed = TransactionCSVExport.makeExport(transactions: Array(transactions.reversed()), transfers: [])
        XCTAssertEqual(export.data, reversed.data)
        let text = try XCTUnwrap(String(data: export.data, encoding: .utf8))
        XCTAssertTrue(text.contains("\"'=1+1\""))
        for note in ["=SUM(A1)", "+note", "-note", "@note", " \t=1"] {
            XCTAssertTrue(text.contains("\"'\(note)\""))
        }
        XCTAssertTrue(text.contains(",-12.3,"))
        XCTAssertEqual(transactions.first?.wallet?.name, "=1+1")
    }

    @MainActor
    func testBackupRoundTripPreservesCompleteGraphAndExactBalances() throws {
        let source = try backupContext()
        try populateBackupFixture(source)
        let original = try BackupStore.capture(context: source, appearance: .dark, now: date(2026, 10, 7))
        let bytes = try AppBackup.encode(original)
        let snapshot = try AppBackup.decode(bytes)
        XCTAssertEqual(snapshot.appearance, "dark")
        XCTAssertEqual(snapshot.createdAt, original.createdAt)
        XCTAssertEqual(snapshot.recordCount, 12)
        XCTAssertTrue(String(decoding: bytes, as: UTF8.self).contains("\"100.01\""))

        let target = try backupContext()
        target.insert(Wallet(name: "Obsolete", startingBalance: 999, currencyCode: "HUF", walletType: "Cash"))
        try target.save()
        try BackupStore.restore(snapshot, context: target)
        let wallets = try target.fetch(FetchDescriptor<Wallet>())
        let euro = try XCTUnwrap(wallets.first { $0.name == "Bank, Árvíztűrő" })
        let dollar = try XCTUnwrap(wallets.first { $0.name == "Dollar" })
        let transfers = try target.fetch(FetchDescriptor<WalletTransfer>())
        XCTAssertEqual(wallets.count, 2)
        XCTAssertEqual(euro.balance(including: transfers), Decimal(string: "118.95")!)
        XCTAssertEqual(dollar.balance(including: transfers), Decimal(string: "1.17")!)
        XCTAssertTrue(euro.allowsNegativeBalance)
        XCTAssertEqual(euro.negativeBalanceLimit, Decimal(string: "250.05")!)
        XCTAssertEqual(euro.icon, "building.columns")
        XCTAssertEqual(euro.colorName, "purple")
        XCTAssertEqual(euro.createdAt, date(2026, 9, 1))
        XCTAssertEqual(euro.transactions.count, 2)
        let category = try XCTUnwrap(target.fetch(FetchDescriptor<SpendingCategory>()).first)
        let subcategory = try XCTUnwrap(target.fetch(FetchDescriptor<SpendingSubcategory>()).first)
        XCTAssertEqual(category.subcategories.count, 1)
        XCTAssertEqual(subcategory.category?.persistentModelID, category.persistentModelID)
        XCTAssertEqual(category.createdAt, date(2026, 9, 2))
        XCTAssertEqual(subcategory.createdAt, date(2026, 9, 3))
        let budget = try XCTUnwrap(target.fetch(FetchDescriptor<Budget>()).first)
        XCTAssertEqual(budget.categories.first?.persistentModelID, category.persistentModelID)
        XCTAssertEqual(budget.seriesID, original.budgets.first?.seriesID)
        XCTAssertTrue(budget.isRecurring)
        XCTAssertEqual(budget.recurrenceType, "Monthly")
        XCTAssertEqual(budget.totalAmount, Decimal(string: "500.07")!)
        XCTAssertEqual(budget.startDate, date(2026, 10, 1))
        XCTAssertEqual(budget.endDate, date(2026, 10, 31))
        let payment = try XCTUnwrap(target.fetch(FetchDescriptor<RecurringPayment>()).first)
        XCTAssertFalse(payment.isActive)
        XCTAssertEqual(payment.scheduledPaymentDate, date(2026, 11, 1))
        XCTAssertEqual(payment.postponedUntil, date(2026, 11, 3))
        XCTAssertEqual(payment.wallet?.persistentModelID, euro.persistentModelID)
        XCTAssertEqual(payment.subcategory?.persistentModelID, subcategory.persistentModelID)
        let transactions = try target.fetch(FetchDescriptor<ExpenseTransaction>())
        let expense = try XCTUnwrap(transactions.first { $0.note == "Paid bill\n\"October\"" })
        XCTAssertEqual(expense.recurringPayment?.persistentModelID, payment.persistentModelID)
        XCTAssertEqual(expense.recurringScheduledDate, date(2026, 10, 1))
        XCTAssertEqual(expense.recurringPostponedUntil, date(2026, 10, 3))
        XCTAssertEqual(expense.category?.persistentModelID, category.persistentModelID)
        XCTAssertEqual(expense.subcategory?.persistentModelID, subcategory.persistentModelID)
        XCTAssertEqual(transactions.filter(\.isIncome).count, 1)
        XCTAssertNil(transactions.first { $0.note == "Deleted wallet" }?.wallet)
        let orphanTransfer = try XCTUnwrap(transfers.first { $0.note == "Deleted wallets" })
        XCTAssertNil(orphanTransfer.sourceWallet)
        XCTAssertNil(orphanTransfer.destinationWallet)
        XCTAssertEqual(orphanTransfer.sourceCurrencyCode, "GBP")
        XCTAssertEqual(orphanTransfer.destinationCurrencyCode, "HUF")
        let transfer = try XCTUnwrap(transfers.first { $0.note == "Exchange" })
        XCTAssertEqual(transfer.sourceWallet?.persistentModelID, euro.persistentModelID)
        XCTAssertEqual(transfer.destinationWallet?.persistentModelID, dollar.persistentModelID)
        XCTAssertEqual(try target.fetch(FetchDescriptor<Item>()).first?.timestamp, date(2026, 9, 4))
        let recaptured = try BackupStore.capture(context: target, appearance: .dark)
        XCTAssertEqual(recaptured.recordCount, snapshot.recordCount)
        XCTAssertEqual(try AppBackup.decode(AppBackup.encode(recaptured)).transactions.count, 3)
    }

    @MainActor
    func testBackupValidationRejectsInvalidFilesBeforeChangingCurrentData() throws {
        let source = try backupContext()
        try populateBackupFixture(source)
        let valid = try BackupStore.capture(context: source, appearance: .system)
        var invalid: [AppBackup.Snapshot] = []
        var sample = valid; sample.format = "AnotherApp"; invalid.append(sample)
        sample = valid; sample.version = 3; invalid.append(sample)
        sample = valid; sample.appearance = "Unknown"; invalid.append(sample)
        sample = valid; sample.wallets.append(sample.wallets[0]); invalid.append(sample)
        sample = valid; sample.transactions[0].walletID = UUID(); invalid.append(sample)
        sample = valid; sample.subcategories[0].categoryID = UUID(); invalid.append(sample)
        sample = valid; sample.budgets[0].categoryIDs = [UUID()]; invalid.append(sample)
        sample = valid; sample.transactions[0].recurringPaymentID = UUID(); invalid.append(sample)
        sample = valid; sample.transactions[0].amount = "12garbage"; invalid.append(sample)
        sample = valid; sample.transfers[0].sourceWalletID = UUID(); invalid.append(sample)
        sample = valid; sample.recurringPayments[0].subcategoryID = UUID(); invalid.append(sample)
        sample = valid; sample.createdAt = Date(timeIntervalSinceReferenceDate: 1e100); invalid.append(sample)
        sample = valid; sample.items = Array(repeating: sample.items[0], count: AppBackup.maximumRecords + 1); invalid.append(sample)
        sample = valid; sample.transfers[0].destinationAmount = "-2"; invalid.append(sample)
        sample = valid; sample.budgets[0].endDate = .distantPast; invalid.append(sample)
        let target = try backupContext()
        target.insert(Wallet(name: "Keep me", startingBalance: 50, currencyCode: "EUR", walletType: "Cash"))
        try target.save()
        for snapshot in invalid {
            XCTAssertThrowsError(try BackupStore.restore(snapshot, context: target))
            let wallets = try target.fetch(FetchDescriptor<Wallet>())
            XCTAssertEqual(wallets.count, 1)
            XCTAssertEqual(wallets.first?.name, "Keep me")
            XCTAssertFalse(target.hasChanges)
        }
        XCTAssertThrowsError(try AppBackup.decode(Data("{\"format\":\"BudgetingAppBackup\"}".utf8)))
        XCTAssertThrowsError(try AppBackup.decode(Data("not json".utf8)))
        XCTAssertThrowsError(try AppBackup.decode(Data(repeating: 0, count: AppBackup.maximumBytes + 1)))
    }

    func testBackupAmountsRejectLossOfPrecisionAndMalformedStrings() throws {
        for text in ["0", "0.05", "-100.01", "123456789012345678901234567890.12345678"] {
            XCTAssertEqual(try AppBackup.decimal(text), Decimal(string: text)!)
        }
        for text in ["NaN", "Infinity", "12foo", "1,23", "", " 2", "2 ", "01", "1.00", "1e999", "1e-999", "123456789012345678901234567890123456789.12"] {
            XCTAssertThrowsError(try AppBackup.decimal(text), text)
        }
    }

    @MainActor
    func testBackupRestoreRollsBackReplacementWhenCommitFails() throws {
        let context = try backupContext()
        try populateBackupFixture(context)
        let original = try BackupStore.capture(context: context, appearance: .light)
        var empty = original
        empty.wallets = []; empty.categories = []; empty.subcategories = []; empty.budgets = []
        empty.recurringPayments = []; empty.transactions = []; empty.transfers = []; empty.items = []
        context.autosaveEnabled = true
        XCTAssertThrowsError(try BackupStore.restore(empty, context: context) { staged in
            XCTAssertFalse(staged.autosaveEnabled)
            XCTAssertTrue(staged.hasChanges)
            throw CocoaError(.fileWriteOutOfSpace)
        })
        XCTAssertTrue(context.autosaveEnabled)
        XCTAssertFalse(context.hasChanges)
        let unchanged = try BackupStore.capture(context: context, appearance: .light)
        XCTAssertEqual(unchanged.recordCount, original.recordCount)
        XCTAssertEqual(unchanged.transactions.map(\.amount).sorted(), original.transactions.map(\.amount).sorted())
        let wallets = try context.fetch(FetchDescriptor<Wallet>())
        let transfers = try context.fetch(FetchDescriptor<WalletTransfer>())
        XCTAssertEqual(wallets.first { $0.name == "Bank, Árvíztűrő" }?.balance(including: transfers), Decimal(string: "118.95")!)
        XCTAssertNotNil(try context.fetch(FetchDescriptor<ExpenseTransaction>()).first { $0.recurringPayment != nil })
    }

    @MainActor
    func testRestoringTwiceReplacesWithoutDuplicatesAndEmptyBackupClearsAllData() throws {
        let context = try backupContext()
        try populateBackupFixture(context)
        var snapshot = try BackupStore.capture(context: context, appearance: .system)
        try BackupStore.restore(snapshot, context: context)
        try BackupStore.restore(snapshot, context: context)
        XCTAssertEqual(try BackupStore.capture(context: context, appearance: .system).recordCount, 12)
        snapshot.wallets = []; snapshot.categories = []; snapshot.subcategories = []; snapshot.budgets = []
        snapshot.recurringPayments = []; snapshot.transactions = []; snapshot.transfers = []; snapshot.items = []
        try BackupStore.restore(AppBackup.decode(AppBackup.encode(snapshot)), context: context)
        XCTAssertEqual(try BackupStore.capture(context: context, appearance: .system).recordCount, 0)
    }

    @MainActor
    func testRestoredBackupPersistsAfterReopeningStore() throws {
        let source = try backupContext()
        try populateBackupFixture(source)
        let snapshot = try BackupStore.capture(context: source, appearance: .dark)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let schema = backupSchema
        let configuration = ModelConfiguration(schema: schema, url: directory.appendingPathComponent("backup.store"), cloudKitDatabase: .none)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            context.insert(Wallet(name: "Old wallet", startingBalance: 999, currencyCode: "EUR", walletType: "Cash"))
            try context.save()
            try BackupStore.restore(snapshot, context: context)
        }
        let reopened = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(reopened)
        let restored = try BackupStore.capture(context: context, appearance: .dark)
        XCTAssertEqual(restored.recordCount, snapshot.recordCount)
        let wallets = try context.fetch(FetchDescriptor<Wallet>())
        let transfers = try context.fetch(FetchDescriptor<WalletTransfer>())
        XCTAssertEqual(wallets.first { $0.name == "Bank, Árvíztűrő" }?.balance(including: transfers), Decimal(string: "118.95")!)
        XCTAssertFalse(wallets.contains { $0.name == "Old wallet" })
        XCTAssertEqual(restored.budgets.first?.seriesID, snapshot.budgets.first?.seriesID)
        XCTAssertNotNil(restored.transactions.first { $0.recurringPaymentID != nil })
    }

    @MainActor
    func testCurrencySettingsSurviveBackupAndVersionOneBackupsStillRestore() throws {
        let source = try backupContext()
        try populateBackupFixture(source)
        let preferences = CurrencyPreferences(enabledCodes: ["JPY", "EUR"], defaultCode: "JPY", addedCodes: ["JPY", "EUR", "USD"])
        let captured = try BackupStore.capture(context: source, appearance: .dark, currencyPreferences: preferences)
        let decoded = try AppBackup.decode(AppBackup.encode(captured))
        XCTAssertEqual(decoded.version, 2)
        XCTAssertEqual(decoded.currencyPreferences, preferences)
        XCTAssertEqual(decoded.currencyPreferences?.listedCodes, ["JPY", "EUR", "USD"])
        XCTAssertFalse(try XCTUnwrap(decoded.currencyPreferences).enabledCodes.contains("USD"))
        // Previous version-2 files have enabled codes but no separate added list.
        var previousJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: AppBackup.encode(captured)) as? [String: Any])
        var previousSettings = try XCTUnwrap(previousJSON["currencyPreferences"] as? [String: Any])
        previousSettings.removeValue(forKey: "addedCodes")
        previousJSON["currencyPreferences"] = previousSettings
        let previous = try AppBackup.decode(JSONSerialization.data(withJSONObject: previousJSON))
        XCTAssertEqual(previous.currencyPreferences?.listedCodes, ["JPY", "EUR"])
        XCTAssertEqual(CurrencyPreferences.decode(try XCTUnwrap(decoded.currencyPreferences).storageValue), preferences)

        // Actual version-1 JSON has no currency settings key. Optional decoding
        // must retain that absence so the UI can leave current preferences intact.
        var legacyJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: AppBackup.encode(captured)) as? [String: Any])
        legacyJSON["version"] = 1
        legacyJSON.removeValue(forKey: "currencyPreferences")
        let legacy = try AppBackup.decode(JSONSerialization.data(withJSONObject: legacyJSON))
        XCTAssertEqual(legacy.version, 1)
        XCTAssertNil(legacy.currencyPreferences)
        let target = try backupContext()
        try BackupStore.restore(legacy, context: target)
        let restored = try target.fetch(FetchDescriptor<Wallet>())
        XCTAssertEqual(Set(restored.map(\.currencyCode)), Set(["EUR", "USD"]))
        XCTAssertEqual(try BackupStore.capture(context: target, appearance: .dark, currencyPreferences: preferences).recordCount,
                       captured.recordCount)
    }

    @MainActor
    func testInvalidBackupCurrencyPreferencesDoNotReplaceExistingData() throws {
        let context = try backupContext()
        try populateBackupFixture(context)
        let valid = try BackupStore.capture(context: context, appearance: .system, currencyPreferences: .defaults)
        let invalidSettings: [CurrencyPreferences?] = [
            nil,
            CurrencyPreferences(enabledCodes: [], defaultCode: "HUF"),
            CurrencyPreferences(enabledCodes: ["EUR", "EUR"], defaultCode: "EUR"),
            CurrencyPreferences(enabledCodes: ["EUR"], defaultCode: "HUF"),
            CurrencyPreferences(enabledCodes: ["eur"], defaultCode: "eur"),
            CurrencyPreferences(enabledCodes: ["EURO"], defaultCode: "EURO"),
            CurrencyPreferences(enabledCodes: ["EUR"], defaultCode: "EUR", addedCodes: []),
            CurrencyPreferences(enabledCodes: ["EUR"], defaultCode: "EUR", addedCodes: ["JPY"]),
            CurrencyPreferences(enabledCodes: ["EUR"], defaultCode: "EUR", addedCodes: ["EUR", "EUR"])
        ]
        for preferences in invalidSettings {
            var invalid = valid
            invalid.currencyPreferences = preferences
            XCTAssertThrowsError(try AppBackup.encode(invalid))
            XCTAssertThrowsError(try BackupStore.restore(invalid, context: context))
            XCTAssertFalse(context.hasChanges)
            XCTAssertEqual(try context.fetch(FetchDescriptor<Wallet>()).count, 2)
            XCTAssertEqual(try context.fetch(FetchDescriptor<ExpenseTransaction>()).count, 3)
        }
        var incompleteJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: AppBackup.encode(valid)) as? [String: Any])
        incompleteJSON.removeValue(forKey: "currencyPreferences")
        XCTAssertThrowsError(try AppBackup.decode(JSONSerialization.data(withJSONObject: incompleteJSON)))
    }

    @MainActor
    private var backupSchema: Schema {
        Schema([Item.self, Wallet.self, ExpenseTransaction.self, SpendingCategory.self,
                SpendingSubcategory.self, Budget.self, WalletTransfer.self, RecurringPayment.self])
    }

    @MainActor
    private func backupContext() throws -> ModelContext {
        let schema = backupSchema
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    @MainActor
    private func populateBackupFixture(_ context: ModelContext) throws {
        let euro = Wallet(name: "Bank, Árvíztűrő", startingBalance: Decimal(string: "100.01")!, currencyCode: "EUR",
                          walletType: "Bank Account", icon: "building.columns", colorName: "purple",
                          allowsNegativeBalance: true, negativeBalanceLimit: Decimal(string: "250.05")!)
        euro.createdAt = date(2026, 9, 1)
        let dollar = Wallet(name: "Dollar", startingBalance: 0, currencyCode: "USD", walletType: "Cash")
        let category = SpendingCategory(name: "Food", icon: "fork.knife", colorName: "orange")
        category.createdAt = date(2026, 9, 2)
        let subcategory = SpendingSubcategory(name: "Lunch", category: category)
        subcategory.createdAt = date(2026, 9, 3)
        let budget = Budget(name: "Monthly food", totalAmount: Decimal(string: "500.07")!, currencyCode: "EUR",
                            startDate: date(2026, 10, 1), endDate: date(2026, 10, 31), isRecurring: true)
        budget.categories = [category]
        let payment = RecurringPayment(name: "Lunch plan", amount: Decimal(string: "0.03")!, frequency: "Monthly",
                                       nextPaymentDate: date(2026, 11, 1), note: "Recurring note", isActive: false,
                                       wallet: euro, category: category, subcategory: subcategory)
        payment.postponedUntil = date(2026, 11, 3)
        for wallet in [euro, dollar] { context.insert(wallet) }
        context.insert(category); context.insert(subcategory); context.insert(budget); context.insert(payment)
        context.insert(ExpenseTransaction(amount: Decimal(string: "20.02")!, isIncome: true, date: date(2026, 10, 2), note: "Salary", wallet: euro))
        context.insert(ExpenseTransaction(amount: Decimal(string: "0.03")!, date: date(2026, 10, 3), note: "Paid bill\n\"October\"",
                                          wallet: euro, category: category, subcategory: subcategory, recurringPayment: payment,
                                          recurringScheduledDate: date(2026, 10, 1), recurringPostponedUntil: date(2026, 10, 3)))
        context.insert(ExpenseTransaction(amount: Decimal(string: "4.56")!, note: "Deleted wallet"))
        context.insert(WalletTransfer(sourceAmount: Decimal(string: "1.05")!, destinationAmount: Decimal(string: "1.17")!,
                                      date: date(2026, 10, 4), note: "Exchange", sourceWallet: euro, destinationWallet: dollar))
        context.insert(WalletTransfer(sourceAmount: 2, destinationAmount: 3, date: date(2026, 10, 5), note: "Deleted wallets",
                                      sourceWallet: nil, destinationWallet: nil, sourceCurrencyCode: "GBP",
                                      destinationCurrencyCode: "HUF", createdAt: date(2026, 10, 5)))
        context.insert(Item(timestamp: date(2026, 9, 4)))
        try context.save()
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
