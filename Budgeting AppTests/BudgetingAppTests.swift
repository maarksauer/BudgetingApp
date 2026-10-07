import Foundation
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
}
