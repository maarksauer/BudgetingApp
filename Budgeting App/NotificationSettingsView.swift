import SwiftUI
import SwiftData
#if os(iOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct RecurringReminderSettings: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(ReminderPreferences.storageKey) private var storedPreferences = ReminderPreferences().storageValue
    @ObservedObject private var manager = NotificationManager.shared
    @State private var enabling = false
    @State private var isExpanded = false
    private var preferences: ReminderPreferences { ReminderPreferences.decode(storedPreferences) }

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $isExpanded) {
                Toggle("Payment Reminders", isOn: Binding(
                    get: { preferences.isEnabled },
                    set: { value in var settings = preferences; settings.isEnabled = value; storedPreferences = settings.storageValue }
                ))
                .disabled(manager.permission != .allowed || enabling)
                .accessibilityIdentifier("recurringRemindersEnabled")

                if manager.permission == .notDetermined {
                    Button("Enable Notifications", action: enable)
                        .disabled(enabling).accessibilityIdentifier("enableRecurringNotifications")
                } else if manager.permission == .denied {
                    Text("Notifications are disabled in your device settings.").foregroundStyle(.secondary)
                    Button("Open Notification Settings", action: openSystemSettings)
                        .accessibilityIdentifier("openSystemNotificationSettings")
                } else if manager.permission == .unknown {
                    Button("Check Notification Status") { manager.refreshNotifications(context: modelContext) }
                }

                Picker("Remind Me", selection: Binding(
                    get: { preferences.daysBefore },
                    set: { value in var settings = preferences; settings.daysBefore = value; storedPreferences = settings.storageValue }
                )) {
                    ForEach(ReminderPreferences.allowedLeadDays, id: \.self) { days in
                        Text(days == 0 ? "On the due date" : (days == 1 ? "1 day before" : "\(days) days before")).tag(days)
                    }
                }
                .pickerStyle(.menu).accessibilityIdentifier("recurringReminderLeadDays")

                DatePicker("Time", selection: Binding(
                    get: { Calendar.current.date(bySettingHour: preferences.hour, minute: preferences.minute, second: 0, of: Date()) ?? Date() },
                    set: { date in
                        var settings = preferences
                        settings.hour = Calendar.current.component(.hour, from: date)
                        settings.minute = Calendar.current.component(.minute, from: date)
                        storedPreferences = settings.storageValue
                    }
                ), displayedComponents: .hourAndMinute)
                .accessibilityIdentifier("recurringReminderTime")

                Text("\(preferences.timingDescription) at \(timeText), using your device’s local time. Applies to all active recurring payments; postponed payments use their postponed due date.")
                    .font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("recurringReminderTimingSummary")
                Text("Tap a reminder to open the payment and confirm Paid. Reminders never record payments automatically.")
                    .font(.caption).foregroundStyle(.secondary)

                if manager.permission == .allowed && preferences.isEnabled {
                    ReadableDetailRow(title: "Pending Reminders", value: "\(manager.scheduledCount)")
                    if manager.waitingCount > 0 {
                        Text("\(manager.waitingCount) later reminders are waiting. The nearest payments are scheduled first; open the app as payments become due to refresh the queue.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Button("Refresh Reminders") { manager.refreshNotifications(context: modelContext) }
                        .accessibilityIdentifier("refreshRecurringNotifications")
                }
                if let error = manager.lastError {
                    Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                    Button("Try Again") { manager.refreshNotifications(context: modelContext) }
                }
            } label: {
                AdaptiveValueRow {
                    Label("Reminders", systemImage: "bell")
                } trailing: {
                    Text(statusText).foregroundStyle(.secondary)
                        .accessibilityIdentifier("reminderAuthorizationStatus")
                }
            }
            .accessibilityIdentifier("recurringReminderSettings")
        }
        .task {
            if manager.lastError != nil { isExpanded = true }
            manager.refreshNotifications(context: modelContext)
        }
        .onChange(of: storedPreferences) { _, _ in manager.refreshNotifications(context: modelContext) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { manager.refreshNotifications(context: modelContext) }
        }
        .onChange(of: manager.lastError) { _, error in
            if error != nil { isExpanded = true }
        }
    }

    private var timeText: String {
        (Calendar.current.date(bySettingHour: preferences.hour, minute: preferences.minute, second: 0, of: Date()) ?? Date())
            .formatted(date: .omitted, time: .shortened)
    }
    private var statusText: String {
        switch manager.permission {
        case .allowed: return preferences.isEnabled ? "On" : "Off"
        case .denied: return "Off"
        case .notDetermined: return "Not Enabled"
        case .unknown: return "Unknown"
        }
    }
    private func enable() {
        enabling = true
        Task { @MainActor in
            if await manager.requestPermission() {
                var settings = preferences; settings.isEnabled = true; storedPreferences = settings.storageValue
                manager.refreshNotifications(context: modelContext)
            }
            enabling = false
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
