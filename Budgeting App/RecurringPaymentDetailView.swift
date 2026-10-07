import SwiftUI
import SwiftData

struct RecurringPaymentDetailView: View {

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.modelContext)
    private var modelContext

    @Query(sort: \ExpenseTransaction.date, order: .reverse)
    private var transactions: [ExpenseTransaction]

    @Query(sort: \Wallet.createdAt)
    private var wallets: [Wallet]

    @Query(sort: \SpendingCategory.createdAt)
    private var categories: [SpendingCategory]

    let payment: RecurringPayment

    // MARK: - Actions

    @State private var showingPostponeOptions = false
    @State private var showingSkipConfirmation = false
    @State private var showingConfirmPayment = false
    @State private var showingDeleteConfirmation = false

    @State private var showingCustomPostponeDate = false
    @State private var customPostponeDate = Date()

    // MARK: - Editing

    @State private var isEditing = false

    @State private var editedName: String
    @State private var editedAmount: String

    @State private var editedWallet: Wallet?
    @State private var editedCategory: SpendingCategory?
    @State private var editedSubcategoryID: PersistentIdentifier?

    @State private var editedFrequency: String
    @State private var editedScheduledDate: Date
    @State private var editedNote: String

    private let frequencies = [
        "Weekly",
        "Monthly",
        "Every 3 Months",
        "Every 6 Months",
        "Yearly"
    ]

    init(
        payment: RecurringPayment
    ) {

        self.payment = payment

        _editedName = State(
            initialValue: payment.name
        )

        _editedAmount = State(
            initialValue:
                NSDecimalNumber(
                    decimal: payment.amount
                ).stringValue
        )

        _editedWallet = State(
            initialValue: payment.wallet
        )

        _editedCategory = State(
            initialValue: payment.category
        )

        _editedSubcategoryID = State(
            initialValue:
                payment.subcategory?
                    .persistentModelID
        )

        _editedFrequency = State(
            initialValue: payment.frequency
        )

        _editedScheduledDate = State(
            initialValue:
                payment.scheduledPaymentDate
        )

        _editedNote = State(
            initialValue: payment.note
        )
    }

    var body: some View {

        Form {

            // MARK: - Payment

            Section("Payment") {

                if isEditing {

                    TextField(
                        "Name",
                        text: $editedName
                    )

                    TextField(
                        "Amount",
                        text: $editedAmount
                    )
                    .keyboardType(.decimalPad)

                    if !editedAmount.isEmpty &&
                        parsedEditedAmount == nil {

                        Text(
                            "Enter a valid amount."
                        )
                        .font(.caption)
                        .foregroundStyle(.red)
                    }

                } else {

                    LabeledContent(
                        "Name",
                        value: payment.name
                    )

                    LabeledContent(
                        "Amount"
                    ) {

                        Text(
                            "\(payment.amount.formatted(.number)) \(payment.wallet?.currencyCode ?? "")"
                        )
                    }
                }
            }

            // MARK: - Wallet

            Section("Wallet") {

                if isEditing {

                    Picker(
                        "Wallet",
                        selection: $editedWallet
                    ) {

                        Text(
                            "Select Wallet"
                        )
                        .tag(
                            nil as Wallet?
                        )

                        ForEach(
                            wallets
                        ) { wallet in

                            Text(
                                "\(wallet.name) • \(wallet.currencyCode)"
                            )
                            .tag(
                                wallet as Wallet?
                            )
                        }
                    }

                } else {

                    LabeledContent(
                        "Wallet",
                        value:
                            payment.wallet?.name
                            ?? "None"
                    )
                }
            }

            // MARK: - Category

            Section("Category") {

                if isEditing {

                    Picker(
                        "Category",
                        selection:
                            $editedCategory
                    ) {

                        Text(
                            "Select Category"
                        )
                        .tag(
                            nil as SpendingCategory?
                        )

                        ForEach(
                            categories
                        ) { category in

                            Text(
                                category.name
                            )
                            .tag(
                                category
                                    as SpendingCategory?
                            )
                        }
                    }
                    .onChange(
                        of: editedCategory
                    ) {

                        editedSubcategoryID =
                            nil
                    }

                    if let editedCategory,
                       !editedCategory
                        .subcategories
                        .isEmpty {

                        Picker(
                            "Subcategory",
                            selection:
                                $editedSubcategoryID
                        ) {

                            Text(
                                "None"
                            )
                            .tag(
                                nil
                                    as PersistentIdentifier?
                            )

                            ForEach(
                                editedCategory
                                    .subcategories
                                    .sorted {

                                        $0.name
                                            .localizedCaseInsensitiveCompare(
                                                $1.name
                                            )
                                        ==
                                        .orderedAscending
                                    }
                            ) { subcategory in

                                Text(
                                    subcategory.name
                                )
                                .tag(
                                    subcategory
                                        .persistentModelID
                                        as PersistentIdentifier?
                                )
                            }
                        }
                    }

                } else {

                    LabeledContent(
                        "Category",
                        value:
                            payment.category?.name
                            ?? "None"
                    )

                    LabeledContent(
                        "Subcategory",
                        value:
                            payment.subcategory?.name
                            ?? "None"
                    )
                }
            }

            // MARK: - Schedule

            Section("Schedule") {

                if isEditing {

                    Picker(
                        "Frequency",
                        selection:
                            $editedFrequency
                    ) {

                        ForEach(
                            frequencies,
                            id: \.self
                        ) { frequency in

                            Text(
                                frequency
                            )
                        }
                    }

                    DatePicker(
                        "Next Scheduled Date",
                        selection:
                            $editedScheduledDate,
                        displayedComponents:
                            .date
                    )

                } else {

                    LabeledContent(
                        "Frequency",
                        value:
                            payment.frequency
                    )

                    if payment.isPostponed {

                        LabeledContent(
                            "Original Schedule"
                        ) {

                            Text(
                                payment
                                    .scheduledPaymentDate
                                    .formatted(
                                        date: .long,
                                        time: .omitted
                                    )
                            )
                        }

                        LabeledContent(
                            "Postponed Until"
                        ) {

                            Text(
                                payment
                                    .nextPaymentDate
                                    .formatted(
                                        date: .long,
                                        time: .omitted
                                    )
                            )
                            .foregroundStyle(
                                .orange
                            )
                        }

                    } else {

                        LabeledContent(
                            payment.isDue
                            ? "Due"
                            : "Next Payment"
                        ) {

                            Text(
                                payment
                                    .nextPaymentDate
                                    .formatted(
                                        date: .long,
                                        time: .omitted
                                    )
                            )
                        }
                    }

                    LabeledContent(
                        "Status"
                    ) {

                        Text(
                            payment.statusText
                        )
                        .foregroundStyle(
                            statusColor
                        )
                    }
                }
            }

            // MARK: - Note

            Section("Note") {

                if isEditing {

                    TextField(
                        "Optional note",
                        text: $editedNote
                    )

                } else {

                    Text(
                        payment.note.isEmpty
                        ? "None"
                        : payment.note
                    )
                    .foregroundStyle(
                        payment.note.isEmpty
                        ? .secondary
                        : .primary
                    )
                }
            }

            // MARK: - Last Payment

            if !isEditing,
               let lastPayment =
                paymentTransactions.first {

                Section("Last Payment") {

                    LabeledContent(
                        "Paid"
                    ) {

                        Text(
                            lastPayment.date
                                .formatted(
                                    date: .long,
                                    time: .omitted
                                )
                        )
                    }

                    LabeledContent(
                        "Amount"
                    ) {

                        Text(
                            "\(lastPayment.amount.formatted(.number)) \(lastPayment.wallet?.currencyCode ?? "")"
                        )
                    }
                }
            }

            // MARK: - Current Payment Actions

            if !isEditing &&
                payment.isActive &&
                (
                    payment.isDue ||
                    payment.isPostponed
                ) {

                Section(
                    "Current Payment"
                ) {

                    Button {

                        showingConfirmPayment =
                            true

                    } label: {

                        Label(
                            "Payment Was Made",
                            systemImage:
                                "checkmark.circle.fill"
                        )
                    }

                    Button {

                        showingPostponeOptions =
                            true

                    } label: {

                        Label(
                            "Postpone",
                            systemImage:
                                "clock.arrow.circlepath"
                        )
                    }

                    Button(
                        role: .destructive
                    ) {

                        showingSkipConfirmation =
                            true

                    } label: {

                        Label(
                            "Skip This Payment",
                            systemImage:
                                "forward.end"
                        )
                    }
                }
            }

            // MARK: - Payment History

            if !isEditing &&
                !paymentTransactions.isEmpty {

                Section(
                    "Payment History"
                ) {

                    ForEach(
                        paymentTransactions
                    ) { transaction in

                        NavigationLink {

                            TransactionDetailView(
                                transaction:
                                    transaction
                            )

                        } label: {

                            paymentHistoryRow(
                                transaction
                            )
                        }
                    }
                }
            }

            // MARK: - Controls

            if !isEditing {

                Section("Recurring Payment") {

                    Button {

                        payment.isActive.toggle()

                    } label: {

                        Label(
                            payment.isActive
                            ? "Pause Recurring Payment"
                            : "Resume Recurring Payment",
                            systemImage:
                                payment.isActive
                                ? "pause.circle"
                                : "play.circle"
                        )
                    }

                    Button(
                        role: .destructive
                    ) {

                        showingDeleteConfirmation =
                            true

                    } label: {

                        Label(
                            "Delete Recurring Payment",
                            systemImage:
                                "trash"
                        )
                    }
                }
            }
        }

        .navigationTitle(
            isEditing
            ? "Edit Recurring Payment"
            : payment.name
        )

        .navigationBarTitleDisplayMode(
            .inline
        )

        // MARK: - Toolbar

        .toolbar {

            ToolbarItem(
                placement:
                    .primaryAction
            ) {

                if isEditing {

                    Button(
                        "Save"
                    ) {

                        saveChanges()
                    }
                    .disabled(
                        !canSave
                    )

                } else {

                    Button(
                        "Edit"
                    ) {

                        resetEditForm()

                        isEditing =
                            true
                    }
                }
            }

            if isEditing {

                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {

                    Button(
                        "Cancel"
                    ) {

                        resetEditForm()

                        isEditing =
                            false
                    }
                }
            }
        }

        // MARK: - Confirm Payment

        .sheet(
            isPresented:
                $showingConfirmPayment
        ) {

            ConfirmRecurringPaymentView(
                payment: payment
            )
        }

        // MARK: - Postpone

        .confirmationDialog(
            "Postpone Payment",
            isPresented:
                $showingPostponeOptions,
            titleVisibility:
                .visible
        ) {

            Button(
                "1 Day"
            ) {

                postpone(
                    byDays: 1
                )
            }

            Button(
                "3 Days"
            ) {

                postpone(
                    byDays: 3
                )
            }

            Button(
                "1 Week"
            ) {

                postpone(
                    byDays: 7
                )
            }

            Button(
                "2 Weeks"
            ) {

                postpone(
                    byDays: 14
                )
            }

            Button(
                "Choose Date…"
            ) {

                prepareCustomPostponeDate()
            }

            Button(
                "Cancel",
                role: .cancel
            ) { }

        } message: {

            Text(
                "Choose how long to postpone this payment."
            )
        }

        // MARK: - Custom Postpone Date

        .sheet(
            isPresented:
                $showingCustomPostponeDate
        ) {

            NavigationStack {

                Form {

                    Section(
                        "Postpone Until"
                    ) {

                        DatePicker(
                            "Date",
                            selection:
                                $customPostponeDate,
                            in:
                                Date()...,
                            displayedComponents:
                                .date
                        )
                    }

                    Section {

                        Text(
                            "This only changes the current payment. Your normal recurring schedule stays unchanged."
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }

                .navigationTitle(
                    "Choose Date"
                )

                .navigationBarTitleDisplayMode(
                    .inline
                )

                .toolbar {

                    ToolbarItem(
                        placement:
                            .cancellationAction
                    ) {

                        Button(
                            "Cancel"
                        ) {

                            showingCustomPostponeDate =
                                false
                        }
                    }

                    ToolbarItem(
                        placement:
                            .confirmationAction
                    ) {

                        Button(
                            "Postpone"
                        ) {

                            applyCustomPostponeDate()
                        }
                    }
                }
            }
        }

        // MARK: - Skip

        .alert(
            "Skip This Payment?",
            isPresented:
                $showingSkipConfirmation
        ) {

            Button(
                "Cancel",
                role: .cancel
            ) { }

            Button(
                "Skip",
                role: .destructive
            ) {

                skipPayment()
            }

        } message: {

            Text(
                "No transaction will be created for this occurrence. The payment will move to its next scheduled date."
            )
        }

        // MARK: - Delete

        .confirmationDialog(
            "Delete Recurring Payment?",
            isPresented:
                $showingDeleteConfirmation,
            titleVisibility:
                .visible
        ) {

            Button(
                "Delete Recurring Payment",
                role: .destructive
            ) {

                deleteRecurringPayment()
            }

            Button(
                "Cancel",
                role: .cancel
            ) { }

        } message: {

            Text(
                "Future recurring payments will stop. Existing completed transactions will remain in your transaction history."
            )
        }
    }

    // MARK: - Payment Transactions

    private var paymentTransactions:
        [ExpenseTransaction] {

        transactions.filter {

            $0.recurringPayment?
                .persistentModelID
            ==
            payment
                .persistentModelID
        }
    }

    // MARK: - Selected Edited Subcategory

    private var editedSubcategory:
        SpendingSubcategory? {

        guard
            let editedSubcategoryID,
            let editedCategory
        else {

            return nil
        }

        return editedCategory
            .subcategories
            .first {

                $0.persistentModelID
                ==
                editedSubcategoryID
            }
    }

    // MARK: - Parsed Amount

    private var parsedEditedAmount:
        Decimal? {

        let cleaned =
            editedAmount
                .replacingOccurrences(
                    of: " ",
                    with: ""
                )
                .replacingOccurrences(
                    of: ",",
                    with: "."
                )

        guard
            let value =
                Decimal(
                    string: cleaned
                ),
            value > 0
        else {

            return nil
        }

        return value
    }

    // MARK: - Validation

    private var canSave: Bool {

        let cleanedName =
            editedName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        return
            !cleanedName.isEmpty
            &&
            parsedEditedAmount != nil
            &&
            editedWallet != nil
            &&
            editedCategory != nil
    }

    // MARK: - Save Changes

    private func saveChanges() {

        guard
            canSave,
            let amount =
                parsedEditedAmount,
            let wallet =
                editedWallet,
            let category =
                editedCategory
        else {

            return
        }

        let oldScheduledDate =
            payment.scheduledPaymentDate

        payment.name =
            editedName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        payment.amount =
            amount

        payment.wallet =
            wallet

        payment.category =
            category

        payment.subcategory =
            editedSubcategory

        payment.frequency =
            editedFrequency

        payment.note =
            editedNote
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        payment.scheduledPaymentDate =
            editedScheduledDate

        if !Calendar.current.isDate(
            oldScheduledDate,
            inSameDayAs:
                editedScheduledDate
        ) {

            payment.postponedUntil =
                nil
        }

        isEditing =
            false
    }

    // MARK: - Reset Edit Form

    private func resetEditForm() {

        editedName =
            payment.name

        editedAmount =
            NSDecimalNumber(
                decimal:
                    payment.amount
            )
            .stringValue

        editedWallet =
            payment.wallet

        editedCategory =
            payment.category

        editedSubcategoryID =
            payment
                .subcategory?
                .persistentModelID

        editedFrequency =
            payment.frequency

        editedScheduledDate =
            payment
                .scheduledPaymentDate

        editedNote =
            payment.note
    }

    // MARK: - Status Color

    private var statusColor: Color {

        if !payment.isActive {

            return .gray
        }

        if payment.isDue {

            return .red
        }

        if payment.isPostponed {

            return .orange
        }

        return .green
    }

    // MARK: - Payment History Row

    private func paymentHistoryRow(
        _ transaction:
            ExpenseTransaction
    ) -> some View {

        HStack(
            spacing: 12
        ) {

            Image(
                systemName:
                    "checkmark.circle.fill"
            )
            .foregroundStyle(
                .green
            )

            VStack(
                alignment: .leading,
                spacing: 4
            ) {

                Text(
                    transaction.date
                        .formatted(
                            date: .abbreviated,
                            time: .omitted
                        )
                )
                .fontWeight(
                    .medium
                )

                if let wallet =
                    transaction.wallet {

                    Text(
                        wallet.name
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }

            Spacer()

            Text(
                "\(transaction.amount.formatted(.number)) \(transaction.wallet?.currencyCode ?? "")"
            )
            .fontWeight(
                .semibold
            )
        }
        .padding(
            .vertical,
            3
        )
    }

    // MARK: - Postpone

    private func postpone(
        byDays days: Int
    ) {

        let startingDate =
            max(
                payment.nextPaymentDate,
                Date()
            )

        guard
            let newDate =
                Calendar.current.date(
                    byAdding:
                        .day,
                    value:
                        days,
                    to:
                        startingDate
                )
        else {

            return
        }

        payment.postponedUntil =
            newDate
    }

    // MARK: - Custom Postpone Date

    private func prepareCustomPostponeDate() {

        let tomorrow =
            Calendar.current.date(
                byAdding:
                    .day,
                value:
                    1,
                to:
                    Date()
            )
            ??
            Date()

        customPostponeDate =
            max(
                payment.nextPaymentDate,
                tomorrow
            )

        showingCustomPostponeDate =
            true
    }

    private func applyCustomPostponeDate() {

        payment.postponedUntil =
            customPostponeDate

        showingCustomPostponeDate =
            false
    }

    // MARK: - Skip

    private func skipPayment() {

        payment.scheduledPaymentDate =
            nextScheduledDate(
                from:
                    payment
                        .scheduledPaymentDate
            )

        payment.postponedUntil =
            nil
    }

    // MARK: - Delete

    private func deleteRecurringPayment() {

        for transaction
            in paymentTransactions {

            transaction.recurringPayment =
                nil
        }

        modelContext.delete(
            payment
        )

        dismiss()
    }

    // MARK: - Next Date

    private func nextScheduledDate(
        from date: Date
    ) -> Date {

        let calendar =
            Calendar.current

        switch payment.frequency {

        case "Weekly":

            return calendar.date(
                byAdding:
                    .weekOfYear,
                value: 1,
                to: date
            )
            ??
            date

        case "Monthly":

            return calendar.date(
                byAdding:
                    .month,
                value: 1,
                to: date
            )
            ??
            date

        case "Every 3 Months":

            return calendar.date(
                byAdding:
                    .month,
                value: 3,
                to: date
            )
            ??
            date

        case "Every 6 Months":

            return calendar.date(
                byAdding:
                    .month,
                value: 6,
                to: date
            )
            ??
            date

        case "Yearly":

            return calendar.date(
                byAdding:
                    .year,
                value: 1,
                to: date
            )
            ??
            date

        default:

            return date
        }
    }
}
