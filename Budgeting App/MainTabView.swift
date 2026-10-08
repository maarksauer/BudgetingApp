import SwiftUI
#if os(iOS) || os(visionOS)
import UIKit
#endif

private enum AppTab: Int, CaseIterable {
    case overview, transactions, add, wallets, more

    var title: String {
        switch self {
        case .overview: "Overview"
        case .transactions: "Transactions"
        case .add: "Add"
        case .wallets: "Wallets"
        case .more: "More"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "chart.bar.fill"
        case .transactions: "list.bullet"
        case .add: "plus"
        case .wallets: "wallet.bifold"
        case .more: "gearshape"
        }
    }

    var accessibilityID: String {
        switch self {
        case .overview: "tabOverview"
        case .transactions: "tabTransactions"
        case .add: "tabAdd"
        case .wallets: "tabWallets"
        case .more: "tabMore"
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .add
    @State private var expenseDraft = ExpenseDraft()
    @State private var morePath: [MoreRoute] = []
    @State private var keyboardIsVisible = false

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(
                openTransactions: { selectedTab = .transactions },
                openBudgets: {
                    morePath = [.budgets]
                    selectedTab = .more
                },
                openWallets: { selectedTab = .wallets }
            )
            .toolbarVisibility(.hidden, for: .tabBar)
            .tabItem { Label("Overview", systemImage: "chart.bar.fill") }
            .tag(AppTab.overview)

            TransactionsView()
                .toolbarVisibility(.hidden, for: .tabBar)
                .tabItem { Label("Transactions", systemImage: "list.bullet") }
                .tag(AppTab.transactions)

            AddExpenseView(draft: $expenseDraft)
                .toolbarVisibility(.hidden, for: .tabBar)
                .tabItem { Label("Add", systemImage: "plus") }
                .tag(AppTab.add)

            WalletsView()
                .toolbarVisibility(.hidden, for: .tabBar)
                .tabItem { Label("Wallets", systemImage: "wallet.bifold") }
                .tag(AppTab.wallets)

            SettingsView(path: $morePath)
                .toolbarVisibility(.hidden, for: .tabBar)
                .tabItem { Label("More", systemImage: "gearshape") }
                .tag(AppTab.more)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !keyboardIsVisible {
                dock
            }
        }
        #if os(iOS) || os(visionOS)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardIsVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardIsVisible = false
        }
        #endif
    }

    private var dock: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        if tab == .add {
                            Image(systemName: tab.symbol)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 48, height: 48)
                                .background(Color.accentColor, in: Circle())
                                .overlay {
                                    Circle()
                                        .strokeBorder(.primary.opacity(selectedTab == .add ? 0.3 : 0), lineWidth: 2)
                                }
                        } else {
                            Image(systemName: tab.symbol)
                                .font(.system(size: 21, weight: .medium))
                                .frame(height: 32)
                        }
                        Text(tab.title)
                            .font(.caption2)
                    }
                    .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.secondary)
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .bottom)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab == .add ? "Add Transaction" : tab.title)
                .accessibilityIdentifier(tab.accessibilityID)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 6)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .accessibilityIdentifier("mainDock")
    }
}
