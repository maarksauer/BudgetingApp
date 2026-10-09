import Foundation
import Combine
import SwiftData
@preconcurrency import UserNotifications
#if os(iOS) || os(visionOS)
import UIKit
#endif

nonisolated enum ReminderAuthorization: Equatable, Sendable {
    case notDetermined, allowed, denied, unknown
}

nonisolated struct ScheduledReminder: Equatable, Sendable {
    let identifier: String
    let userInfo: [String: String]
}

@MainActor
protocol ReminderNotificationClient: AnyObject {
    func authorizationStatus() async -> ReminderAuthorization
    func requestPermission() async throws -> Bool
    func pending() async -> [ScheduledReminder]
    func delivered() async -> [ScheduledReminder]
    func add(_ specification: ReminderSpecification, fireDate: Date) async throws
    func removePending(_ identifiers: [String])
    func removeDelivered(_ identifiers: [String])
}

@MainActor
final class SystemReminderNotificationClient: ReminderNotificationClient {
    let center: UNUserNotificationCenter
    init(center: UNUserNotificationCenter = .current()) { self.center = center }
    func authorizationStatus() async -> ReminderAuthorization {
        let settings = await center.notificationSettings()
        let status = settings.authorizationStatus
        switch status {
        case .authorized, .provisional: return .allowed
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        default: return .unknown
        }
    }
    func requestPermission() async throws -> Bool { try await center.requestAuthorization(options: [.alert, .sound, .badge]) }
    func pending() async -> [ScheduledReminder] {
        let requests = await center.pendingNotificationRequests()
        return requests.map { request in
            ScheduledReminder(identifier: request.identifier, userInfo: Self.stringInfo(request.content.userInfo))
        }
    }
    func delivered() async -> [ScheduledReminder] {
        let notifications = await center.deliveredNotifications()
        return notifications.map { notification in
            ScheduledReminder(identifier: notification.request.identifier, userInfo: Self.stringInfo(notification.request.content.userInfo))
        }
    }
    private nonisolated static func stringInfo(_ info: [AnyHashable: Any]) -> [String: String] {
        var result: [String: String] = [:]
        for key in ["paymentKey", "occurrenceKey", "fingerprint"] { result[key] = info[key] as? String }
        return result
    }
    func add(_ specification: ReminderSpecification, fireDate: Date) async throws {
        let content = UNMutableNotificationContent()
        content.title = specification.title; content.body = specification.body
        content.sound = .default; content.userInfo = specification.userInfo
        content.threadIdentifier = "recurring-payments"
        // Full calendar components keep this a one-shot notification. The app
        // schedules the next occurrence only after the payment action is saved.
        var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
        components.calendar = Calendar.current; components.timeZone = .current
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try await center.add(UNNotificationRequest(identifier: specification.paymentKey, content: content, trigger: trigger))
    }
    func removePending(_ identifiers: [String]) { if !identifiers.isEmpty { center.removePendingNotificationRequests(withIdentifiers: identifiers) } }
    func removeDelivered(_ identifiers: [String]) { if !identifiers.isEmpty { center.removeDeliveredNotifications(withIdentifiers: identifiers) } }
}

