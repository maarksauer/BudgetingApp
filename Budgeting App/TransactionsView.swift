import SwiftUI
import SwiftData

struct TransactionsView: View {
    @Query(sort: \ExpenseTransaction.date, order: .reverse) private var transactions: [ExpenseTransaction]
    @Query(sort: \WalletTransfer.date, order: .reverse) private var transfers: [WalletTransfer]
    @Query(sort: \Wallet.createdAt) private var wallets: [Wallet]
    @Query(sort: \SpendingCategory.name) private var categories: [SpendingCategory]
    @State private var searchText = ""
    @State private var showingFilters = false
    @State private var filters = TransactionFilters()

    private var activities: [TransactionActivity] {
        transactions.map(TransactionActivity.expense) + transfers.map(TransactionActivity.transfer)
    }

    var body: some View {
        NavigationStack {
            // Compute matching rows once so the count and day groups always agree.
            let matches = TransactionActivityList.filtered(activities, search: searchText, filters: filters)
            List {
                Section {
                    typeButtons
                    if filters.walletID != nil || filters.categoryID != nil || filters.period != .anyTime { activeFilters }
                    HStack {
                        Text("\(matches.count) \(matches.count == 1 ? "transaction" : "transactions")")
                            .accessibilityIdentifier("transactionResultCount")
                        Spacer()
                        if filters.hasActiveFilters {
                            Button("Reset") { filters = TransactionFilters() }
                                .accessibilityIdentifier("resetTransactionFilters")
                        }
                    }
                    .font(.subheadline).foregroundStyle(.secondary)
                }
                if activities.isEmpty {
                    ContentUnavailableView("No Transactions Yet", systemImage: "list.bullet.rectangle",
                                           description: Text("Income, expenses, and wallet transfers will appear here. Use the + tab to record a payment."))
                        .listRowBackground(Color.clear)
                } else if matches.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label("No Matching Transactions", systemImage: "magnifyingglass")
                        } description: {
                            Text("Try another search or remove a filter.")
                        } actions: {
                            if !searchText.isEmpty {
                                Button("Clear Search") { searchText = "" }
                                    .accessibilityIdentifier("clearTransactionSearch")
                            }
                            if filters.hasActiveFilters {
                                Button("Clear Filters") { filters = TransactionFilters() }
                            }
                        }
                        .accessibilityIdentifier("transactionNoResults")
                        .listRowBackground(Color.clear)
                    }
                } else {
                    ForEach(TransactionActivityList.grouped(matches), id: \.date) { group in
                        Section {
                            ForEach(group.activities) { activity in activityRow(activity) }
                        } header: {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(groupTitle(group.date)).font(.subheadline.weight(.semibold))
                                    if Calendar.current.isDateInToday(group.date) || Calendar.current.isDateInYesterday(group.date) {
                                        Text(group.date.formatted(date: .abbreviated, time: .omitted)).font(.caption)
                                    }
                                }
                                Spacer()
                                Text("\(group.activities.count)").font(.caption).monospacedDigit()
                            }
                            .textCase(nil).accessibilityElement(children: .combine)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Transactions")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Note, wallet, category or amount")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingFilters = true } label: {
                        Label("Filters", systemImage: filters.hasActiveFilters
                              ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Filters")
                    .accessibilityValue("\(filters.activeCount) active")
                    .accessibilityIdentifier("openTransactionFilters")
                }
            }
            .sheet(isPresented: $showingFilters) {
                TransactionFilterView(filters: filters) { filters = $0 }
            }
            .onChange(of: wallets.map(\.persistentModelID)) { _, ids in
                if let id = filters.walletID, !ids.contains(id) { filters.walletID = nil }
            }
            .onChange(of: categories.map(\.persistentModelID)) { _, ids in
                if let id = filters.categoryID, !ids.contains(id) { filters.categoryID = nil }
            }
        }
    }

    private var typeButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TransactionActivityKind.allCases) { kind in
                    Button {
                        filters.kind = kind
                        if kind == .transfers { filters.categoryID = nil }
                    } label: {
                        Text(kind.rawValue).font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14).frame(minHeight: 44)
                            .foregroundStyle(filters.kind == kind ? Color.white : Color.primary)
                            .background(filters.kind == kind ? Color.accentColor : Color.secondary.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(filters.kind == kind ? .isSelected : [])
                    .accessibilityIdentifier("transactionType-\(kind.rawValue)")
                }
            }
        }
    }

    private var activeFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let wallet = wallets.first(where: { $0.persistentModelID == filters.walletID }) {
                    filterChip(wallet.name, symbol: "wallet.bifold", identifier: "removeWalletFilter") { filters.walletID = nil }
                }
                if let category = categories.first(where: { $0.persistentModelID == filters.categoryID }) {
                    filterChip(category.name, symbol: category.icon, identifier: "removeCategoryFilter") { filters.categoryID = nil }
                }
                if filters.period != .anyTime {
                    filterChip(filters.dateLabel, symbol: "calendar", identifier: "removeDateFilter") { filters.period = .anyTime }
                }
            }
        }
    }

    private func filterChip(_ title: String, symbol: String, identifier: String, remove: @escaping () -> Void) -> some View {
        Button(action: remove) {
            HStack(spacing: 8) {
                Label(title, systemImage: symbol)
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .font(.caption.weight(.medium)).padding(.horizontal, 12).frame(minHeight: 44)
            .background(Color.secondary.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain).accessibilityLabel("Remove \(title) filter")
        .accessibilityIdentifier(identifier)
    }

    private func groupTitle(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
    }

    @ViewBuilder
    private func activityRow(_ activity: TransactionActivity) -> some View {
        switch activity {
        case .expense(let transaction):
            NavigationLink { TransactionDetailView(transaction: transaction) } label: {
                TransactionSummaryRow(
                    title: transactionTitle(transaction),
                    subtitle: transaction.isIncome ? "Income" : "Expense · \(transaction.subcategory?.name ?? transaction.category?.name ?? "Uncategorized")",
                    detail: "\(transaction.wallet?.name ?? "Missing wallet") · \(transaction.date.formatted(date: .omitted, time: .shortened))",
                    symbol: transaction.isIncome ? "arrow.down.left" : (transaction.category?.icon ?? "creditcard.fill"),
                    tint: transaction.isIncome ? .green : FormPalette.color(transaction.category?.colorName ?? "gray"),
                    amount: "\(transaction.amountSign)\(transaction.amount.formatted(.number))",
                    currency: transaction.wallet?.currencyCode ?? "", secondaryAmount: nil)
            }
            .accessibilityIdentifier("transactionRow-\(transaction.note)")
        case .transfer(let transfer):
            NavigationLink { TransferDetailView(transfer: transfer) } label: {
                TransactionSummaryRow(
                    title: "\(transfer.sourceWallet?.name ?? "Missing wallet") → \(transfer.destinationWallet?.name ?? "Missing wallet")",
                    subtitle: "Transfer", detail: transfer.note.isEmpty ? transfer.date.formatted(date: .omitted, time: .shortened) : transfer.note,
                    symbol: "arrow.left.arrow.right", tint: .blue,
                    amount: "−\(transfer.sourceAmount.formatted(.number))", currency: transfer.sourceCurrencyCode,
                    secondaryAmount: "+\(transfer.destinationAmount.formatted(.number)) \(transfer.destinationCurrencyCode)")
            }
            .accessibilityIdentifier("transferRow-\(transfer.note)")
        }
    }

    private func transactionTitle(_ transaction: ExpenseTransaction) -> String {
        let note = transaction.note.trimmingCharacters(in: .whitespacesAndNewlines)
        return note.isEmpty ? (transaction.subcategory?.name ?? transaction.category?.name ?? transaction.typeName) : note
    }
}

nonisolated enum TransactionActivityKind: String, CaseIterable, Identifiable {
    case all = "All", expenses = "Expenses", income = "Income", transfers = "Transfers"
    var id: String { rawValue }
}

nonisolated enum TransactionDatePeriod: String, CaseIterable, Identifiable {
    case anyTime = "Any Time", lastSevenDays = "Last 7 Days", thisMonth = "This Month", lastMonth = "Last Month", custom = "Custom Range"
    var id: String { rawValue }
}

struct TransactionFilters {
    var kind: TransactionActivityKind = .all
    var walletID: PersistentIdentifier?
    var categoryID: PersistentIdentifier?
    var period: TransactionDatePeriod = .anyTime
    var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    var endDate = Date()

    var activeCount: Int {
        (kind == .all ? 0 : 1) + (walletID == nil ? 0 : 1) + (categoryID == nil ? 0 : 1) + (period == .anyTime ? 0 : 1)
    }
    var hasActiveFilters: Bool { activeCount > 0 }
    var dateLabel: String {
        period == .custom
        ? "\(startDate.formatted(date: .abbreviated, time: .omitted)) – \(endDate.formatted(date: .abbreviated, time: .omitted))"
        : period.rawValue
    }

    // End is exclusive and advanced with the calendar, including daylight-saving days.
    func dateRange(now: Date, calendar: Calendar) -> Range<Date>? {
        let today = calendar.startOfDay(for: now)
        let month = calendar.dateInterval(of: .month, for: now)
        switch period {
        case .anyTime: return nil
        case .lastSevenDays:
            guard let start = calendar.date(byAdding: .day, value: -6, to: today),
                  let end = calendar.date(byAdding: .day, value: 1, to: today) else { return nil }
            return start..<end
        case .thisMonth:
            return month.map { $0.start..<$0.end }
        case .lastMonth:
            guard let start = month?.start, let previous = calendar.date(byAdding: .month, value: -1, to: start) else { return nil }
            return previous..<start
        case .custom:
            let start = calendar.startOfDay(for: min(startDate, endDate))
            guard let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: max(startDate, endDate))) else { return nil }
            return start..<end
        }
    }
}

