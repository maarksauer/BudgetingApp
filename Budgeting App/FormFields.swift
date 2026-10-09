import SwiftUI

nonisolated enum WalletFormField: Hashable { case name, balance, limit }
nonisolated enum BudgetFormField: Hashable { case name, amount }

private enum WalletFormStyle {
    static let types = ["Cash", "Bank Account", "Savings", "Credit Card", "Other"]
    static let icons = ["wallet.bifold.fill", "banknote.fill", "building.columns.fill", "creditcard.fill", "dollarsign.circle.fill"]
    static let colors = ["blue", "green", "orange", "purple", "red", "pink", "teal", "gray"]

    static func iconTitle(_ code: String) -> String {
        switch code {
        case "wallet.bifold.fill": return "Wallet"
        case "banknote.fill": return "Cash"
        case "building.columns.fill": return "Bank"
        case "creditcard.fill": return "Card"
        case "dollarsign.circle.fill": return "Currency"
        default: return "Current Icon"
        }
    }

    static func color(_ name: String) -> Color {
        switch name {
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "red": return .red
        case "pink": return .pink
        case "teal": return .teal
        case "gray": return .gray
        default: return .blue
        }
    }

    static func including(_ selected: String, in options: [String]) -> [String] {
        options.contains(selected) ? options : options + [selected]
    }
}

