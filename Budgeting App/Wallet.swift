import Foundation
import SwiftData

@Model
final class Wallet {

    var name: String
    var startingBalance: Decimal
    var currencyCode: String
    var walletType: String
    var icon: String
    var colorName: String
    var createdAt: Date

    var allowsNegativeBalance: Bool = false
    var negativeBalanceLimit: Decimal = 0

    var transactions: [ExpenseTransaction] = []

    init(
        name: String,
        startingBalance: Decimal,
        currencyCode: String,
        walletType: String,
        icon: String = "wallet.bifold.fill",
        colorName: String = "blue",
        allowsNegativeBalance: Bool = false,
        negativeBalanceLimit: Decimal = 0
    ) {
        self.name = name
        self.startingBalance = startingBalance
        self.currencyCode = currencyCode
        self.walletType = walletType
        self.icon = icon
        self.colorName = colorName
        self.allowsNegativeBalance = allowsNegativeBalance
        self.negativeBalanceLimit = negativeBalanceLimit
        self.createdAt = Date()
    }

    var currentBalance: Decimal {

        let totalExpenses =
            transactions.reduce(
                Decimal.zero
            ) {
                result,
                transaction in

                result + transaction.amount
            }

        return
            startingBalance
            -
            totalExpenses
    }

    var minimumAllowedBalance: Decimal {

        guard allowsNegativeBalance else {
            return 0
        }

        return -negativeBalanceLimit
    }
}
