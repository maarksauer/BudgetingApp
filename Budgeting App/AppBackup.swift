import Foundation
import SwiftData

// Portable values only. No SwiftData object or persistent identifier crosses
// the file boundary; IDs below link records within this particular backup.
nonisolated enum AppBackup {
    static let format = "BudgetingAppBackup"
    static let version = 1
    static let maximumBytes = 32 * 1024 * 1024
    static let maximumRecords = 100_000
    static let restoreRevisionKey = "dataRestoreRevision"
    static let restoreNoticeKey = "showDataRestoreNotice"

    nonisolated enum BackupError: LocalizedError {
        case invalid(String)
        var errorDescription: String? {
            switch self {
            case .invalid(let reason): return reason
            }
        }
    }

    nonisolated struct Snapshot: Codable, Sendable {
        var format: String = AppBackup.format
        var version: Int = AppBackup.version
        var createdAt: Date
        var appearance: String
        var wallets: [WalletRecord]
        var categories: [CategoryRecord]
        var subcategories: [SubcategoryRecord]
        var budgets: [BudgetRecord]
        var recurringPayments: [PaymentRecord]
        var transactions: [TransactionRecord]
        var transfers: [TransferRecord]
        var items: [ItemRecord]

        var recordCount: Int {
            wallets.count + categories.count + subcategories.count + budgets.count +
            recurringPayments.count + transactions.count + transfers.count + items.count
        }
    }

    nonisolated struct WalletRecord: Codable, Sendable, Identifiable {
        var id: UUID
        var name: String
        var startingBalance: String
        var currencyCode: String
        var walletType: String
        var icon: String
        var colorName: String
        var createdAt: Date
        var allowsNegativeBalance: Bool
        var negativeBalanceLimit: String
    }

    nonisolated struct CategoryRecord: Codable, Sendable, Identifiable {
        var id: UUID
        var name: String
        var icon: String
        var colorName: String
        var createdAt: Date
    }

    nonisolated struct SubcategoryRecord: Codable, Sendable, Identifiable {
        var id: UUID
        var name: String
        var createdAt: Date
        var categoryID: UUID?
    }

    nonisolated struct BudgetRecord: Codable, Sendable, Identifiable {
        var id: UUID
        var name: String
        var totalAmount: String
        var currencyCode: String
        var startDate: Date
        var endDate: Date
        var createdAt: Date
        var categoryIDs: [UUID]
        var isRecurring: Bool
        var recurrenceType: String
        var seriesID: UUID
    }

    nonisolated struct PaymentRecord: Codable, Sendable, Identifiable {
        var id: UUID
        var name: String
        var amount: String
        var frequency: String
        var scheduledPaymentDate: Date
        var postponedUntil: Date?
        var note: String
        var isActive: Bool
        var walletID: UUID?
        var categoryID: UUID?
        var subcategoryID: UUID?
        var createdAt: Date
    }

    nonisolated struct TransactionRecord: Codable, Sendable, Identifiable {
        var id: UUID
        var isIncome: Bool
        var amount: String
        var date: Date
        var note: String
        var walletID: UUID?
        var categoryID: UUID?
        var subcategoryID: UUID?
        var recurringPaymentID: UUID?
        var recurringScheduledDate: Date?
        var recurringPostponedUntil: Date?
    }

    nonisolated struct TransferRecord: Codable, Sendable, Identifiable {
        var id: UUID
        var sourceAmount: String
        var destinationAmount: String
        var date: Date
        var note: String
        var sourceWalletID: UUID?
        var destinationWalletID: UUID?
        var sourceCurrencyCode: String
        var destinationCurrencyCode: String
        var createdAt: Date
    }

    nonisolated struct ItemRecord: Codable, Sendable, Identifiable {
        var id: UUID
        var timestamp: Date
    }

    static func encode(_ snapshot: Snapshot) throws -> Data {
        try validate(snapshot)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        guard data.count <= maximumBytes else {
            throw BackupError.invalid("This backup exceeds the 32 MB size limit.")
        }
        return data
    }

    static func decode(_ data: Data) throws -> Snapshot {
        guard data.count <= maximumBytes else {
            throw BackupError.invalid("Choose a backup smaller than 32 MB.")
        }
        let snapshot: Snapshot
        do {
            snapshot = try JSONDecoder().decode(Snapshot.self, from: data)
        } catch {
            throw BackupError.invalid("This file is not a complete Budgeting App backup, or it is damaged.")
        }
        try validate(snapshot)
        return snapshot
    }

    static func decimal(_ text: String) throws -> Decimal {
        // Only canonical Decimal strings written by this app are accepted.
        // This also rejects partial parses, NaN, overflow and silently rounded input.
        guard text.count <= 200,
              text.range(of: #"^-?[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$"#,
                         options: .regularExpression) != nil,
              let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")),
              !value.isNaN,
              NSDecimalNumber(decimal: value).stringValue == text else {
            throw BackupError.invalid("The backup contains an invalid or imprecise amount.")
        }
        return value
    }

    static func validate(_ snapshot: Snapshot) throws {
        guard snapshot.format == format else {
            throw BackupError.invalid("Choose a Budgeting App backup JSON file.")
        }
        guard snapshot.version == version else {
            throw BackupError.invalid("This backup version is not supported. Try the app version that created it.")
        }
        guard AppAppearance(rawValue: snapshot.appearance) != nil else {
            throw BackupError.invalid("The backup contains an unknown appearance preference.")
        }
        guard snapshot.recordCount <= maximumRecords else {
            throw BackupError.invalid("This backup exceeds the 100,000 record limit.")
        }
        try dates([snapshot.createdAt])
        let wallets = try identifiers(snapshot.wallets)
        let categories = try identifiers(snapshot.categories)
        let subcategories = try identifiers(snapshot.subcategories)
        let payments = try identifiers(snapshot.recurringPayments)
        _ = try identifiers(snapshot.budgets)
        _ = try identifiers(snapshot.transactions)
        _ = try identifiers(snapshot.transfers)
        _ = try identifiers(snapshot.items)
        for record in snapshot.wallets {
            _ = try decimal(record.startingBalance)
            try nonnegative(record.negativeBalanceLimit)
            try dates([record.createdAt])
        }
        for record in snapshot.categories { try dates([record.createdAt]) }
        for record in snapshot.subcategories {
            try reference(record.categoryID, in: categories)
            try dates([record.createdAt])
        }
        for record in snapshot.budgets {
            try nonnegative(record.totalAmount)
            try dates([record.startDate, record.endDate, record.createdAt])
            guard record.startDate <= record.endDate else {
                throw BackupError.invalid("A budget has an invalid date range.")
            }
            for id in record.categoryIDs { try reference(id, in: categories) }
        }
        for record in snapshot.recurringPayments {
            try nonnegative(record.amount)
            try reference(record.walletID, in: wallets)
            try reference(record.categoryID, in: categories)
            try reference(record.subcategoryID, in: subcategories)
            try dates([record.scheduledPaymentDate, record.postponedUntil, record.createdAt])
        }
        for record in snapshot.transactions {
            try nonnegative(record.amount)
            try reference(record.walletID, in: wallets)
            try reference(record.categoryID, in: categories)
            try reference(record.subcategoryID, in: subcategories)
            try reference(record.recurringPaymentID, in: payments)
            try dates([record.date, record.recurringScheduledDate, record.recurringPostponedUntil])
        }
        for record in snapshot.transfers {
            try nonnegative(record.sourceAmount)
            try nonnegative(record.destinationAmount)
            try reference(record.sourceWalletID, in: wallets)
            try reference(record.destinationWalletID, in: wallets)
            try dates([record.date, record.createdAt])
        }
        for record in snapshot.items { try dates([record.timestamp]) }
    }

    private static func identifiers<T: Identifiable>(_ records: [T]) throws -> Set<UUID> where T.ID == UUID {
        let ids = Set(records.map(\.id))
        guard ids.count == records.count else {
            throw BackupError.invalid("The backup contains duplicate record identifiers.")
        }
        return ids
    }

    private static func reference(_ id: UUID?, in identifiers: Set<UUID>) throws {
        if let id, !identifiers.contains(id) {
            throw BackupError.invalid("The backup contains a link to a missing record.")
        }
    }

    private static func nonnegative(_ text: String) throws {
        guard try decimal(text) >= 0 else {
            throw BackupError.invalid("The backup contains a negative transaction amount or limit.")
        }
    }

    private static func dates(_ values: [Date?]) throws {
        guard values.allSatisfy({ value in
            guard let value else { return true }
            return value.timeIntervalSinceReferenceDate.isFinite &&
                value >= Date.distantPast && value <= Date.distantFuture
        }) else {
            throw BackupError.invalid("The backup contains an invalid date.")
        }
    }

    static func filename(date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "Budgeting-Backup-\(formatter.string(from: date)).json"
    }

    static func read(from url: URL) throws -> Snapshot {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard size.isRegularFile == true, (size.fileSize ?? 0) <= maximumBytes else {
            throw BackupError.invalid("Choose a backup JSON file smaller than 32 MB.")
        }
        return try decode(Data(contentsOf: url, options: .mappedIfSafe))
    }

    static func recoveryURL() throws -> URL {
        let directory = try FileManager.default.url(for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("BackupRecovery", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("Budgeting-Before-Last-Restore.json")
    }

    static var hasRecoveryBackup: Bool {
        guard let url = try? recoveryURL() else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
}

// Model work stays on the main actor. The same context drives @Query updates.
@MainActor
enum BackupStore {
    private static func amount(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    private static func ids<T: PersistentModel>(_ models: [T]) -> [PersistentIdentifier: UUID] {
        Dictionary(uniqueKeysWithValues: models.map { ($0.persistentModelID, UUID()) })
    }

    private static func id<T: PersistentModel>(_ model: T?, in identifiers: [PersistentIdentifier: UUID]) throws -> UUID? {
        guard let model else { return nil }
        guard let id = identifiers[model.persistentModelID] else {
            throw AppBackup.BackupError.invalid("A saved record has a missing link. Close any edits and try again.")
        }
        return id
    }

    static func capture(context: ModelContext, appearance: AppAppearance, now: Date = .now) throws -> AppBackup.Snapshot {
        try context.save()
        let wallets = try context.fetch(FetchDescriptor<Wallet>())
        let categories = try context.fetch(FetchDescriptor<SpendingCategory>())
        let subcategories = try context.fetch(FetchDescriptor<SpendingSubcategory>())
        let budgets = try context.fetch(FetchDescriptor<Budget>())
        let payments = try context.fetch(FetchDescriptor<RecurringPayment>())
        let transactions = try context.fetch(FetchDescriptor<ExpenseTransaction>())
        let transfers = try context.fetch(FetchDescriptor<WalletTransfer>())
        let items = try context.fetch(FetchDescriptor<Item>())
        let walletIDs = ids(wallets), categoryIDs = ids(categories), subcategoryIDs = ids(subcategories), paymentIDs = ids(payments)
        let snapshot = try AppBackup.Snapshot(
            createdAt: now, appearance: appearance.rawValue,
            wallets: wallets.map { wallet in
                AppBackup.WalletRecord(id: walletIDs[wallet.persistentModelID]!, name: wallet.name,
                    startingBalance: amount(wallet.startingBalance), currencyCode: wallet.currencyCode,
                    walletType: wallet.walletType, icon: wallet.icon, colorName: wallet.colorName,
                    createdAt: wallet.createdAt, allowsNegativeBalance: wallet.allowsNegativeBalance,
                    negativeBalanceLimit: amount(wallet.negativeBalanceLimit))
            },
            categories: categories.map { category in
                AppBackup.CategoryRecord(id: categoryIDs[category.persistentModelID]!, name: category.name,
                    icon: category.icon, colorName: category.colorName, createdAt: category.createdAt)
            },
            subcategories: subcategories.map { subcategory in
                AppBackup.SubcategoryRecord(id: subcategoryIDs[subcategory.persistentModelID]!, name: subcategory.name,
                    createdAt: subcategory.createdAt, categoryID: try id(subcategory.category, in: categoryIDs))
            },
            budgets: budgets.map { budget in
                AppBackup.BudgetRecord(id: UUID(), name: budget.name, totalAmount: amount(budget.totalAmount),
                    currencyCode: budget.currencyCode, startDate: budget.startDate, endDate: budget.endDate,
                    createdAt: budget.createdAt, categoryIDs: try budget.categories.map { try id($0, in: categoryIDs)! },
                    isRecurring: budget.isRecurring, recurrenceType: budget.recurrenceType, seriesID: budget.seriesID)
            },
            recurringPayments: payments.map { payment in
                AppBackup.PaymentRecord(id: paymentIDs[payment.persistentModelID]!, name: payment.name,
                    amount: amount(payment.amount), frequency: payment.frequency, scheduledPaymentDate: payment.scheduledPaymentDate,
                    postponedUntil: payment.postponedUntil, note: payment.note, isActive: payment.isActive,
                    walletID: try id(payment.wallet, in: walletIDs), categoryID: try id(payment.category, in: categoryIDs),
                    subcategoryID: try id(payment.subcategory, in: subcategoryIDs), createdAt: payment.createdAt)
            },
            transactions: transactions.map { transaction in
                AppBackup.TransactionRecord(id: UUID(), isIncome: transaction.isIncome, amount: amount(transaction.amount),
                    date: transaction.date, note: transaction.note, walletID: try id(transaction.wallet, in: walletIDs),
                    categoryID: try id(transaction.category, in: categoryIDs), subcategoryID: try id(transaction.subcategory, in: subcategoryIDs),
                    recurringPaymentID: try id(transaction.recurringPayment, in: paymentIDs),
                    recurringScheduledDate: transaction.recurringScheduledDate, recurringPostponedUntil: transaction.recurringPostponedUntil)
            },
            transfers: transfers.map { transfer in
                AppBackup.TransferRecord(id: UUID(), sourceAmount: amount(transfer.sourceAmount), destinationAmount: amount(transfer.destinationAmount),
                    date: transfer.date, note: transfer.note, sourceWalletID: try id(transfer.sourceWallet, in: walletIDs),
                    destinationWalletID: try id(transfer.destinationWallet, in: walletIDs), sourceCurrencyCode: transfer.sourceCurrencyCode,
                    destinationCurrencyCode: transfer.destinationCurrencyCode, createdAt: transfer.createdAt)
            },
            items: items.map { AppBackup.ItemRecord(id: UUID(), timestamp: $0.timestamp) }
        )
        try AppBackup.validate(snapshot)
        return snapshot
    }

    // All replacement changes are saved together. A failure discards pending
    // deletes and inserts; autosave cannot commit a partly restored graph.
    static func restore(_ snapshot: AppBackup.Snapshot, context: ModelContext,
                        commit: (ModelContext) throws -> Void = { try $0.save() }) throws {
        try AppBackup.validate(snapshot)
        try context.save()
        let previousAutosave = context.autosaveEnabled
        context.autosaveEnabled = false
        defer { context.autosaveEnabled = previousAutosave }
        do {
            try removeAll(context)
            try insert(snapshot, context: context)
            try commit(context)
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func removeAll(_ context: ModelContext) throws {
        // Fetch all objects before deleting anything; never use bulk deletes,
        // which could commit outside the final save operation.
        let transactions = try context.fetch(FetchDescriptor<ExpenseTransaction>())
        let transfers = try context.fetch(FetchDescriptor<WalletTransfer>())
        let payments = try context.fetch(FetchDescriptor<RecurringPayment>())
        let budgets = try context.fetch(FetchDescriptor<Budget>())
        let subcategories = try context.fetch(FetchDescriptor<SpendingSubcategory>())
        let categories = try context.fetch(FetchDescriptor<SpendingCategory>())
        let wallets = try context.fetch(FetchDescriptor<Wallet>())
        let items = try context.fetch(FetchDescriptor<Item>())
        for model in transactions { context.delete(model) }
        for model in transfers { context.delete(model) }
        for model in payments { context.delete(model) }
        for model in budgets { context.delete(model) }
        for model in subcategories { context.delete(model) }
        for model in categories { context.delete(model) }
        for model in wallets { context.delete(model) }
        for model in items { context.delete(model) }
    }

    private static func insert(_ snapshot: AppBackup.Snapshot, context: ModelContext) throws {
        var wallets: [UUID: Wallet] = [:]
        var categories: [UUID: SpendingCategory] = [:]
        var subcategories: [UUID: SpendingSubcategory] = [:]
        var payments: [UUID: RecurringPayment] = [:]
        for record in snapshot.wallets {
            let model = try Wallet(name: record.name, startingBalance: AppBackup.decimal(record.startingBalance),
                currencyCode: record.currencyCode, walletType: record.walletType, icon: record.icon,
                colorName: record.colorName, allowsNegativeBalance: record.allowsNegativeBalance,
                negativeBalanceLimit: AppBackup.decimal(record.negativeBalanceLimit))
            model.createdAt = record.createdAt
            context.insert(model)
            wallets[record.id] = model
        }
        for record in snapshot.categories {
            let model = SpendingCategory(name: record.name, icon: record.icon, colorName: record.colorName)
            model.createdAt = record.createdAt
            context.insert(model)
            categories[record.id] = model
        }
        for record in snapshot.subcategories {
            let model = SpendingSubcategory(name: record.name, category: record.categoryID.flatMap { categories[$0] })
            model.createdAt = record.createdAt
            context.insert(model)
            subcategories[record.id] = model
        }
        for record in snapshot.budgets {
            let model = try Budget(name: record.name, totalAmount: AppBackup.decimal(record.totalAmount),
                currencyCode: record.currencyCode, startDate: record.startDate, endDate: record.endDate,
                isRecurring: record.isRecurring, recurrenceType: record.recurrenceType, seriesID: record.seriesID)
            model.createdAt = record.createdAt
            model.categories = record.categoryIDs.compactMap { categories[$0] }
            context.insert(model)
        }
        for record in snapshot.recurringPayments {
            let model = try RecurringPayment(name: record.name, amount: AppBackup.decimal(record.amount),
                frequency: record.frequency, nextPaymentDate: record.scheduledPaymentDate, note: record.note,
                isActive: record.isActive, wallet: record.walletID.flatMap { wallets[$0] },
                category: record.categoryID.flatMap { categories[$0] }, subcategory: record.subcategoryID.flatMap { subcategories[$0] })
            model.createdAt = record.createdAt
            model.postponedUntil = record.postponedUntil
            context.insert(model)
            payments[record.id] = model
        }
        for record in snapshot.transactions {
            let model = try ExpenseTransaction(amount: AppBackup.decimal(record.amount), isIncome: record.isIncome,
                date: record.date, note: record.note, wallet: record.walletID.flatMap { wallets[$0] },
                category: record.categoryID.flatMap { categories[$0] }, subcategory: record.subcategoryID.flatMap { subcategories[$0] },
                recurringPayment: record.recurringPaymentID.flatMap { payments[$0] },
                recurringScheduledDate: record.recurringScheduledDate, recurringPostponedUntil: record.recurringPostponedUntil)
            context.insert(model)
        }
        for record in snapshot.transfers {
            let model = try WalletTransfer(sourceAmount: AppBackup.decimal(record.sourceAmount),
                destinationAmount: AppBackup.decimal(record.destinationAmount), date: record.date, note: record.note,
                sourceWallet: record.sourceWalletID.flatMap { wallets[$0] }, destinationWallet: record.destinationWalletID.flatMap { wallets[$0] },
                sourceCurrencyCode: record.sourceCurrencyCode, destinationCurrencyCode: record.destinationCurrencyCode,
                createdAt: record.createdAt)
            context.insert(model)
        }
        for record in snapshot.items { context.insert(Item(timestamp: record.timestamp)) }
    }
}
