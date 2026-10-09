import SwiftUI
import SwiftData
#if os(iOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct PaymentReminderOptions: View {
    @Binding var settings: ReminderPreferences
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var manager = NotificationManager.shared
    @State private var requestingPermission = false

    var body: some View {
        Section("Reminder") {
            Picker("Remind Me", selection: $settings.daysBefore) {
                ForEach(ReminderPreferences.allowedLeadDays, id: \.self) { days in
                    Text(days == 0 ? "On the due date" : (days == 1 ? "1 day before" : "\(days) days before")).tag(days)
                }
            }
            .pickerStyle(.menu).accessibilityIdentifier("recurringReminderLeadDays")

            DatePicker("Time", selection: Binding(
                get: { Calendar.current.date(bySettingHour: settings.hour, minute: settings.minute, second: 0, of: Date()) ?? Date() },
                set: { date in
                    var updated = settings
                    updated.hour = Calendar.current.component(.hour, from: date)
                    updated.minute = Calendar.current.component(.minute, from: date)
                    settings = updated
                }
            ), displayedComponents: .hourAndMinute)
            .accessibilityIdentifier("recurringReminderTime")

            ReadableDetailRow(title: "Notifications", value: permissionText)
                .accessibilityIdentifier("reminderAuthorizationStatus")
            if manager.permission == .notDetermined {
                Button("Enable Notifications", action: enableNotifications)
                    .disabled(requestingPermission).accessibilityIdentifier("enableRecurringNotifications")
            } else if manager.permission == .denied {
                Text("Allow notifications in your device settings to receive this reminder.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Open Notification Settings", action: openSystemSettings)
                    .accessibilityIdentifier("openSystemNotificationSettings")
            } else if manager.permission == .unknown {
                Button("Check Notification Status") { checkPermission() }
            }
            if let error = manager.lastError {
                Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                Button("Try Again") { manager.refreshNotifications(context: modelContext) }
            }
            if manager.waitingCount > 0 {
                Text("The nearest payments are scheduled first. Open the app as payments become due to refresh later reminders.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } footer: {
            Text("\(settings.timingDescription) at \(timeText), using your device’s local time. A postponement moves this reminder too. Tap the notification to open this payment and confirm Paid.")
                .accessibilityIdentifier("recurringReminderTimingSummary")
        }
        .task { _ = await manager.authorizationStatus() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { checkPermission() } }
    }

    private var timeText: String {
        (Calendar.current.date(bySettingHour: settings.hour, minute: settings.minute, second: 0, of: Date()) ?? Date())
            .formatted(date: .omitted, time: .shortened)
    }
    private var permissionText: String {
        switch manager.permission {
        case .allowed: "Enabled"
        case .denied: "Off in Device Settings"
        case .notDetermined: "Not Enabled"
        case .unknown: "Unknown"
        }
    }
    private func checkPermission() {
        Task { @MainActor in
            _ = await manager.authorizationStatus()
            manager.refreshNotifications(context: modelContext)
        }
    }
    private func enableNotifications() {
        requestingPermission = true
        Task { @MainActor in
            if await manager.requestPermission() { manager.refreshNotifications(context: modelContext) }
            requestingPermission = false
        }
    }
    private func openSystemSettings() {
        #if os(iOS) || os(visionOS)
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
        #elseif os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") { NSWorkspace.shared.open(url) }
        #endif
    }
}


struct ReminderPaymentDestination: View {
    @Query private var payments: [RecurringPayment]
    let paymentKey: String
    let occurrenceKey: String
    var body: some View {
        if let payment = payments.first(where: { RecurringReminderSnapshot(payment: $0).paymentKey == paymentKey }) {
            RecurringPaymentDetailView(payment: payment, reminderOccurrence: occurrenceKey)
        } else {
            ContentUnavailableView("Payment No Longer Available", systemImage: "calendar.badge.exclamationmark",
                                   description: Text("This payment was deleted or replaced by a restored backup. Your saved recurring payments are available in More."))
                .navigationTitle("Payment Reminder").navigationBarTitleDisplayMode(.inline)
        }
    }
}