@MainActor
final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    @Published private(set) var permission: ReminderAuthorization = .notDetermined
    @Published private(set) var scheduledCount = 0
    @Published private(set) var waitingCount = 0
    @Published private(set) var lastError: String?
    @Published private(set) var openRequest: ReminderOpenRequest?

    private let client: any ReminderNotificationClient
    private let defaults: UserDefaults
    private let now: () -> Date
    private let capacity: Int
    private var snapshots: [String: RecurringReminderSnapshot] = [:]
    private var receipts: [String: ReminderReceipt]
    private var revision = 0
    private var worker: Task<Void, Never>?
    #if os(iOS)
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    #endif
    private static let receiptKey = "recurringReminderReceipts"

    init(client: (any ReminderNotificationClient)? = nil, defaults: UserDefaults = .standard,
         capacity: Int = 64, now: @escaping () -> Date = { Date() }) {
        self.client = client ?? SystemReminderNotificationClient()
        self.defaults = defaults; self.capacity = max(capacity, 0); self.now = now
        self.receipts = defaults.data(forKey: Self.receiptKey).flatMap { try? JSONDecoder().decode([String: ReminderReceipt].self, from: $0) } ?? [:]
        super.init()
    }

    func installDelegate() {
        if let system = client as? SystemReminderNotificationClient { system.center.delegate = self }
    }

    func authorizationStatus() async -> ReminderAuthorization {
        let status = await client.authorizationStatus(); permission = status; return status
    }

    func requestPermission() async -> Bool {
        do {
            let granted = try await client.requestPermission()
            _ = await authorizationStatus()
            return granted
        } catch { lastError = error.localizedDescription; return false }
    }

    func refreshNotifications(context: ModelContext) {
        do { refreshNotifications(for: try context.fetch(FetchDescriptor<RecurringPayment>())) }
        catch { lastError = "Couldn’t read recurring payments. Please try again." }
    }

    func refreshNotifications(for payments: [RecurringPayment]) {
        refresh(snapshots: payments.map { RecurringReminderSnapshot(payment: $0) })
    }

    func scheduleDueNotification(for payment: RecurringPayment) {
        let snapshot = RecurringReminderSnapshot(payment: payment)
        snapshots[snapshot.paymentKey] = snapshot
        enqueue()
    }

    func cancelNotification(for payment: RecurringPayment) {
        let key = RecurringReminderSnapshot(payment: payment).paymentKey
        snapshots.removeValue(forKey: key)
        enqueue()
    }

    func dueNotificationDate(for payment: RecurringPayment) -> Date? {
        guard let specification = ReminderPlanner.specification(for: RecurringReminderSnapshot(payment: payment), preferences: ReminderPreferences.load(defaults: defaults)) else { return nil }
        return ReminderPlanner.fireDate(for: specification, now: now())
    }

    // Immutable snapshots keep SwiftData objects out of asynchronous callbacks.
    func refresh(snapshots values: [RecurringReminderSnapshot]) {
        snapshots = Dictionary(values.map { ($0.paymentKey, $0) }, uniquingKeysWith: { _, latest in latest })
        enqueue()
    }

    private func enqueue() {
        revision += 1
        guard worker == nil else { return }
        beginBackgroundUpdate()
        worker = Task { @MainActor in
            defer { self.endBackgroundUpdate() }
            while true {
                let current = self.revision
                await self.reconcile(values: Array(self.snapshots.values), revision: current)
                if self.revision == current { break }
            }
            self.worker = nil
        }
    }

    private func beginBackgroundUpdate() {
        #if os(iOS)
        guard client is SystemReminderNotificationClient, backgroundTask == .invalid else { return }
        // Finish an in-flight save's reminder update if the user immediately
        // leaves the app. This does not run a periodic background service.
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Update recurring reminders") { @MainActor [weak self] in
            self?.endBackgroundUpdate()
        }
        #endif
    }

    private func endBackgroundUpdate() {
        #if os(iOS)
        guard backgroundTask != .invalid else { return }
        let identifier = backgroundTask
        backgroundTask = .invalid
        UIApplication.shared.endBackgroundTask(identifier)
        #endif
    }

    func waitForRefresh() async { await worker?.value }

    private func reconcile(values: [RecurringReminderSnapshot], revision current: Int) async {
        let preferences = ReminderPreferences.load(defaults: defaults)
        let status = await client.authorizationStatus()
        guard revision == current else { return }
        permission = status
        let pending = await client.pending()
        let delivered = await client.delivered()
        guard revision == current else { return }
        let specifications = status == .allowed
            ? values.compactMap { ReminderPlanner.specification(for: $0, preferences: preferences) } : []
        let desired = Dictionary(specifications.map { ($0.paymentKey, $0) }, uniquingKeysWith: { _, last in last })
        let ownPending = pending.filter { $0.identifier.hasPrefix(ReminderIdentity.prefix) }
        let ownDelivered = delivered.filter { $0.identifier.hasPrefix(ReminderIdentity.prefix) }
        let pendingByID = Dictionary(ownPending.map { ($0.identifier, $0) }, uniquingKeysWith: { _, last in last })
        // Remove only this feature's requests, and clear delivered reminders when
        // their payment is paused/deleted or the occurrence/details have changed.
        client.removePending(ownPending.filter { desired[$0.identifier] == nil }.map(\.identifier))
        client.removeDelivered(ownDelivered.filter { notification in
            guard let target = desired[notification.identifier] else { return true }
            return notification.userInfo["fingerprint"] != target.fingerprint
        }.map(\.identifier))
        receipts = receipts.filter { desired[$0.key] != nil }
        let date = now()
        for notification in ownDelivered where pendingByID[notification.identifier] == nil {
            if let target = desired[notification.identifier], notification.userInfo["occurrenceKey"] == target.occurrenceKey {
                receipts[notification.identifier] = ReminderReceipt(occurrenceKey: target.occurrenceKey, fireDate: date)
            }
        }
        let candidates = specifications.filter { spec in
            if let pending = pendingByID[spec.paymentKey], pending.userInfo["fingerprint"] == spec.fingerprint { return true }
            // Once the same occurrence has fired, opening the app (or dismissing
            // its notification) must not keep creating overdue alerts.
            if let receipt = receipts[spec.paymentKey], receipt.occurrenceKey == spec.occurrenceKey, receipt.fireDate <= date,
               pendingByID[spec.paymentKey] == nil { return false }
            return true
        }.sorted {
            $0.logicalFireDate == $1.logicalFireDate ? $0.paymentKey < $1.paymentKey : $0.logicalFireDate < $1.logicalFireDate
        }
        let available = max(capacity - pending.filter { !$0.identifier.hasPrefix(ReminderIdentity.prefix) }.count, 0)
        let selected = Array(candidates.prefix(available))
        let selectedIDs = Set(selected.map(\.paymentKey))
        let displaced = ownPending.filter { desired[$0.identifier] != nil && !selectedIDs.contains($0.identifier) }.map(\.identifier)
        client.removePending(displaced)
        // A removed request has not fired. It must remain eligible when a queue
        // slot opens, even if its original reminder time has since passed.
        for identifier in displaced { receipts.removeValue(forKey: identifier) }
        waitingCount = max(candidates.count - selected.count, 0)
        scheduledCount = 0; lastError = nil
        for specification in selected {
            guard revision == current else { persistReceipts(); return }
            if pendingByID[specification.paymentKey]?.userInfo["fingerprint"] == specification.fingerprint {
                scheduledCount += 1; continue
            }
            client.removePending([specification.paymentKey])
            client.removeDelivered([specification.paymentKey])
            receipts.removeValue(forKey: specification.paymentKey)
            let fire = ReminderPlanner.fireDate(for: specification, now: date)
            do {
                try await client.add(specification, fireDate: fire)
                receipts[specification.paymentKey] = ReminderReceipt(occurrenceKey: specification.occurrenceKey, fireDate: fire)
                scheduledCount += 1
            } catch { lastError = "Some reminders couldn’t be scheduled. Please try again. \(error.localizedDescription)" }
        }
        persistReceipts()
    }

    private func persistReceipts() {
        if let data = try? JSONEncoder().encode(receipts) { defaults.set(data, forKey: Self.receiptKey) }
    }

    func consumeOpenRequest(_ id: UUID) { if openRequest?.id == id { openRequest = nil } }

    func openPaymentReminder(paymentKey: String, occurrenceKey: String) {
        guard paymentKey.hasPrefix(ReminderIdentity.prefix) else { return }
        openRequest = ReminderOpenRequest(paymentKey: paymentKey, occurrenceKey: occurrenceKey)
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
              let key = response.notification.request.content.userInfo["paymentKey"] as? String,
              let occurrence = response.notification.request.content.userInfo["occurrenceKey"] as? String,
              key.hasPrefix(ReminderIdentity.prefix) else { return }
        await MainActor.run { self.openPaymentReminder(paymentKey: key, occurrenceKey: occurrence) }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let key = notification.request.content.userInfo["paymentKey"] as? String
        let occurrence = notification.request.content.userInfo["occurrenceKey"] as? String
        let fingerprint = notification.request.content.userInfo["fingerprint"] as? String
        return await MainActor.run {
            let preferences = ReminderPreferences.load(defaults: self.defaults)
            guard preferences.isEnabled,
                  let key, let payment = self.snapshots[key], payment.isActive,
                  payment.occurrenceKey == occurrence,
                  ReminderPlanner.specification(for: payment, preferences: preferences)?.fingerprint == fingerprint else { return [] }
            return [.banner, .list, .sound]
        }
    }
}

#if os(iOS) || os(visionOS)
@MainActor
final class BudgetNotificationAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        NotificationManager.shared.installDelegate()
        return true
    }
}
#endif
