import SwiftUI
import SwiftData

@main
struct BudgetingAppApp: App {
    #if os(iOS) || os(visionOS)
    @UIApplicationDelegateAdaptor(BudgetNotificationAppDelegate.self) private var notificationDelegate
    #endif

    init() { NotificationManager.shared.installDelegate() }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Item.self,
            Wallet.self,
            ExpenseTransaction.self,
            SpendingCategory.self,
            SpendingSubcategory.self,
            Budget.self,
            WalletTransfer.self,
            RecurringPayment.self
        ])
    }
}
