import Foundation
import SwiftData

@Model
final class ExpenseTransaction {

    // Default keeps previously saved transactions classified as expenses.
    var isIncome: Bool = false

    var amount: Decimal
    var date: Date
    var note: String

    var wallet: Wallet?
    var category: SpendingCategory?
    var subcategory: SpendingSubcategory?

    // MARK: - Recurring Payment

    var recurringPayment: RecurringPayment?

    var recurringScheduledDate: Date?
    var recurringPostponedUntil: Date?

    var balanceImpact: Decimal {
        isIncome ? amount : -amount
    }

    var typeName: String { isIncome ? "Income" : "Expense" }
    var amountSign: String { isIncome ? "+" : "−" }

    init(
        amount: Decimal,
        isIncome: Bool = false,
        date: Date = .now,
        note: String = "",
        wallet: Wallet? = nil,
        category: SpendingCategory? = nil,
        subcategory: SpendingSubcategory? = nil,
        recurringPayment: RecurringPayment? = nil,
        recurringScheduledDate: Date? = nil,
        recurringPostponedUntil: Date? = nil
    ) {

        self.amount = amount
        self.isIncome = isIncome
        self.date = date
        self.note = note

        self.wallet = wallet
        self.category = category
        self.subcategory = subcategory

        self.recurringPayment = recurringPayment
        self.recurringScheduledDate = recurringScheduledDate
        self.recurringPostponedUntil = recurringPostponedUntil
    }
}
