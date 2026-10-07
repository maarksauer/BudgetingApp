import SwiftUI
import SwiftData

struct EditWalletView: View {

    @Environment(\.dismiss)
    private var dismiss

    let wallet: Wallet

    @State private var name: String
    @State private var startingBalance: String
    @State private var walletType: String
    @State private var icon: String
    @State private var colorName: String

    @State private var allowsNegativeBalance: Bool
    @State private var negativeBalanceLimit: String

    let walletTypes = [
        "Cash",
        "Bank Account",
        "Savings",
        "Credit Card",
        "Other"
    ]

    let icons = [
        "wallet.bifold.fill",
        "banknote.fill",
        "building.columns.fill",
        "creditcard.fill",
        "dollarsign.circle.fill"
    ]

    let colors = [
        "blue",
        "green",
        "orange",
        "purple",
        "red",
        "pink",
        "teal",
        "gray"
    ]

    init(
        wallet: Wallet
    ) {

        self.wallet =
            wallet

        _name = State(
            initialValue:
                wallet.name
        )

        _startingBalance = State(
            initialValue:
                NSDecimalNumber(
                    decimal:
                        wallet.startingBalance
                )
                .stringValue
        )

        _walletType = State(
            initialValue:
                wallet.walletType
        )

        _icon = State(
            initialValue:
                wallet.icon
        )

        _colorName = State(
            initialValue:
                wallet.colorName
        )

        _allowsNegativeBalance = State(
            initialValue:
                wallet.allowsNegativeBalance
        )

        _negativeBalanceLimit = State(
            initialValue:
                NSDecimalNumber(
                    decimal:
                        wallet.negativeBalanceLimit
                )
                .stringValue
        )
    }

    var body: some View {

        NavigationStack {

            Form {

                Section("Wallet") {

                    TextField(
                        "Wallet name",
                        text: $name
                    )

                    TextField(
                        "Starting balance",
                        text:
                            $startingBalance
                    )
                    .keyboardType(
                        .numbersAndPunctuation
                    )

                    if
                        !startingBalance.isEmpty
                        &&
                        parsedBalance == nil {

                        Text(
                            "Enter a valid balance."
                        )
                        .font(.caption)
                        .foregroundStyle(.red)
                    }

                    HStack {

                        Text("Currency")

                        Spacer()

                        Text(
                            wallet.currencyCode
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }

                Section("Type") {

                    Picker(
                        "Wallet Type",
                        selection:
                            $walletType
                    ) {

                        ForEach(
                            walletTypes,
                            id: \.self
                        ) { type in

                            Text(type)
                        }
                    }
                }

                Section("Balance Rules") {

                    Toggle(
                        "Allow Negative Balance",
                        isOn:
                            $allowsNegativeBalance
                    )
                    .disabled(
                        walletType ==
                        "Credit Card"
                    )

                    if walletType ==
                        "Credit Card" {

                        Text(
                            "Credit cards always allow a negative balance."
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    if effectiveAllowsNegativeBalance {

                        TextField(
                            walletType ==
                            "Credit Card"
                            ? "Credit limit"
                            : "Maximum negative balance",
                            text:
                                $negativeBalanceLimit
                        )
                        .keyboardType(
                            .decimalPad
                        )

                        if
                            !negativeBalanceLimit.isEmpty
                            &&
                            parsedNegativeLimit == nil {

                            Text(
                                walletType ==
                                "Credit Card"
                                ? "Enter a valid credit limit."
                                : "Enter a valid negative balance limit."
                            )
                            .font(.caption)
                            .foregroundStyle(
                                .red
                            )
                        }

                        if
                            let limit =
                                parsedNegativeLimit {

                            HStack {

                                Text(
                                    "Lowest Balance"
                                )

                                Spacer()

                                Text(
                                    "-\(limit.formatted(.number)) \(wallet.currencyCode)"
                                )
                                .foregroundStyle(
                                    .secondary
                                )
                            }
                        }
                    }
                }

                Section("Icon") {

                    Picker(
                        "Icon",
                        selection:
                            $icon
                    ) {

                        ForEach(
                            icons,
                            id: \.self
                        ) { iconName in

                            Label(
                                iconName,
                                systemImage:
                                    iconName
                            )
                            .tag(iconName)
                        }
                    }
                }

                Section("Color") {

                    Picker(
                        "Color",
                        selection:
                            $colorName
                    ) {

                        ForEach(
                            colors,
                            id: \.self
                        ) { color in

                            Text(
                                color.capitalized
                            )
                            .tag(color)
                        }
                    }
                }
            }

            .navigationTitle(
                "Edit Wallet"
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

                        dismiss()
                    }
                }

                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {

                    Button(
                        "Save"
                    ) {

                        saveWallet()
                    }
                    .disabled(
                        !canSave
                    )
                }
            }

            .onChange(
                of: walletType
            ) { _, newValue in

                if newValue ==
                    "Credit Card" {

                    allowsNegativeBalance =
                        true

                    icon =
                        "creditcard.fill"
                }
            }
        }
    }

    private var cleanedName:
        String {

        name.trimmingCharacters(
            in:
                .whitespacesAndNewlines
        )
    }

    private var effectiveAllowsNegativeBalance:
        Bool {

        walletType ==
        "Credit Card"
        ||
        allowsNegativeBalance
    }

    private var parsedBalance:
        Decimal? {

        parseDecimal(
            startingBalance,
            allowNegative: true
        )
    }

    private var parsedNegativeLimit:
        Decimal? {

        guard
            let amount =
                parseDecimal(
                    negativeBalanceLimit,
                    allowNegative: false
                ),
            amount > 0
        else {
            return nil
        }

        return amount
    }

    private var canSave:
        Bool {

        guard
            !cleanedName.isEmpty,
            parsedBalance != nil
        else {
            return false
        }

        if effectiveAllowsNegativeBalance {

            return
                parsedNegativeLimit != nil
        }

        return true
    }

    private func parseDecimal(
        _ value: String,
        allowNegative: Bool
    ) -> Decimal? {

        let cleaned =
            value
                .replacingOccurrences(
                    of: " ",
                    with: ""
                )
                .replacingOccurrences(
                    of: ",",
                    with: "."
                )

        guard
            let amount =
                Decimal(
                    string:
                        cleaned
                )
        else {
            return nil
        }

        if !allowNegative &&
            amount < 0 {

            return nil
        }

        return amount
    }

    private func saveWallet() {

        guard
            let balance =
                parsedBalance
        else {
            return
        }

        wallet.name =
            cleanedName

        wallet.startingBalance =
            balance

        wallet.walletType =
            walletType

        wallet.icon =
            icon

        wallet.colorName =
            colorName

        wallet.allowsNegativeBalance =
            effectiveAllowsNegativeBalance

        wallet.negativeBalanceLimit =
            effectiveAllowsNegativeBalance
            ? parsedNegativeLimit ?? 0
            : 0

        dismiss()
    }
}
