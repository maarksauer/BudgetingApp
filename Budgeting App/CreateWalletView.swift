import SwiftUI
import SwiftData

struct CreateWalletView: View {

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.modelContext)
    private var modelContext

    @State private var name = ""
    @State private var startingBalance = ""
    @State private var currency = "HUF"

    @State private var walletType = "Bank Account"

    @State private var icon =
        "wallet.bifold.fill"

    @State private var colorName =
        "blue"

    @State private var allowsNegativeBalance =
        false

    @State private var negativeBalanceLimit =
        ""

    let currencies = [
        "HUF",
        "EUR",
        "GBP",
        "USD"
    ]

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
                        parsedStartingBalance == nil {

                        Text(
                            "Enter a valid starting balance."
                        )
                        .font(.caption)
                        .foregroundStyle(.red)
                    }

                    Picker(
                        "Currency",
                        selection: $currency
                    ) {

                        ForEach(
                            currencies,
                            id: \.self
                        ) { currency in

                            Text(currency)
                        }
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
                                    "-\(limit.formatted(.number)) \(currency)"
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
                        selection: $icon
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

                Section {

                    Button {

                        createWallet()

                    } label: {

                        Text(
                            "Create Wallet"
                        )
                        .frame(
                            maxWidth:
                                .infinity
                        )
                    }
                    .disabled(
                        !canCreateWallet
                    )
                }
            }

            .navigationTitle(
                "New Wallet"
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

    private var cleanedName: String {

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

    private var parsedStartingBalance:
        Decimal? {

        parseDecimal(
            startingBalance,
            allowNegative: true
        )
    }

    private var parsedNegativeLimit:
        Decimal? {

        guard
            let value =
                parseDecimal(
                    negativeBalanceLimit,
                    allowNegative: false
                ),
            value > 0
        else {
            return nil
        }

        return value
    }

    private var canCreateWallet:
        Bool {

        guard
            !cleanedName.isEmpty,
            parsedStartingBalance != nil
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
                    string: cleaned
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

    private func createWallet() {

        guard
            let balance =
                parsedStartingBalance
        else {
            return
        }

        let limit =
            effectiveAllowsNegativeBalance
            ? parsedNegativeLimit ?? 0
            : 0

        let wallet =
            Wallet(
                name:
                    cleanedName,
                startingBalance:
                    balance,
                currencyCode:
                    currency,
                walletType:
                    walletType,
                icon:
                    icon,
                colorName:
                    colorName,
                allowsNegativeBalance:
                    effectiveAllowsNegativeBalance,
                negativeBalanceLimit:
                    limit
            )

        modelContext.insert(
            wallet
        )

        dismiss()
    }
}
