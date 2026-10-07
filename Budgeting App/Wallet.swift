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
        startingBalance + transactions.reduce(Decimal.zero) {
            $0 + $1.balanceImpact
        }
    }

    /// All screens use the same income, expense, and transfer calculation.
    func balance(including transfers: [WalletTransfer]) -> Decimal {
        let outgoing = transfers.filter {
            $0.sourceWallet?.persistentModelID == persistentModelID
        }.reduce(Decimal.zero) { $0 + $1.sourceAmount }
        let incoming = transfers.filter {
            $0.destinationWallet?.persistentModelID == persistentModelID
        }.reduce(Decimal.zero) { $0 + $1.destinationAmount }
        return currentBalance - outgoing + incoming
    }

    var minimumAllowedBalance: Decimal {

        guard allowsNegativeBalance else {
            return 0
        }

        return -negativeBalanceLimit
    }
}