struct FormValidationMessage: View {
    let text: String
    var body: some View {
        Label(text, systemImage: "exclamationmark.circle")
            .font(.caption).foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct WalletFormFields: View {
    @Binding var draft: WalletFormDraft
    let currencyCodes: [String]
    let canChooseCurrency: Bool
    var focusedField: FocusState<WalletFormField?>.Binding

    var body: some View {
        Group {
            Section {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: draft.icon)
                        .font(.system(size: 24)).foregroundStyle(WalletFormStyle.color(draft.colorName))
                        .frame(width: 50, height: 50)
                        .background(WalletFormStyle.color(draft.colorName).opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(draft.cleanedName.isEmpty ? "Your Wallet" : draft.cleanedName).font(.headline)
                        Text(draft.walletType).font(.subheadline).foregroundStyle(.secondary)
                        Text("Starting balance").font(.caption).foregroundStyle(.secondary)
                        if let balance = draft.balance {
                            Text(balance.formatted(.currency(code: draft.currencyCode)))
                                .font(.title2.weight(.semibold)).monospacedDigit()
                        } else {
                            Text("Enter a balance").foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 6)
                .accessibilityElement(children: .combine)
            }
            detailsSection
            balanceSection
            appearanceSection
        }
    }

    private var detailsSection: some View {
        Section {
            TextField("Wallet name", text: $draft.name)
                .focused(focusedField, equals: .name).submitLabel(.next)
                .onSubmit { focusedField.wrappedValue = .balance }
                .accessibilityIdentifier("walletFormName")
            if !draft.name.isEmpty && draft.cleanedName.isEmpty {
                FormValidationMessage(text: "Enter a wallet name.")
            }
            Picker("Wallet Type", selection: $draft.walletType) {
                ForEach(WalletFormStyle.including(draft.walletType, in: WalletFormStyle.types), id: \.self) {
                    Text($0).tag($0)
                }
            }
            if canChooseCurrency {
                Picker("Currency", selection: $draft.currencyCode) {
                    ForEach(currencyCodes, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("walletFormCurrency")
                NavigationLink("Manage Currencies") { CurrenciesSettingsView() }
            } else {
                LabeledContent("Currency", value: draft.currencyCode)
            }
        } header: {
            Text("Wallet Details")
        } footer: {
            if !canChooseCurrency { Text("The currency stays fixed for this wallet and its history.") }
        }
    }

    private var balanceSection: some View {
        Section {
            LabeledContent("Starting Balance") {
                TextField("0", text: $draft.startingBalance)
                    .keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing)
                    .focused(focusedField, equals: .balance).submitLabel(.done)
                    .onSubmit { focusedField.wrappedValue = nil }
                    .accessibilityLabel("Starting balance").accessibilityIdentifier("walletFormBalance")
            }
            if !draft.startingBalance.isEmpty && draft.balance == nil {
                FormValidationMessage(text: "Enter a complete number using a decimal point or comma.")
            }
            Toggle("Allow Negative Balance", isOn: Binding(
                get: { draft.effectiveAllowsNegativeBalance }, set: { draft.allowsNegativeBalance = $0 }
            ))
                .disabled(draft.walletType == "Credit Card")
            if draft.walletType == "Credit Card" {
                Text("Credit cards always allow a negative balance.").font(.caption).foregroundStyle(.secondary)
            }
            if draft.effectiveAllowsNegativeBalance {
                LabeledContent(draft.walletType == "Credit Card" ? "Credit Limit" : "Overdraft Limit") {
                    TextField("0", text: $draft.negativeBalanceLimit)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        .focused(focusedField, equals: .limit)
                        .accessibilityLabel(draft.walletType == "Credit Card" ? "Credit limit" : "Overdraft limit")
                        .accessibilityIdentifier("walletFormLimit")
                }
                if !draft.negativeBalanceLimit.isEmpty && draft.limit == nil {
                    FormValidationMessage(text: "Enter a limit greater than zero.")
                }
                if let limit = draft.limit {
                    LabeledContent("Lowest Balance", value: (-limit).formatted(.currency(code: draft.currencyCode)))
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Balance & Limits")
        } footer: { Text("Starting balance is the balance before your recorded transactions. Use a decimal point or comma, and spaces for thousands.") }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Icon", selection: $draft.icon) {
                ForEach(WalletFormStyle.including(draft.icon, in: WalletFormStyle.icons), id: \.self) { code in
                    Label(WalletFormStyle.iconTitle(code), systemImage: code).tag(code)
                }
            }
            .pickerStyle(.navigationLink)
            Picker("Color", selection: $draft.colorName) {
                ForEach(WalletFormStyle.including(draft.colorName, in: WalletFormStyle.colors), id: \.self) { name in
                    HStack {
                        Image(systemName: "circle.fill").foregroundStyle(WalletFormStyle.color(name))
                        Text(name.capitalized)
                    }.tag(name)
                }
            }
            .pickerStyle(.navigationLink)
        }
    }
}

struct BudgetFormFields: View {
    @Binding var draft: BudgetFormDraft
    let currencyCodes: [String]
    let isPartOfRecurringSeries: Bool
    var focusedField: FocusState<BudgetFormField?>.Binding

    var body: some View {
        Group {
            Section {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "chart.pie.fill").font(.title2).foregroundStyle(.blue)
                        .frame(width: 50, height: 50)
                        .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(draft.cleanedName.isEmpty ? "Your Budget" : draft.cleanedName).font(.headline)
                        Text("Budget limit").font(.caption).foregroundStyle(.secondary)
                        if let total = draft.total {
                            Text(total.formatted(.currency(code: draft.currencyCode)))
                                .font(.title2.weight(.semibold)).monospacedDigit()
                        } else { Text("Enter an amount").foregroundStyle(.secondary) }
                        Text("\(draft.startDate.formatted(date: .abbreviated, time: .omitted)) – \(draft.endDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6).accessibilityElement(children: .combine)
            }
            Section {
                TextField("Budget name", text: $draft.name)
                    .focused(focusedField, equals: .name).submitLabel(.next)
                    .onSubmit { focusedField.wrappedValue = .amount }
                    .accessibilityIdentifier("budgetFormName")
                if !draft.name.isEmpty && draft.cleanedName.isEmpty {
                    FormValidationMessage(text: "Enter a budget name.")
                }
                LabeledContent("Total Amount") {
                    TextField("0", text: $draft.amount)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        .focused(focusedField, equals: .amount)
                        .accessibilityLabel("Total amount").accessibilityIdentifier("budgetFormAmount")
                }
                if !draft.amount.isEmpty && draft.total == nil {
                    FormValidationMessage(text: "Enter a complete amount greater than zero.")
                }
                Picker("Currency", selection: $draft.currencyCode) {
                    ForEach(currencyCodes, id: \.self) { Text($0).tag($0) }
                }
            } header: {
                Text("Budget Details")
            } footer: { Text("Use a decimal point or comma, and spaces for thousands.") }
            Section {
                DatePicker("Start Date", selection: $draft.startDate, displayedComponents: .date)
                DatePicker("End Date", selection: $draft.endDate, in: draft.startDate..., displayedComponents: .date)
                if !draft.periodIsValid { FormValidationMessage(text: "The end date must be on or after the start date.") }
            } header: {
                Text("Period")
            } footer: {
                if isPartOfRecurringSeries { Text("Period dates apply only to the budget you are editing.") }
            }
            Section {
                Toggle("Recurring Budget", isOn: $draft.isRecurring)
                if draft.isRecurring {
                    Picker("Repeat", selection: $draft.recurrenceType) {
                        ForEach(WalletFormStyle.including(draft.recurrenceType, in: ["Monthly"]), id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                }
            } header: {
                Text("Repeat")
            } footer: {
                if draft.isRecurring { Text("A new monthly period is created when this budget ends.") }
            }
        }
        .onChange(of: draft.startDate) {
            if !draft.periodIsValid { draft.endDate = draft.startDate }
        }
    }
}

// Use intrinsic-height stacks inside List/Form rows. Measuring native Labels
// with ViewThatFits can produce expanded rows and omit their visible titles.
struct AdaptiveValueRow<Leading: View, Trailing: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let leading: Leading
    let trailing: Trailing

    init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    leading
                    trailing
                }
                .multilineTextAlignment(.leading)
            } else {
                HStack(alignment: .top, spacing: 12) {
                    leading
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                    Spacer(minLength: 8)
                    trailing
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        // List's automatic label styling must not turn these labels into icons.
        .labelStyle(.titleAndIcon)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct ReadableDetailRow: View {
    let title: String
    let value: String
    var body: some View {
        AdaptiveValueRow {
            Text(title)
        } trailing: {
            Text(value).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct AmountEntryRow<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let currency: String
    let content: Content
    init(currency: String, @ViewBuilder content: () -> Content) {
        self.currency = currency
        self.content = content()
    }
    private var layout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
        : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
    }
    var body: some View {
        layout {
            content
            if !currency.isEmpty { Text(currency).font(.headline).foregroundStyle(.secondary) }
        }
    }
}
