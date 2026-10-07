import SwiftUI
import SwiftData

struct TransactionsView: View {

    @Query(
        sort: \ExpenseTransaction.date,
        order: .reverse
    )
    private var transactions:
        [ExpenseTransaction]

    @Query(
        sort: \WalletTransfer.date,
        order: .reverse
    )
    private var transfers:
        [WalletTransfer]

    @State private var searchText = ""

    @State private var showingFilters = false

    @State private var selectedWallet: Wallet?
    @State private var selectedCategory: SpendingCategory?

    @State private var useDateFilter = false

    @State private var filterStartDate =
        Calendar.current.date(
            byAdding: .month,
            value: -1,
            to: Date()
        ) ?? Date()

    @State private var filterEndDate =
        Date()

    var body: some View {

        NavigationStack {

            Group {

                if allActivities.isEmpty {

                    emptyState

                } else if filteredActivities.isEmpty {

                    noResults

                } else {

                    List {

                        if hasActiveFilters {

                            Section {

                                activeFiltersView
                            }
                        }

                        ForEach(
                            groupedActivities,
                            id: \.date
                        ) { group in

                            Section(
                                groupTitle(
                                    for: group.date
                                )
                            ) {

                                ForEach(
                                    group.activities
                                ) { activity in

                                    activityRow(
                                        activity
                                    )
                                }
                            }
                        }
                    }
                }
            }

            .navigationTitle(
                "Transactions"
            )

            .searchable(
                text: $searchText,
                placement:
                    .navigationBarDrawer(
                        displayMode:
                            .automatic
                    ),
                prompt:
                    "Search transactions"
            )

            .toolbar {

                ToolbarItem(
                    placement:
                        .primaryAction
                ) {

                    Button {

                        showingFilters =
                            true

                    } label: {

                        Image(
                            systemName:
                                hasActiveFilters
                                ? "line.3.horizontal.decrease.circle.fill"
                                : "line.3.horizontal.decrease.circle"
                        )
                    }
                }
            }

            .sheet(
                isPresented:
                    $showingFilters
            ) {

                TransactionFilterView(
                    selectedWallet:
                        $selectedWallet,
                    selectedCategory:
                        $selectedCategory,
                    useDateFilter:
                        $useDateFilter,
                    startDate:
                        $filterStartDate,
                    endDate:
                        $filterEndDate
                )
            }
        }
    }

    // MARK: - All Activity

    private var allActivities:
        [TransactionActivity] {

        let expenseActivities =
            transactions.map {
                transaction in

                TransactionActivity.expense(
                    transaction
                )
            }

        let transferActivities =
            transfers.map {
                transfer in

                TransactionActivity.transfer(
                    transfer
                )
            }

        return
            (
                expenseActivities
                +
                transferActivities
            )
            .sorted {
                $0.date >
                $1.date
            }
    }

    // MARK: - Filters

    private var hasActiveFilters:
        Bool {

        selectedWallet != nil
        ||
        selectedCategory != nil
        ||
        useDateFilter
    }

    private var filteredActivities:
        [TransactionActivity] {

        allActivities.filter {
            activity in

            searchMatches(
                activity
            )
            &&
            walletMatches(
                activity
            )
            &&
            categoryMatches(
                activity
            )
            &&
            dateMatches(
                activity
            )
        }
    }

    // MARK: - Search

