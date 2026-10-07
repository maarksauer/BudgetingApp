import Foundation
import SwiftData

@Model
final class Budget {

    var name: String
    var totalAmount: Decimal
    var currencyCode: String
    var startDate: Date
    var endDate: Date
    var createdAt: Date

    var categories: [SpendingCategory] = []

    var isRecurring: Bool
    var recurrenceType: String

    var seriesID: UUID

    init(
        name: String,
        totalAmount: Decimal,
        currencyCode: String,
        startDate: Date,
        endDate: Date,
        isRecurring: Bool = false,
        recurrenceType: String = "Monthly",
        seriesID: UUID = UUID()
    ) {
        self.name = name
        self.totalAmount = totalAmount
        self.currencyCode = currencyCode
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = Date()

        self.isRecurring = isRecurring
        self.recurrenceType = recurrenceType
        self.seriesID = seriesID
    }
}
