import Foundation
import SwiftData

@Model
final class RecurringPayment {

    var name: String
    var amount: Decimal

    var frequency: String

    var scheduledPaymentDate: Date
    var postponedUntil: Date?

    var note: String

    var isActive: Bool

    var wallet: Wallet?
    var category: SpendingCategory?
    var subcategory: SpendingSubcategory?

    var createdAt: Date

    init(
        name: String,
        amount: Decimal,
        frequency: String,
        nextPaymentDate: Date,
        note: String = "",
        isActive: Bool = true,
        wallet: Wallet? = nil,
        category: SpendingCategory? = nil,
        subcategory: SpendingSubcategory? = nil
    ) {
        self.name = name
        self.amount = amount
        self.frequency = frequency

        self.scheduledPaymentDate = nextPaymentDate
        self.postponedUntil = nil

        self.note = note
        self.isActive = isActive

        self.wallet = wallet
        self.category = category
        self.subcategory = subcategory

        self.createdAt = Date()
    }

    var nextPaymentDate: Date {

        get {
            postponedUntil ?? scheduledPaymentDate
        }

        set {
            scheduledPaymentDate = newValue
            postponedUntil = nil
        }
    }

    var isPostponed: Bool {

        postponedUntil != nil
    }

    var isDue: Bool {

        guard isActive else {
            return false
        }

        let calendar =
            Calendar.current

        let today =
            calendar.startOfDay(
                for: Date()
            )

        let dueDate =
            calendar.startOfDay(
                for: nextPaymentDate
            )

        return dueDate <= today
    }

    var statusText: String {

        if !isActive {
            return "Paused"
        }

        if isDue {
            return "Due"
        }

        if isPostponed {
            return "Postponed"
        }

        return "Upcoming"
    }
}