    private func searchMatches(
        _ activity:
            TransactionActivity
    ) -> Bool {

        let search =
            searchText
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()

        guard
            !search.isEmpty
        else {
            return true
        }

        switch activity {

        case .expense(
            let transaction
        ):

            let note =
                transaction.note
                    .lowercased()

            let wallet =
                transaction.wallet?
                    .name
                    .lowercased()
                ?? ""

            let category =
                transaction.category?
                    .name
                    .lowercased()
                ?? ""

            let subcategory =
                transaction.subcategory?
                    .name
                    .lowercased()
                ?? ""

            let amount =
                NSDecimalNumber(
                    decimal:
                        transaction.amount
                )
                .stringValue
                .lowercased()

            let currency =
                transaction.wallet?
                    .currencyCode
                    .lowercased()
                ?? ""

            return
                note.contains(search)
                ||
                wallet.contains(search)
                ||
                category.contains(search)
                ||
                subcategory.contains(search)
                ||
                amount.contains(search)
                ||
                currency.contains(search)
                ||
                transaction.typeName.lowercased().contains(search)

        case .transfer(
            let transfer
        ):

            let note =
                transfer.note
                    .lowercased()

            let sourceWallet =
                transfer.sourceWallet?
                    .name
                    .lowercased()
                ?? ""

            let destinationWallet =
                transfer.destinationWallet?
                    .name
                    .lowercased()
                ?? ""

            let sourceAmount =
                NSDecimalNumber(
                    decimal:
                        transfer.sourceAmount
                )
                .stringValue
                .lowercased()

            let destinationAmount =
                NSDecimalNumber(
                    decimal:
                        transfer.destinationAmount
                )
                .stringValue
                .lowercased()

            let sourceCurrency =
                transfer.sourceCurrencyCode
                    .lowercased()

            let destinationCurrency =
                transfer.destinationCurrencyCode
                    .lowercased()

            return
                note.contains(search)
                ||
                sourceWallet.contains(search)
                ||
                destinationWallet.contains(search)
                ||
                sourceAmount.contains(search)
                ||
                destinationAmount.contains(search)
                ||
                sourceCurrency.contains(search)
                ||
                destinationCurrency.contains(search)
                ||
                "transfer".contains(search)
        }
    }

    // MARK: - Wallet Filter

    private func walletMatches(
        _ activity:
            TransactionActivity
    ) -> Bool {

        guard
            let selectedWallet
        else {
            return true
        }

        switch activity {

        case .expense(
            let transaction
        ):

            return
                transaction.wallet?
                    .persistentModelID
                ==
                selectedWallet
                    .persistentModelID

        case .transfer(
            let transfer
        ):

            let sourceMatches =
                transfer.sourceWallet?
                    .persistentModelID
                ==
                selectedWallet
                    .persistentModelID

            let destinationMatches =
                transfer.destinationWallet?
                    .persistentModelID
                ==
                selectedWallet
                    .persistentModelID

            return
                sourceMatches
                ||
                destinationMatches
        }
    }

    // MARK: - Category Filter

    private func categoryMatches(
        _ activity:
            TransactionActivity
    ) -> Bool {

        guard
            let selectedCategory
        else {
            return true
        }

        switch activity {

        case .expense(
            let transaction
        ):

            return
                transaction.category?
                    .persistentModelID
                ==
                selectedCategory
                    .persistentModelID

        case .transfer:

            return false
        }
    }

    // MARK: - Date Filter

    private func dateMatches(
        _ activity:
            TransactionActivity
    ) -> Bool {

        guard
            useDateFilter
        else {
            return true
        }

        let calendar =
            Calendar.current

        let start =
            calendar.startOfDay(
                for:
                    filterStartDate
            )

        let end =
            calendar.startOfDay(
                for:
                    filterEndDate
            )

        let dayAfterEnd =
            calendar.date(
                byAdding: .day,
                value: 1,
                to: end
            )
            ??
            filterEndDate

        return
            activity.date >= start
            &&
            activity.date < dayAfterEnd
    }

    // MARK: - Active Filters

    private var activeFiltersView:
        some View {

        ScrollView(
            .horizontal,
            showsIndicators: false
        ) {

            HStack(
                spacing: 8
            ) {

                if let selectedWallet {

                    filterChip(
                        title:
                            selectedWallet.name,
                        systemImage:
                            "wallet.bifold"
                    )
                }

                if let selectedCategory {

                    filterChip(
                        title:
                            selectedCategory.name,
                        systemImage:
                            selectedCategory.icon
                    )
                }

                if useDateFilter {

                    filterChip(
                        title:
                            "\(filterStartDate.formatted(date: .abbreviated, time: .omitted)) – \(filterEndDate.formatted(date: .abbreviated, time: .omitted))",
                        systemImage:
                            "calendar"
                    )
                }
            }
        }
    }

    private func filterChip(
        title: String,
        systemImage: String
    ) -> some View {

        Label(
            title,
            systemImage:
                systemImage
        )
        .font(.caption)
        .padding(
            .horizontal,
            10
        )
        .padding(
            .vertical,
            6
        )
        .background(
            .thinMaterial
        )
        .clipShape(
            Capsule()
        )
    }

