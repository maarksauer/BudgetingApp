import SwiftUI
import SwiftData
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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var notificationManager = NotificationManager.shared
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedTab: AppTab = .add
    @State private var expenseDraft = ExpenseDraft()
    @State private var morePath: [MoreRoute] = []
    @State private var keyboardIsVisible = false

    var body: some View {
        VStack(spacing: 0) {
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
            // Reserve actual layout space instead of relying on a safe-area
            // inset passing through TabView's hosted navigation stacks.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            if !keyboardIsVisible {
                dock
            }
        }
        .task {
            notificationManager.refreshNotifications(context: modelContext)
            openReminderIfNeeded()
        }
        .onChange(of: notificationManager.openRequest) { _, _ in openReminderIfNeeded() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { notificationManager.refreshNotifications(context: modelContext); openReminderIfNeeded() }
        }
        .onReceive(NotificationCenter.default.publisher(for: ReminderEvents.recordsChanged)) { _ in
            notificationManager.refreshNotifications(context: modelContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            // Direct saves/autosaves also cover wallet deletion or renaming.
            notificationManager.refreshNotifications(context: modelContext)
        }
        #if os(iOS) || os(visionOS)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            notificationManager.refreshNotifications(context: modelContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardIsVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardIsVisible = false
        }
        #endif
    }

    private func openReminderIfNeeded() {
        guard let request = notificationManager.openRequest else { return }
        morePath = [.recurringPayments, .reminderPayment(request.paymentKey, request.occurrenceKey)]
        selectedTab = .more
        notificationManager.consumeOpenRequest(request.id)
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
                        if !dynamicTypeSize.isAccessibilitySize {
                            Text(tab.title).font(.caption2)
                        }
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
