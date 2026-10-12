import Foundation
import SwiftUI
import SwiftData
import Combine

nonisolated enum RecurringUndoKind: Equatable {
    case paid, postponed, skipped

    var confirmation: String {
        switch self {
        case .paid: "Payment recorded"
        case .postponed: "Payment postponed"
        case .skipped: "Payment skipped"
        }
    }
}

nonisolated struct RecurringUndoPaymentState: Equatable {
    let name: String
    let amount: Decimal
    let frequency: String
    let scheduledDate: Date
    let postponedUntil: Date?
    let note: String
    let isActive: Bool
    let walletID: PersistentIdentifier?
    let categoryID: PersistentIdentifier?
    let subcategoryID: PersistentIdentifier?
    let reminder: ReminderPreferences
    let secondReminder: ReminderPreferences

    @MainActor init(_ payment: RecurringPayment) {
        name = payment.name; amount = payment.amount; frequency = payment.frequency
        scheduledDate = payment.scheduledPaymentDate; postponedUntil = payment.postponedUntil
        note = payment.note; isActive = payment.isActive
        walletID = payment.wallet?.persistentModelID; categoryID = payment.category?.persistentModelID
        subcategoryID = payment.subcategory?.persistentModelID
        reminder = payment.reminderPreferences; secondReminder = payment.secondReminderPreferences
    }
}

nonisolated struct RecurringUndoTransactionState: Equatable {
    let identifier: PersistentIdentifier
    let amount: Decimal
    let isIncome: Bool
    let date: Date
    let note: String
    let walletID: PersistentIdentifier?
    let categoryID: PersistentIdentifier?
    let subcategoryID: PersistentIdentifier?
    let paymentID: PersistentIdentifier?
    let scheduledDate: Date?
    let postponedUntil: Date?

    @MainActor init(_ transaction: ExpenseTransaction) {
        identifier = transaction.persistentModelID
        amount = transaction.amount; isIncome = transaction.isIncome; date = transaction.date; note = transaction.note
        walletID = transaction.wallet?.persistentModelID; categoryID = transaction.category?.persistentModelID
        subcategoryID = transaction.subcategory?.persistentModelID; paymentID = transaction.recurringPayment?.persistentModelID
        scheduledDate = transaction.recurringScheduledDate; postponedUntil = transaction.recurringPostponedUntil
    }
}

nonisolated struct RecurringPaymentUndoToken: Identifiable {
    let id = UUID()
    let kind: RecurringUndoKind
    let paymentID: PersistentIdentifier
    let paymentKey: String
    let before: RecurringUndoPaymentState
    let after: RecurringUndoPaymentState
    let transaction: RecurringUndoTransactionState?

    @MainActor init(kind: RecurringUndoKind, payment: RecurringPayment, before: RecurringUndoPaymentState,
                    transaction: ExpenseTransaction? = nil) {
        self.kind = kind; self.paymentID = payment.persistentModelID
        self.paymentKey = RecurringReminderSnapshot(payment: payment).paymentKey
        self.before = before; self.after = RecurringUndoPaymentState(payment)
        self.transaction = transaction.map { RecurringUndoTransactionState($0) }
    }
}

@MainActor
extension FormStore {
    nonisolated enum UndoError: LocalizedError {
        case noLongerAvailable
        var errorDescription: String? { "This payment or its recorded expense has changed. This action can no longer be undone." }
    }

    static func confirmRecurringPaymentWithUndo(_ payment: RecurringPayment, amount: String, date: Date,
                                               context: ModelContext, commit: (ModelContext) throws -> Void = { try $0.save() }) throws -> RecurringPaymentUndoToken {
        let before = RecurringUndoPaymentState(payment)
        let transaction = try confirmRecurringPayment(payment, amount: amount, date: date, context: context, commit: commit)
        return RecurringPaymentUndoToken(kind: .paid, payment: payment, before: before, transaction: transaction)
    }

    static func postponeRecurringPaymentWithUndo(_ payment: RecurringPayment, until date: Date,
                                                context: ModelContext, commit: (ModelContext) throws -> Void = { try $0.save() }) throws -> RecurringPaymentUndoToken {
        let before = RecurringUndoPaymentState(payment)
        try postponeRecurringPayment(payment, until: date, context: context, commit: commit)
        return RecurringPaymentUndoToken(kind: .postponed, payment: payment, before: before)
    }