enum TransactionActivity: Identifiable {
    case expense(ExpenseTransaction)
    case transfer(WalletTransfer)
    var id: String {
        switch self {
        case .expense(let transaction): return "expense-\(transaction.persistentModelID)"
        case .transfer(let transfer): return "transfer-\(transfer.persistentModelID)"
        }
    }
    var date: Date {
        switch self {
        case .expense(let transaction): return transaction.date
        case .transfer(let transfer): return transfer.date
        }
    }
    var kind: TransactionActivityKind {
        switch self {
        case .expense(let transaction): return transaction.isIncome ? .income : .expenses
        case .transfer: return .transfers
        }
    }
    func matchesWallet(_ id: PersistentIdentifier) -> Bool {
        switch self {
        case .expense(let transaction): return transaction.wallet?.persistentModelID == id
        case .transfer(let transfer): return transfer.sourceWallet?.persistentModelID == id || transfer.destinationWallet?.persistentModelID == id
        }
    }
    func matchesCategory(_ id: PersistentIdentifier) -> Bool {
        switch self {
        case .expense(let transaction): return transaction.category?.persistentModelID == id
        case .transfer: return false
        }
    }
    var searchFields: [String] {
        switch self {
        case .expense(let transaction):
            return [transaction.note, transaction.wallet?.name ?? "", transaction.category?.name ?? "",
                    transaction.subcategory?.name ?? "", transaction.wallet?.currencyCode ?? "", transaction.typeName,
                    NSDecimalNumber(decimal: transaction.amount).stringValue, transaction.amount.formatted(.number)]
        case .transfer(let transfer):
            return [transfer.note, transfer.sourceWallet?.name ?? "", transfer.destinationWallet?.name ?? "",
                    transfer.sourceCurrencyCode, transfer.destinationCurrencyCode, "Transfer",
                    NSDecimalNumber(decimal: transfer.sourceAmount).stringValue, transfer.sourceAmount.formatted(.number),
                    NSDecimalNumber(decimal: transfer.destinationAmount).stringValue, transfer.destinationAmount.formatted(.number)]
        }
    }
}