    // MARK: - Grouping

    private var groupedActivities:
        [TransactionActivityDateGroup] {

        let calendar =
            Calendar.current

        let grouped =
            Dictionary(
                grouping:
                    filteredActivities
            ) {
                activity in

                calendar.startOfDay(
                    for:
                        activity.date
                )
            }

        return
            grouped
                .map {
                    date,
                    activities in

                    TransactionActivityDateGroup(
                        date:
                            date,
                        activities:
                            activities.sorted {
                                $0.date >
                                $1.date
                            }
                    )
                }
                .sorted {
                    $0.date >
                    $1.date
                }
    }

    private func groupTitle(
        for date: Date
    ) -> String {

        let calendar =
            Calendar.current

        if calendar.isDateInToday(
            date
        ) {

            return "Today"
        }

        if calendar.isDateInYesterday(
            date
        ) {

            return "Yesterday"
        }

        return date.formatted(
            date: .abbreviated,
            time: .omitted
        )
    }

    // MARK: - Activity Row

    @ViewBuilder
    private func activityRow(
        _ activity:
            TransactionActivity
    ) -> some View {

        switch activity {

        case .expense(
            let transaction
        ):

            NavigationLink {

                TransactionDetailView(
                    transaction:
                        transaction
                )

            } label: {

                expenseRow(
                    transaction
                )
            }

        case .transfer(
            let transfer
        ):

            NavigationLink {

                TransferDetailView(
                    transfer:
                        transfer
                )

            } label: {

                transferRow(
                    transfer
                )
            }
        }
    }

    // MARK: - Expense Row

