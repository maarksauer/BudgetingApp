import SwiftUI
import SwiftData

nonisolated enum TransactionFormField: Hashable { case name, amount, note }

@MainActor
struct ExpenseDraft {
    var isIncome = false
    var amount = ""
    var note = ""
    var transactionDate = Date()
    var selectedWallet: Wallet?
    var selectedCategory: SpendingCategory?
    var selectedSubcategoryID: PersistentIdentifier?

    var total: Decimal? { AmountInput.positive(amount) }
    var cleanedNote: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }
    var subcategory: SpendingSubcategory? {
        selectedCategory?.subcategories.first { $0.persistentModelID == selectedSubcategoryID }
    }
    var hasRequiredFields: Bool {
        total != nil && selectedWallet != nil && (isIncome || selectedCategory != nil) &&
        transactionDate.timeIntervalSinceReferenceDate.isFinite
    }

    func availableAmount(transfers: [WalletTransfer], excluding transaction: ExpenseTransaction? = nil) -> Decimal {
        guard let wallet = selectedWallet else { return 0 }
        var balance = wallet.balance(including: transfers)
        if let transaction, transaction.wallet?.persistentModelID == wallet.persistentModelID {
            balance -= transaction.balanceImpact
        }
        return max(balance - wallet.minimumAllowedBalance, 0)
    }

    func canSave(transfers: [WalletTransfer], excluding transaction: ExpenseTransaction? = nil) -> Bool {
        guard hasRequiredFields, let total else { return false }
        return isIncome || total <= availableAmount(transfers: transfers, excluding: transaction)
    }

    init() { }
    init(transaction: ExpenseTransaction) {
        isIncome = transaction.isIncome
        amount = NSDecimalNumber(decimal: transaction.amount).stringValue
        note = transaction.note
        transactionDate = transaction.date
        selectedWallet = transaction.wallet
        selectedCategory = transaction.category
        selectedSubcategoryID = transaction.subcategory?.persistentModelID
    }
}

@MainActor
struct RecurringPaymentFormDraft {
    var name = ""
    var details = ExpenseDraft()
    var frequency = "Monthly"
    var scheduledDate = Date()

    var cleanedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var canSave: Bool {
        !cleanedName.isEmpty && details.hasRequiredFields && !details.isIncome &&
        RecurringSchedule.frequencies.contains(frequency) && scheduledDate.timeIntervalSinceReferenceDate.isFinite
    }

    init() { }
    init(payment: RecurringPayment) {
        name = payment.name
        details.amount = NSDecimalNumber(decimal: payment.amount).stringValue
        details.note = payment.note
        details.selectedWallet = payment.wallet
        details.selectedCategory = payment.category
        details.selectedSubcategoryID = payment.subcategory?.persistentModelID
        frequency = payment.frequency
        scheduledDate = payment.scheduledPaymentDate
    }
}

struct TransactionAmountSection: View {
    let title: String
    let symbol: String
    let tint: Color
    @Binding var amount: String
    let currencyCode: String
    var focusedField: FocusState<TransactionFormField?>.Binding
    let identifier: String

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Label(title, systemImage: symbol)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(tint)
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    TextField("0", text: $amount)
                        .font(.largeTitle.weight(.semibold)).monospacedDigit()
                        .keyboardType(.decimalPad)
                        .focused(focusedField, equals: .amount)
                        .accessibilityLabel("Amount").accessibilityIdentifier(identifier)
                    if !currencyCode.isEmpty {
                        Text(currencyCode).font(.headline).foregroundStyle(.secondary)
                    }
                }
                if !amount.isEmpty && AmountInput.positive(amount) == nil {
                    FormValidationMessage(text: "Enter a complete amount greater than zero.")
                }
            }
            .padding(.vertical, 8)
        } footer: {
            Text("Use a decimal point or comma, and spaces for thousands.")
        }
    }
}

struct TransactionSelectionSections: View {
    @Binding var draft: ExpenseDraft
    let wallets: [Wallet]
    let categories: [SpendingCategory]
    let prefix: String

    var body: some View {
        Section("Wallet") {
            if wallets.isEmpty {
                Label("Create a wallet first in Wallets.", systemImage: "wallet.bifold")
                    .foregroundStyle(.secondary)
            } else {
                Picker(selection: $draft.selectedWallet) {
                    Text("Select Wallet").tag(nil as Wallet?)
                    ForEach(wallets) { wallet in
                        Label("\(wallet.name) • \(wallet.currencyCode)", systemImage: wallet.icon)
                            .tag(wallet as Wallet?)
                    }
                } label: {
                    Label("Wallet", systemImage: "wallet.bifold")
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("\(prefix)Wallet")
            }
        }
        if !draft.isIncome {
            Section("Category") {
                if categories.isEmpty {
                    Text("No categories available. Add one in More → Categories.")
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                        ForEach(categories) { category in
                            let selected = draft.selectedCategory?.persistentModelID == category.persistentModelID
                            Button {
                                draft.selectedCategory = category
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: category.icon)
                                        .foregroundStyle(FormPalette.color(category.colorName))
                                    Text(category.name).font(.subheadline.weight(.medium))
                                    Spacer(minLength: 0)
                                    if selected { Image(systemName: "checkmark").font(.caption.weight(.bold)) }
                                }
                                .padding(12).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .background(selected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06),
                                            in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(category.name)
                            .accessibilityAddTraits(selected ? .isSelected : [])
                            .accessibilityIdentifier("\(prefix)Category-\(category.name)")
                        }
                    }
                    .padding(.vertical, 4)
                    if let category = draft.selectedCategory, !category.subcategories.isEmpty {
                        Picker("Subcategory", selection: $draft.selectedSubcategoryID) {
                            Text("None").tag(nil as PersistentIdentifier?)
                            ForEach(category.subcategories.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) {
                                Text($0.name).tag($0.persistentModelID as PersistentIdentifier?)
                            }
                        }
                        .pickerStyle(.menu)
                        .accessibilityIdentifier("\(prefix)Subcategory")
                    }
                }
            }
            .onChange(of: draft.selectedCategory?.persistentModelID) {
                draft.selectedSubcategoryID = nil
            }
        }
    }
}