struct TransactionActivityDateGroup {
    let date: Date
    let activities: [TransactionActivity]
}

enum TransactionActivityList {
    static func filtered(_ activities: [TransactionActivity], search: String, filters: TransactionFilters,
                         now: Date = .now, calendar: Calendar = .current) -> [TransactionActivity] {
        let tokens = normalized(search).split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let range = filters.dateRange(now: now, calendar: calendar)
        return activities.filter { activity in
            guard filters.kind == .all || activity.kind == filters.kind else { return false }
            if let id = filters.walletID, !activity.matchesWallet(id) { return false }
            if let id = filters.categoryID, !activity.matchesCategory(id) { return false }
            if let range, !range.contains(activity.date) { return false }
            guard !tokens.isEmpty else { return true }
            let fields = activity.searchFields.map(normalized)
            return tokens.allSatisfy { token in fields.contains { $0.contains(token) } }
        }.sorted { $0.date == $1.date ? $0.id < $1.id : $0.date > $1.date }
    }

    static func grouped(_ activities: [TransactionActivity], calendar: Calendar = .current) -> [TransactionActivityDateGroup] {
        Dictionary(grouping: activities) { calendar.startOfDay(for: $0.date) }
            .map { TransactionActivityDateGroup(date: $0.key, activities: $0.value) }
            .sorted { $0.date > $1.date }
    }

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: ",", with: ".")
    }
}