    private func expenseRow(
        _ transaction:
            ExpenseTransaction
    ) -> some View {

        HStack(
            spacing: 14
        ) {

            categoryIcon(
                for:
                    transaction
            )

            VStack(
                alignment: .leading,
                spacing: 4
            ) {

                Text(
                    displayTitle(
                        for:
                            transaction
                    )
                )
                .fontWeight(
                    .medium
                )

                HStack(
                    spacing: 6
                ) {

                    if let wallet =
                        transaction.wallet {

                        Text(
                            wallet.name
                        )

                        Text("•")
                    }

                    Text(transaction.typeName)
                    Text("•")

                    Text(
                        transaction.date
                            .formatted(
                                date:
                                    .omitted,
                                time:
                                    .shortened
                            )
                    )
                }
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()

            VStack(
                alignment: .trailing,
                spacing: 3
            ) {

                Text(
                    "\(transaction.amountSign)\(transaction.amount.formatted(.number))"
                )
                .foregroundStyle(transaction.isIncome ? Color.green : Color.primary)
                .fontWeight(
                    .semibold
                )

                Text(
                    transaction.wallet?
                        .currencyCode
                    ?? ""
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }
        }
        .padding(
            .vertical,
            4
        )
    }

    // MARK: - Transfer Row

    private func transferRow(
        _ transfer:
            WalletTransfer
    ) -> some View {

        HStack(
            spacing: 14
        ) {

            Image(
                systemName:
                    "arrow.left.arrow.right"
            )
            .foregroundStyle(
                .blue
            )
            .frame(
                width: 40,
                height: 40
            )
            .background(
                .blue.opacity(0.12)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 11
                )
            )

            VStack(
                alignment: .leading,
                spacing: 4
            ) {

                Text(
                    "\(transfer.sourceWallet?.name ?? "Wallet") → \(transfer.destinationWallet?.name ?? "Wallet")"
                )
                .fontWeight(
                    .medium
                )

                if transfer.note.isEmpty {

                    Text("Transfer")
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )

                } else {

                    Text(
                        transfer.note
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
            }

            Spacer()

            VStack(
                alignment: .trailing,
                spacing: 3
            ) {

                if transfer.sourceCurrencyCode
                    ==
                    transfer.destinationCurrencyCode {

                    Text(
                        transfer.sourceAmount,
                        format: .number
                    )
                    .fontWeight(
                        .semibold
                    )

                    Text(
                        transfer.sourceCurrencyCode
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                } else {

                    Text(
                        "\(transfer.sourceAmount.formatted(.number)) \(transfer.sourceCurrencyCode)"
                    )
                    .fontWeight(
                        .semibold
                    )

                    Text(
                        "→ \(transfer.destinationAmount.formatted(.number)) \(transfer.destinationCurrencyCode)"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
            }
        }
        .padding(
            .vertical,
            4
        )
    }

    // MARK: - Expense Helpers

    private func displayTitle(
        for transaction:
            ExpenseTransaction
    ) -> String {

        let cleanedNote =
            transaction.note
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        if !cleanedNote.isEmpty {

            return cleanedNote
        }

        if let subcategory =
            transaction.subcategory {

            return subcategory.name
        }

        if let category =
            transaction.category {

            return category.name
        }

        return transaction.typeName
    }

    @ViewBuilder
    private func categoryIcon(
        for transaction:
            ExpenseTransaction
    ) -> some View {

        if transaction.isIncome {
            Image(systemName: "arrow.down.left")
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 11))
        } else if let category =
            transaction.category {

            Image(
                systemName:
                    category.icon
            )
            .foregroundStyle(
                .white
            )
            .frame(
                width: 40,
                height: 40
            )
            .background(
                colorFromName(
                    category.colorName
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 11
                )
            )

        } else {

            Image(
                systemName:
                    "creditcard.fill"
            )
            .foregroundStyle(
                .white
            )
            .frame(
                width: 40,
                height: 40
            )
            .background(
                .gray
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 11
                )
            )
        }
    }

    // MARK: - Empty States

    private var emptyState:
        some View {

        VStack(
            spacing: 16
        ) {

            Image(
                systemName:
                    "list.bullet.rectangle"
            )
            .font(
                .system(
                    size: 46
                )
            )
            .foregroundStyle(
                .secondary
            )

            Text(
                "No Transactions Yet"
            )
            .font(
                .title3
            )
            .fontWeight(
                .semibold
            )

            Text(
                "Income, expenses, and wallet transfers will appear here."
            )
            .foregroundStyle(
                .secondary
            )
            .multilineTextAlignment(
                .center
            )
        }
        .padding()
    }

    private var noResults:
        some View {

        VStack(
            spacing: 16
        ) {

            Image(
                systemName:
                    "line.3.horizontal.decrease.circle"
            )
            .font(
                .system(
                    size: 42
                )
            )
            .foregroundStyle(
                .secondary
            )

            Text(
                "No Results"
            )
            .font(
                .title3
            )
            .fontWeight(
                .semibold
            )

            Text(
                hasActiveFilters
                ? "No activity matches your current filters."
                : "No activity matches your search."
            )
            .foregroundStyle(
                .secondary
            )
            .multilineTextAlignment(
                .center
            )

            if hasActiveFilters {

                Button(
                    "Clear Filters"
                ) {

                    clearFilters()
                }
                .buttonStyle(
                    .borderedProminent
                )
            }
        }
        .padding()
    }

    private func clearFilters() {

        selectedWallet =
            nil

        selectedCategory =
            nil

        useDateFilter =
            false

        filterStartDate =
            Calendar.current.date(
                byAdding: .month,
                value: -1,
                to: Date()
            )
            ??
            Date()

        filterEndDate =
            Date()
    }

    // MARK: - Colors

    private func colorFromName(
        _ name: String
    ) -> Color {

        switch name {

        case "blue":
            return .blue

        case "green":
            return .green

        case "orange":
            return .orange

        case "purple":
            return .purple

        case "red":
            return .red

        case "pink":
            return .pink

        case "teal":
            return .teal

        case "gray":
            return .gray

        default:
            return .blue
        }
    }
}


// MARK: - Combined Activity

private enum TransactionActivity:
    Identifiable {

    case expense(
        ExpenseTransaction
    )

    case transfer(
        WalletTransfer
    )

    var id: String {

        switch self {

        case .expense(
            let transaction
        ):

            return
                "expense-\(transaction.persistentModelID)"

        case .transfer(
            let transfer
        ):

            return
                "transfer-\(transfer.persistentModelID)"
        }
    }

    var date: Date {

        switch self {

        case .expense(
            let transaction
        ):

            return
                transaction.date

        case .transfer(
            let transfer
        ):

            return
                transfer.date
        }
    }
}


// MARK: - Date Group

private struct TransactionActivityDateGroup {

    let date: Date

    let activities:
        [TransactionActivity]
}
