import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {

            AddExpenseView()
                .tabItem {
                    Label("Add", systemImage: "plus.circle.fill")
                }
                .tag(0)

            TransactionsView()
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet")
                }
                .tag(1)

            BudgetsView()
                .tabItem {
                    Label("Budgets", systemImage: "chart.pie")
                }
                .tag(2)

            WalletsView()
                .tabItem {
                    Label("Wallets", systemImage: "wallet.bifold")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("More", systemImage: "gearshape")
                }
                .tag(4)
        }
    }
}