struct TransactionFormFields: View {
    @Binding var draft: ExpenseDraft
    let wallets: [Wallet]
    let categories: [SpendingCategory]
    let transfers: [WalletTransfer]
    var editingTransaction: ExpenseTransaction? = nil
    var focusedField: FocusState<TransactionFormField?>.Binding
    let prefix: String

    var body: some View {
        TransactionAmountSection(title: draft.isIncome ? "Money in" : "Money out",
                                 symbol: draft.isIncome ? "arrow.down.left.circle.fill" : "arrow.up.right.circle.fill",
                                 tint: draft.isIncome ? .green : .orange, amount: $draft.amount,
                                 currencyCode: draft.selectedWallet?.currencyCode ?? "",
                                 focusedField: focusedField, identifier: "\(prefix)Amount")
        Section("Details") {
            DatePicker("Date", selection: $draft.transactionDate, in: ...Date(), displayedComponents: .date)
            TextField(draft.isIncome ? "Source or note (optional)" : "Note (optional)", text: $draft.note)
                .focused(focusedField, equals: .note).submitLabel(.done)
                .onSubmit { focusedField.wrappedValue = nil }
                .accessibilityIdentifier("\(prefix)Note")
        }
        TransactionSelectionSections(draft: $draft, wallets: wallets, categories: categories, prefix: prefix)
        if let wallet = draft.selectedWallet {
            Section("Balance") {
                LabeledContent("Current Balance", value: wallet.balance(including: transfers).formatted(.currency(code: wallet.currencyCode)))
                if !draft.isIncome {
                    let available = draft.availableAmount(transfers: transfers, excluding: editingTransaction)
                    LabeledContent(wallet.walletType == "Credit Card" ? "Available Credit" : "Available to Spend",
                                   value: available.formatted(.currency(code: wallet.currencyCode)))
                    if let total = draft.total, total > available {
                        FormValidationMessage(text: "This expense exceeds the available amount of \(available.formatted(.currency(code: wallet.currencyCode))).")
                    }
                }
            }
        }
    }
}

struct RecurringPaymentFormFields: View {
    @Binding var draft: RecurringPaymentFormDraft
    let wallets: [Wallet]
    let categories: [SpendingCategory]
    let isEditing: Bool
    var focusedField: FocusState<TransactionFormField?>.Binding

    var body: some View {
        Section("Payment") {
            TextField("Payment name", text: $draft.name)
                .focused(focusedField, equals: .name).submitLabel(.next)
                .onSubmit { focusedField.wrappedValue = .amount }
                .accessibilityIdentifier("recurringFormName")
            if !draft.name.isEmpty && draft.cleanedName.isEmpty {
                FormValidationMessage(text: "Enter a payment name.")
            }
        }
        TransactionAmountSection(title: "Scheduled amount", symbol: "arrow.trianglehead.2.clockwise.rotate.90",
                                 tint: .blue, amount: $draft.details.amount,
                                 currencyCode: draft.details.selectedWallet?.currencyCode ?? "",
                                 focusedField: focusedField, identifier: "recurringFormAmount")
        Section("Schedule") {
            Picker("Repeat", selection: $draft.frequency) {
                ForEach(RecurringSchedule.frequencies, id: \.self) { Text($0).tag($0) }
            }
            if isEditing {
                DatePicker("Next Scheduled Date", selection: $draft.scheduledDate, displayedComponents: .date)
            } else {
                DatePicker("First Payment", selection: $draft.scheduledDate,
                           in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
            }
            Label("Payments are recorded only when you confirm they were made.", systemImage: "info.circle")
                .font(.caption).foregroundStyle(.secondary)
        }
        TransactionSelectionSections(draft: $draft.details, wallets: wallets, categories: categories, prefix: "recurringForm")
        Section("Note") {
            TextField("Optional note", text: $draft.details.note)
                .focused(focusedField, equals: .note).submitLabel(.done)
                .onSubmit { focusedField.wrappedValue = nil }
                .accessibilityIdentifier("recurringFormNote")
        }
    }
}

nonisolated enum FormPalette {
    static func color(_ name: String) -> Color {
        switch name {
        case "green": .green
        case "orange": .orange
        case "purple": .purple
        case "red": .red
        case "pink": .pink
        case "teal": .teal
        case "gray": .gray
        default: .blue
        }
    }
}

struct TransactionSummaryRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let subtitle: String
    let detail: String
    let symbol: String
    let tint: Color
    let amount: String
    let currency: String
    let secondaryAmount: String?

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    description
                    amounts
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    description
                    Spacer(minLength: 8)
                    amounts
                }
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private var description: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.body.weight(.semibold)).foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text(subtitle).font(.caption.weight(.medium)).foregroundStyle(tint)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var amounts: some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 4) {
            Text(amount).font(.subheadline.weight(.semibold)).monospacedDigit()
                .foregroundStyle(tint)
            Text(currency).font(.caption).foregroundStyle(.secondary)
            if let secondaryAmount {
                Text(secondaryAmount).font(.caption).monospacedDigit().foregroundStyle(.secondary)
            }
        }
    }
}
