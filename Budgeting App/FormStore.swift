import Foundation
import SwiftData

nonisolated struct WalletFormDraft {
    var name = ""
    var startingBalance = ""
    var currencyCode = CurrencyPreferences.load().defaultCode
    var walletType = "Bank Account"
    var icon = "wallet.bifold.fill"
    var colorName = "blue"
    var allowsNegativeBalance = false
    var negativeBalanceLimit = ""

    var cleanedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var balance: Decimal? { AmountInput.parse(startingBalance) }
    var effectiveAllowsNegativeBalance: Bool { walletType == "Credit Card" || allowsNegativeBalance }
    var limit: Decimal? { AmountInput.positive(negativeBalanceLimit) }
    var canSave: Bool {
        !cleanedName.isEmpty && balance != nil && !currencyCode.isEmpty &&
        (!effectiveAllowsNegativeBalance || limit != nil)
    }
}

@MainActor
extension WalletFormDraft {
    init(wallet: Wallet) {
        self.init(name: wallet.name, startingBalance: NSDecimalNumber(decimal: wallet.startingBalance).stringValue,
                  currencyCode: wallet.currencyCode, walletType: wallet.walletType, icon: wallet.icon,
                  colorName: wallet.colorName, allowsNegativeBalance: wallet.allowsNegativeBalance,
                  negativeBalanceLimit: NSDecimalNumber(decimal: wallet.negativeBalanceLimit).stringValue)
    }
}

nonisolated struct BudgetFormDraft {
    var name = ""
    var amount = ""
    var currencyCode = CurrencyPreferences.load().defaultCode
    var startDate = Date()
    var endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    var isRecurring = false
    var recurrenceType = "Monthly"

    var cleanedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var total: Decimal? { AmountInput.positive(amount) }
    var periodIsValid: Bool {
        startDate.timeIntervalSinceReferenceDate.isFinite && endDate.timeIntervalSinceReferenceDate.isFinite &&
        Calendar.current.startOfDay(for: endDate) >= Calendar.current.startOfDay(for: startDate)
    }
    var canSave: Bool { !cleanedName.isEmpty && total != nil && !currencyCode.isEmpty && periodIsValid }
}

@MainActor
extension BudgetFormDraft {
    init(budget: Budget) {
        self.init(name: budget.name, amount: NSDecimalNumber(decimal: budget.totalAmount).stringValue,
                  currencyCode: budget.currencyCode, startDate: budget.startDate, endDate: budget.endDate,
                  isRecurring: budget.isRecurring, recurrenceType: budget.recurrenceType)
    }
}

@MainActor
enum FormStore {
    nonisolated enum SaveError: LocalizedError {
        case invalidFields
        var errorDescription: String? { "Check the required fields and the wallet’s available balance, then try again." }
    }

    private static func perform<Result>(context: ModelContext, commit: (ModelContext) throws -> Void,
                                        changes: () throws -> Result) throws -> Result {
        // Flush existing changes first so rollback only reverts this save attempt.
        try context.save()
        let previousAutosave = context.autosaveEnabled
        context.autosaveEnabled = false
        defer { context.autosaveEnabled = previousAutosave }
        do {
            let result = try changes()
            try commit(context)
            return result
        } catch { context.rollback(); throw error }
    }

    @discardableResult
    static func createWallet(_ draft: WalletFormDraft, context: ModelContext,
                             commit: (ModelContext) throws -> Void = { try $0.save() }) throws -> Wallet {
        guard draft.canSave, let balance = draft.balance else { throw SaveError.invalidFields }
        let wallet = Wallet(name: draft.cleanedName, startingBalance: balance, currencyCode: draft.currencyCode,
                            walletType: draft.walletType, icon: draft.icon, colorName: draft.colorName,
                            allowsNegativeBalance: draft.effectiveAllowsNegativeBalance,
                            negativeBalanceLimit: draft.effectiveAllowsNegativeBalance ? draft.limit ?? 0 : 0)
        try perform(context: context, commit: commit) { context.insert(wallet) }
        return wallet
    }

    static func updateWallet(_ wallet: Wallet, draft: WalletFormDraft, context: ModelContext,
                             commit: (ModelContext) throws -> Void = { try $0.save() }) throws {
        guard draft.canSave, draft.currencyCode == wallet.currencyCode, let balance = draft.balance else { throw SaveError.invalidFields }
        try perform(context: context, commit: commit) {
            wallet.name = draft.cleanedName
            wallet.startingBalance = balance
            wallet.walletType = draft.walletType
            wallet.icon = draft.icon
            wallet.colorName = draft.colorName
            wallet.allowsNegativeBalance = draft.effectiveAllowsNegativeBalance
            wallet.negativeBalanceLimit = draft.effectiveAllowsNegativeBalance ? draft.limit ?? 0 : 0
        }
    }

