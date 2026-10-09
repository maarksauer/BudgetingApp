import SwiftUI
import SwiftData

struct RecurringPaymentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseTransaction.date, order: .reverse) private var transactions: [ExpenseTransaction]
    @Query(sort: \Wallet.createdAt) private var wallets: [Wallet]
    @Query(sort: \SpendingCategory.createdAt) private var categories: [SpendingCategory]
    let payment: RecurringPayment
    let reminderOccurrence: String?
    @State private var draft: RecurringPaymentFormDraft
    @FocusState private var focusedField: TransactionFormField?
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var showingConfirmPayment = false
    @State private var showingPostponeOptions = false
    @State private var showingSkipConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var showingCustomPostponeDate = false
    @State private var customPostponeDate = Date()
    @State private var showingSaveError = false
    @State private var showingPostponeError = false
    @State private var saveError = ""

    init(payment: RecurringPayment, reminderOccurrence: String? = nil) {
        self.payment = payment
        self.reminderOccurrence = reminderOccurrence
        _draft = State(initialValue: RecurringPaymentFormDraft(payment: payment))
    }

    private var paymentTransactions: [ExpenseTransaction] {
        transactions.filter { $0.recurringPayment?.persistentModelID == payment.persistentModelID }
    }

    var body: some View {
        Form {
            if isEditing {
                RecurringPaymentFormFields(draft: $draft, wallets: wallets, categories: categories,
                                           isEditing: true, focusedField: $focusedField)
                if payment.isPostponed {
                    Section {
                        Label("Changing the scheduled day clears the current postponement. Other edits keep it.", systemImage: "info.circle")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            } else {
                if let reminderOccurrence, reminderOccurrence != RecurringReminderSnapshot(payment: payment).occurrenceKey {
                    Section {
                        Label("This reminder is for an earlier schedule. The payment’s current details are shown below.", systemImage: "info.circle")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                summary
                schedule
                Section("Details") {
                    ReadableDetailRow(title: "Wallet", value: payment.wallet?.name ?? "None")
                    ReadableDetailRow(title: "Category", value: payment.category?.name ?? "None")
                    ReadableDetailRow(title: "Subcategory", value: payment.subcategory?.name ?? "None")
                }
                Section("Note") {
                    Text(payment.note.isEmpty ? "No note" : payment.note)
                        .foregroundStyle(payment.note.isEmpty ? .secondary : .primary)
                }
                if payment.isActive && (payment.isDue || payment.isPostponed || reminderOccurrence == RecurringReminderSnapshot(payment: payment).occurrenceKey) { currentActions }
                if let last = paymentTransactions.first {
                    Section("Last Payment") {
                        ReadableDetailRow(title: "Paid", value: last.date.formatted(date: .long, time: .omitted))
                        ReadableDetailRow(title: "Amount", value: last.amount.formatted(.number) + " " + (last.wallet?.currencyCode ?? ""))
                    }
                }
                if !paymentTransactions.isEmpty {
                    Section("Payment History") {
                        ForEach(paymentTransactions) { transaction in
                            NavigationLink { TransactionDetailView(transaction: transaction) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(transaction.date.formatted(date: .abbreviated, time: .omitted)).font(.subheadline.weight(.medium))
                                        Text(transaction.wallet?.name ?? "Missing wallet").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(transaction.amount.formatted(.number) + " " + (transaction.wallet?.currencyCode ?? ""))
                                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                Section("Manage Payment") {
                    Button {
                        perform { try FormStore.setRecurringPaymentActive(payment, active: !payment.isActive, context: modelContext) }
                    } label: {
                        Label(payment.isActive ? "Pause Recurring Payment" : "Resume Recurring Payment",
                              systemImage: payment.isActive ? "pause.circle" : "play.circle")
                    }
                    Button("Delete Recurring Payment", role: .destructive) { showingDeleteConfirmation = true }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(isEditing ? "Edit Recurring Payment" : payment.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isEditing {
                    Button("Save", action: save).buttonStyle(.borderedProminent)
                        .disabled(!draft.canSave || isSaving).accessibilityIdentifier("saveRecurringPaymentEdit")
                } else {
                    Button("Edit") { draft = RecurringPaymentFormDraft(payment: payment); isEditing = true }
                        .accessibilityIdentifier("editRecurringPayment")
                }
            }
            if isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        focusedField = nil; draft = RecurringPaymentFormDraft(payment: payment); isEditing = false
                    }
                    .disabled(isSaving).accessibilityIdentifier("cancelRecurringForm")
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                if focusedField != nil {
                    Spacer()
                    Button("Done") { focusedField = nil }.accessibilityIdentifier("recurringFormKeyboardDone")
                }
            }
        }
        .onDisappear { focusedField = nil }
        .sheet(isPresented: $showingConfirmPayment) { ConfirmRecurringPaymentView(payment: payment) }
        .sheet(isPresented: $showingCustomPostponeDate) { customPostponeSheet }
        .confirmationDialog("Postpone Payment", isPresented: $showingPostponeOptions, titleVisibility: .visible) {
            Button("1 Day") { postpone(byDays: 1) }
            Button("3 Days") { postpone(byDays: 3) }
            Button("1 Week") { postpone(byDays: 7) }
            Button("2 Weeks") { postpone(byDays: 14) }
            Button("Choose Date…") {
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                customPostponeDate = max(payment.nextPaymentDate, tomorrow)
                showingCustomPostponeDate = true
            }
            Button("Cancel", role: .cancel) { }
        } message: { Text("This postpones the current payment and keeps the normal recurring schedule.") }
        .alert("Skip This Payment?", isPresented: $showingSkipConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Skip", role: .destructive) { perform { try FormStore.skipRecurringPayment(payment, context: modelContext) } }
        } message: { Text("No transaction will be created. This moves the payment to its next scheduled date.") }
        .confirmationDialog("Delete Recurring Payment?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Recurring Payment", role: .destructive) {
                perform({ try FormStore.deleteRecurringPayment(payment, context: modelContext) }, afterSave: { dismiss() })
            }
            Button("Cancel", role: .cancel) { }
        } message: { Text("Future payments will stop. Completed transactions will remain in your history.") }
        .alert("Couldn’t save changes", isPresented: $showingSaveError) {
            Button("OK", role: .cancel) { }
        } message: { Text(isEditing ? "Your entries are still here. \(saveError)" : "Please try again. \(saveError)") }
    }

    private var summary: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label(payment.name, systemImage: payment.category?.icon ?? "arrow.trianglehead.2.clockwise.rotate.90")
                    .font(.headline).foregroundStyle(FormPalette.color(payment.category?.colorName ?? "blue"))
                Text(payment.amount.formatted(.number) + " " + (payment.wallet?.currencyCode ?? ""))
                    .font(.largeTitle.weight(.semibold)).monospacedDigit()
                Text(payment.statusText).font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(statusColor.opacity(0.12), in: Capsule()).foregroundStyle(statusColor)
            }
            .padding(.vertical, 8)
        }
    }

    private var schedule: some View {
        Section("Schedule") {
            ReadableDetailRow(title: "Repeat", value: payment.frequency)
            if payment.isPostponed {
                ReadableDetailRow(title: "Original Schedule", value: payment.scheduledPaymentDate.formatted(date: .long, time: .omitted))
                ReadableDetailRow(title: "Postponed Until", value: payment.nextPaymentDate.formatted(date: .long, time: .omitted))
            } else {
                ReadableDetailRow(title: payment.isDue ? "Due" : "Next Payment", value: payment.nextPaymentDate.formatted(date: .long, time: .omitted))
            }
        }
    }

    private var currentActions: some View {
        Section("Current Payment") {
            Button { showingConfirmPayment = true } label: {
                Label("Payment Was Made", systemImage: "checkmark.circle.fill")
            }
            .accessibilityIdentifier("openConfirmPayment")
            Button { showingPostponeOptions = true } label: { Label("Postpone", systemImage: "clock.arrow.circlepath") }
            Button(role: .destructive) { showingSkipConfirmation = true } label: {
                Label("Skip This Payment", systemImage: "forward.end")
            }
        }
    }

    private var customPostponeSheet: some View {
        NavigationStack {
            Form {
                Section("Postpone Until") {
                    DatePicker("Date", selection: $customPostponeDate, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                }
                Section { Text("This keeps your normal recurring schedule unchanged.").font(.caption).foregroundStyle(.secondary) }
            }
            .navigationTitle("Choose Date").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingCustomPostponeDate = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Postpone") {
                        do {
                            try FormStore.postponeRecurringPayment(payment, until: customPostponeDate, context: modelContext)
                            showingCustomPostponeDate = false
                        } catch { saveError = error.localizedDescription; showingPostponeError = true }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .alert("Couldn’t postpone payment", isPresented: $showingPostponeError) {
                Button("OK", role: .cancel) { }
            } message: { Text("Your selected date is still here. \(saveError)") }
        }
    }

    private var statusColor: Color {
        if !payment.isActive { return .gray }
        if payment.isDue { return .red }
        if payment.isPostponed { return .orange }
        return .green
    }

    private func postpone(byDays days: Int) {
        guard let date = Calendar.current.date(byAdding: .day, value: days, to: max(payment.nextPaymentDate, Date())) else { return }
        perform { try FormStore.postponeRecurringPayment(payment, until: date, context: modelContext) }
    }

    private func save() {
        guard draft.canSave, !isSaving else { return }
        focusedField = nil
        perform({ try FormStore.updateRecurringPayment(payment, draft: draft, context: modelContext) }, afterSave: { isEditing = false })
    }

    private func perform(_ action: () throws -> Void, afterSave: () -> Void = {}) {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do { try action(); afterSave() }
        catch { saveError = error.localizedDescription; showingSaveError = true }
    }
}