    static func skipRecurringPaymentWithUndo(_ payment: RecurringPayment, context: ModelContext,
                                            commit: (ModelContext) throws -> Void = { try $0.save() }) throws -> RecurringPaymentUndoToken {
        let before = RecurringUndoPaymentState(payment)
        try skipRecurringPayment(payment, context: context, commit: commit)
        return RecurringPaymentUndoToken(kind: .skipped, payment: payment, before: before)
    }

    static func canUndoRecurringPaymentAction(_ token: RecurringPaymentUndoToken, context: ModelContext) -> Bool {
        (try? undoTargets(token, context: context)) != nil
    }

    private static func undoTargets(_ token: RecurringPaymentUndoToken, context: ModelContext) throws -> (RecurringPayment, ExpenseTransaction?) {
        guard let payment = try context.fetch(FetchDescriptor<RecurringPayment>()).first(where: { $0.persistentModelID == token.paymentID }),
              RecurringReminderSnapshot(payment: payment).paymentKey == token.paymentKey,
              RecurringUndoPaymentState(payment) == token.after else { throw UndoError.noLongerAvailable }
        var transaction: ExpenseTransaction?
        if let original = token.transaction {
            transaction = try context.fetch(FetchDescriptor<ExpenseTransaction>()).first(where: { $0.persistentModelID == original.identifier })
            guard let transaction, RecurringUndoTransactionState(transaction) == original else { throw UndoError.noLongerAvailable }
        }
        return (payment, transaction)
    }

    static func undoRecurringPaymentAction(_ token: RecurringPaymentUndoToken, context: ModelContext,
                                          commit: (ModelContext) throws -> Void = { try $0.save() }) throws {
        let (payment, transaction) = try undoTargets(token, context: context)
        // Use the same protected save path as every other recurring action.
        // Restore only this action's schedule; remove only its exact expense.
        try performRecurringUndo(context: context, commit: commit) {
            payment.scheduledPaymentDate = token.before.scheduledDate
            payment.postponedUntil = token.before.postponedUntil
            if let transaction { context.delete(transaction) }
        }
    }
}

@MainActor
final class RecurringUndoController: ObservableObject {
    @Published private(set) var token: RecurringPaymentUndoToken?
    @Published private(set) var isUndoing = false
    @Published var error: String?
    private var expiry: Task<Void, Never>?

    func record(_ token: RecurringPaymentUndoToken) {
        expiry?.cancel()
        self.token = token; error = nil
        expiry = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: 30_000_000_000) }
            catch { return }
            if self?.token?.id == token.id { self?.dismiss() }
        }
    }

    func dismiss() {
        expiry?.cancel(); expiry = nil; token = nil
    }

    func validate(context: ModelContext) {
        guard !isUndoing, let token else { return }
        if !FormStore.canUndoRecurringPaymentAction(token, context: context) { dismiss() }
    }

    func undo(context: ModelContext, commit: (ModelContext) throws -> Void = { try $0.save() }) {
        guard !isUndoing, let token else { return }
        isUndoing = true
        defer { isUndoing = false }
        do {
            try FormStore.undoRecurringPaymentAction(token, context: context, commit: commit)
            dismiss()
        } catch {
            self.error = error.localizedDescription
            if !FormStore.canUndoRecurringPaymentAction(token, context: context) { dismiss() }
        }
    }
}

struct RecurringUndoBanner: View {
    @ObservedObject var controller: RecurringUndoController
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if let token = controller.token {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(spacing: 12))
            layout {
                VStack(alignment: .leading, spacing: 3) {
                    Text(token.kind.confirmation).font(.subheadline.weight(.semibold))
                    Text(token.before.name).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 6) {
                    Button("Undo") { controller.undo(context: modelContext) }
                        .buttonStyle(.borderedProminent).disabled(controller.isUndoing)
                        .frame(minHeight: 44).accessibilityIdentifier("undoRecurringAction")
                    Button { controller.dismiss() } label: {
                        Image(systemName: "xmark").frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .accessibilityLabel("Dismiss Undo").accessibilityIdentifier("dismissRecurringUndo")
                }
            }
            .padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .accessibilityIdentifier("recurringUndoBanner")
        }
    }
}