    @discardableResult
    static func createBudget(_ draft: BudgetFormDraft, context: ModelContext,
                             commit: (ModelContext) throws -> Void = { try $0.save() }) throws -> Budget {
        guard draft.canSave, let total = draft.total else { throw SaveError.invalidFields }
        let budget = Budget(name: draft.cleanedName, totalAmount: total, currencyCode: draft.currencyCode,
                            startDate: draft.startDate, endDate: draft.endDate,
                            isRecurring: draft.isRecurring, recurrenceType: draft.recurrenceType)
        try perform(context: context, commit: commit) { context.insert(budget) }
        return budget
    }

    static func updateBudget(_ budget: Budget, draft: BudgetFormDraft, includeFuture: Bool,
                             context: ModelContext, commit: (ModelContext) throws -> Void = { try $0.save() }) throws {
        guard draft.canSave, let total = draft.total else { throw SaveError.invalidFields }
        try perform(context: context, commit: commit) {
            let affected: [Budget]
            if includeFuture {
                affected = try context.fetch(FetchDescriptor<Budget>()).filter {
                    $0.seriesID == budget.seriesID && $0.startDate >= budget.startDate
                }
            } else { affected = [budget] }
            for model in affected {
                model.name = draft.cleanedName
                model.totalAmount = total
                model.currencyCode = draft.currencyCode
                model.isRecurring = draft.isRecurring
                model.recurrenceType = draft.recurrenceType
            }
            // Dates and category selections belong to individual periods.
            budget.startDate = draft.startDate
            budget.endDate = draft.endDate
        }
    }
}

@MainActor
extension FormStore {
    private static func validateSelections(_ draft: ExpenseDraft, context: ModelContext) throws {
        guard draft.hasRequiredFields,
              try context.fetch(FetchDescriptor<Wallet>()).contains(where: { $0.persistentModelID == draft.selectedWallet?.persistentModelID })
        else { throw SaveError.invalidFields }
        if !draft.isIncome {
            guard try context.fetch(FetchDescriptor<SpendingCategory>()).contains(where: { $0.persistentModelID == draft.selectedCategory?.persistentModelID }),
                  draft.selectedSubcategoryID == nil || draft.subcategory != nil
            else { throw SaveError.invalidFields }
        }
    }

    @discardableResult
    static func createTransaction(_ draft: ExpenseDraft, context: ModelContext,
                                  commit: (ModelContext) throws -> Void = { try $0.save() }) throws -> ExpenseTransaction {
        try validateSelections(draft, context: context)
        let transfers = try context.fetch(FetchDescriptor<WalletTransfer>())
        guard draft.canSave(transfers: transfers), let total = draft.total else { throw SaveError.invalidFields }
        return try perform(context: context, commit: commit) {
            let transaction = ExpenseTransaction(amount: total, isIncome: draft.isIncome, date: draft.transactionDate,
                                                 note: draft.cleanedNote, wallet: draft.selectedWallet,
                                                 category: draft.isIncome ? nil : draft.selectedCategory,
                                                 subcategory: draft.isIncome ? nil : draft.subcategory)
            context.insert(transaction)
            return transaction
        }
    }

    static func updateTransaction(_ transaction: ExpenseTransaction, draft: ExpenseDraft, context: ModelContext,
                                  commit: (ModelContext) throws -> Void = { try $0.save() }) throws {
        try validateSelections(draft, context: context)
        let transfers = try context.fetch(FetchDescriptor<WalletTransfer>())
        guard draft.isIncome == transaction.isIncome, draft.canSave(transfers: transfers, excluding: transaction),
              let total = draft.total else { throw SaveError.invalidFields }
        try perform(context: context, commit: commit) {
            transaction.amount = total
            transaction.date = draft.transactionDate
            transaction.note = draft.cleanedNote
            transaction.wallet = draft.selectedWallet
            transaction.category = draft.isIncome ? nil : draft.selectedCategory
            transaction.subcategory = draft.isIncome ? nil : draft.subcategory
        }
    }

    static func deleteTransaction(_ transaction: ExpenseTransaction, context: ModelContext,
                                  commit: (ModelContext) throws -> Void = { try $0.save() }) throws {
        try perform(context: context, commit: commit) { context.delete(transaction) }
    }

    static func revertRecurringTransaction(_ transaction: ExpenseTransaction, context: ModelContext,
                                          commit: (ModelContext) throws -> Void = { try $0.save() }) throws {
        guard let payment = transaction.recurringPayment, let scheduled = transaction.recurringScheduledDate
        else { throw SaveError.invalidFields }
        try perform(context: context, commit: commit) {
            payment.scheduledPaymentDate = scheduled
            payment.postponedUntil = transaction.recurringPostponedUntil
            context.delete(transaction)
        }
    }

