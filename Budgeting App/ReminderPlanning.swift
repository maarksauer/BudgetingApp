import Foundation
import SwiftData

nonisolated struct ReminderPreferences: Codable, Equatable, Sendable {
    static let allowedLeadDays = [0, 1, 2, 3, 7]
    var isEnabled = false
    var daysBefore = 0
    var hour = 9
    var minute = 0

    var isValid: Bool {
        Self.allowedLeadDays.contains(daysBefore) && (0...23).contains(hour) && (0...59).contains(minute)
    }
    var timingDescription: String {
        daysBefore == 0 ? "On the due date" : (daysBefore == 1 ? "1 day before" : "\(daysBefore) days before")
    }
}

nonisolated enum ReminderEvents {
    static let recordsChanged = Notification.Name("budgetingReminderRecordsChanged")
}

nonisolated enum ReminderIdentity {
    static let prefix = "budgeting.recurring."
    static func paymentKey(createdAt: Date, modelID: String) -> String {
        // Creation time is the base; the saved model identity disambiguates equal
        // timestamps, including after reopening the saved store.
        prefix + String(createdAt.timeIntervalSinceReferenceDate.bitPattern, radix: 16) + "." + component(modelID)
    }
    static func component(_ string: String) -> String { Data(string.utf8).base64EncodedString() }
    static func dateKey(_ date: Date) -> String { String(date.timeIntervalSinceReferenceDate.bitPattern, radix: 16) }
}

nonisolated struct RecurringReminderSnapshot: Equatable, Sendable {
    let paymentKey: String
    let name: String
    let amountText: String
    let currency: String
    let scheduledDate: Date
    let effectiveDueDate: Date
    let isActive: Bool
    var reminder: ReminderPreferences = ReminderPreferences()
    var occurrenceKey: String { ReminderIdentity.dateKey(scheduledDate) + "." + ReminderIdentity.dateKey(effectiveDueDate) }
}

@MainActor
extension RecurringReminderSnapshot {
    init(payment: RecurringPayment) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let modelID = (try? encoder.encode(payment.persistentModelID))
            .flatMap { String(data: $0, encoding: .utf8) } ?? String(describing: payment.persistentModelID)
        self.init(paymentKey: ReminderIdentity.paymentKey(createdAt: payment.createdAt, modelID: modelID),
                  name: payment.name, amountText: payment.amount.formatted(.number), currency: payment.wallet?.currencyCode ?? "",
                  scheduledDate: payment.scheduledPaymentDate, effectiveDueDate: payment.nextPaymentDate, isActive: payment.isActive,
                  reminder: payment.reminderPreferences)
    }
}

nonisolated struct ReminderSpecification: Equatable, Sendable {
    let paymentKey: String
    let occurrenceKey: String
    let fingerprint: String
    let title: String
    let body: String
    let logicalFireDate: Date
    var userInfo: [String: String] {
        ["paymentKey": paymentKey, "occurrenceKey": occurrenceKey, "fingerprint": fingerprint]
    }
}

nonisolated enum ReminderPlanner {
    static func specification(for payment: RecurringReminderSnapshot, preferences override: ReminderPreferences? = nil,
                              calendar: Calendar = .current) -> ReminderSpecification? {
        let preferences = override ?? payment.reminder
        guard payment.isActive, preferences.isEnabled,
              payment.effectiveDueDate.timeIntervalSinceReferenceDate.isFinite,
              preferences.isValid,
              let day = calendar.date(byAdding: .day, value: -preferences.daysBefore, to: calendar.startOfDay(for: payment.effectiveDueDate)),
              let fire = calendar.date(bySettingHour: preferences.hour, minute: preferences.minute, second: 0, of: day)
        else { return nil }
        let title = preferences.daysBefore == 0 ? "Payment Due" : "Upcoming Payment"
        let amount = payment.currency.isEmpty ? payment.amountText : "\(payment.amountText) \(payment.currency)"
        let body = "\(payment.name) • \(amount)\nDue \(payment.effectiveDueDate.formatted(date: .abbreviated, time: .omitted))"
        let fingerprint = [payment.occurrenceKey, String(preferences.daysBefore), String(preferences.hour), String(preferences.minute), ReminderIdentity.dateKey(fire), title, body]
            .map { ReminderIdentity.component($0) }.joined(separator: ".")
        return ReminderSpecification(paymentKey: payment.paymentKey, occurrenceKey: payment.occurrenceKey,
                                     fingerprint: fingerprint, title: title, body: body, logicalFireDate: fire)
    }

    static func fireDate(for specification: ReminderSpecification, now: Date) -> Date {
        specification.logicalFireDate > now ? specification.logicalFireDate : now.addingTimeInterval(2)
    }
}

nonisolated struct ReminderReceipt: Codable, Equatable, Sendable {
    let occurrenceKey: String
    let fireDate: Date
}

nonisolated struct ReminderOpenRequest: Equatable, Identifiable, Sendable {
    let id: UUID
    let paymentKey: String
    let occurrenceKey: String
    init(paymentKey: String, occurrenceKey: String) {
        self.id = UUID(); self.paymentKey = paymentKey; self.occurrenceKey = occurrenceKey
    }
}
