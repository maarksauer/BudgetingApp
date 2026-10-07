import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showingAddExpense = false
    @State private var expenseDraft = ExpenseDraft()

    var body: some View {
        TabView(selection: $selectedTab) {

            DashboardView(
                openTransactions: { selectedTab = 1 },
                openBudgets: { selectedTab = 2 },
                openWallets: { selectedTab = 3 }
            )
                .modifier(AddExpenseAction(action: openAddExpense))
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            TransactionsView()
                .modifier(AddExpenseAction(action: openAddExpense))
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet")
                }
                .tag(1)

            BudgetsView()
                .modifier(AddExpenseAction(action: openAddExpense))
                .tabItem {
                    Label("Budgets", systemImage: "chart.pie")
                }
                .tag(2)

            WalletsView()
                .modifier(AddExpenseAction(action: openAddExpense))
                .tabItem {
                    Label("Wallets", systemImage: "wallet.bifold")
                }
                .tag(3)

            SettingsView()
                .modifier(AddExpenseAction(action: openAddExpense))
                .tabItem {
                    Label("More", systemImage: "gearshape")
                }
                .tag(4)
        }
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseView(draft: $expenseDraft) {
                showingAddExpense = false
            }
        }
    }

    private func openAddExpense() {
        showingAddExpense = true
    }
}

private struct AddExpenseAction: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            Button(action: action) {
                Label("Add Expense", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("openAddExpense")
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }
}