    @discardableResult
    static func createRecurringPayment(_ draft: RecurringPaymentFormDraft, context: ModelContext,
                                       commit: (ModelContext) throws -> Void = { try $0.save() }) throws -> RecurringPayment {
        guard draft.canSave, let total = draft.details.total else { throw SaveError.invalidFields }
        try validateSelections(draft.details, context: context)
        return try perform(context: context, commit: commit) {
            let payment = RecurringPayment(name: draft.cleanedName, amount: total, frequency: draft.frequency,
                                           nextPaymentDate: draft.scheduledDate, note: draft.details.cleanedNote,
                                           wallet: draft.details.selectedWallet, category: draft.details.selectedCategory,
                                           subcategory: draft.details.subcategory)
            context.insert(payment)
            return payment
        }
    }

    static func updateRecurringPayment(_ payment: RecurringPayment, draft: RecurringPaymentFormDraft,
                                       context: ModelContext, commit: (ModelContext) throws -> Void = { try $0.save() }) throws {
        guard draft.canSave, let total = draft.details.total else { throw SaveError.invalidFields }
        try validateSelections(draft.details, context: context)
        try perform(context: context, commit: commit) {
            let previousDate = payment.scheduledPaymentDate
            payment.name = draft.cleanedName
            payment.amount = total
            payment.frequency = draft.frequency
            payment.scheduledPaymentDate = draft.scheduledDate
            payment.note = draft.details.cleanedNote
            payment.wallet = draft.details.selectedWallet
            payment.category = draft.details.selectedCategory
            payment.subcategory = draft.details.subcategory
            if !Calendar.current.isDate(previousDate, inSameDayAs: draft.scheduledDate) {
                payment.postponedUntil = nil
            }
        }
    }

    @discardableResult
    static func confirmRecurringPayment(_ payment: RecurringPayment, amount: String, date: Date,
                                        context: ModelContext, commit: (ModelContext) throws -> Void = { try $0.save() }) throws -> ExpenseTransaction {
        guard payment.isActive, let next = RecurringSchedule.nextDate(frequency: payment.frequency, from: payment.scheduledPaymentDate),
              next > payment.scheduledPaymentDate else { throw SaveError.invalidFields }
        var draft = ExpenseDraft()
        draft.amount = amount; draft.transactionDate = date; draft.note = payment.note
        draft.selectedWallet = payment.wallet; draft.selectedCategory = payment.category
        draft.selectedSubcategoryID = payment.subcategory?.persistentModelID
        try validateSelections(draft, context: context)
        guard draft.canSave(transfers: try context.fetch(FetchDescriptor<WalletTransfer>())), let total = draft.total
        else { throw SaveError.invalidFields }
        return try perform(context: context, commit: commit) {
            let transaction = ExpenseTransaction(amount: total, date: date, note: draft.cleanedNote,
                                                 wallet: payment.wallet, category: payment.category, subcategory: payment.subcategory,
                                                 recurringPayment: payment, recurringScheduledDate: payment.scheduledPaymentDate,
                                                 recurringPostponedUntil: payment.postponedUntil)
            context.insert(transaction)
            payment.scheduledPaymentDate = next
            payment.postponedUntil = nil
            return transaction
        }
    }

    static func setRecurringPaymentActive(_ payment: RecurringPayment, active: Bool, context: ModelContext,
                                          commit: (ModelContext) throws -> Void = { try $0.save() }) throws {
        try perform(context: context, commit: commit) { payment.isActive = active }
    }

    static func postponeRecurringPayment(_ payment: RecurringPayment, until date: Date, context: ModelContext,
                                         commit: (ModelContext) throws -> Void = { try $0.save() }) throws {
        guard date.timeIntervalSinceReferenceDate.isFinite else { throw SaveError.invalidFields }
        try perform(context: context, commit: commit) { payment.postponedUntil = date }
    }

    static func skipRecurringPayment(_ payment: RecurringPayment, context: ModelContext,
                                     commit: (ModelContext) throws -> Void = { try $0.save() }) throws {
        guard let next = RecurringSchedule.nextDate(frequency: payment.frequency, from: payment.scheduledPaymentDate),
              next > payment.scheduledPaymentDate else { throw SaveError.invalidFields }
        try perform(context: context, commit: commit) {
            payment.scheduledPaymentDate = next
            payment.postponedUntil = nil
        }
    }

    static func deleteRecurringPayment(_ payment: RecurringPayment, context: ModelContext,
                                       commit: (ModelContext) throws -> Void = { try $0.save() }) throws {
        try perform(context: context, commit: commit) {
            let transactions = try context.fetch(FetchDescriptor<ExpenseTransaction>()).filter {
                $0.recurringPayment?.persistentModelID == payment.persistentModelID
            }
            for transaction in transactions { transaction.recurringPayment = nil }
            context.delete(payment)
        }
    }
}
