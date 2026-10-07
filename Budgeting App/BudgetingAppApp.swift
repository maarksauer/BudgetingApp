import SwiftUI
import SwiftData

@main
struct BudgetingAppApp: App {

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
