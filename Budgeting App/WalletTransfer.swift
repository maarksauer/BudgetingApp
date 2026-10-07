import Foundation
import SwiftData

@Model
final class WalletTransfer {

    var sourceAmount: Decimal
    var destinationAmount: Decimal

    var date: Date
    var note: String

    var sourceWallet: Wallet?
    var destinationWallet: Wallet?

    var sourceCurrencyCode: String
    var destinationCurrencyCode: String

    var createdAt: Date

    init(
        sourceAmount: Decimal,
        destinationAmount: Decimal,
        date: Date = .now,
        note: String = "",
        sourceWallet: Wallet,
        destinationWallet: Wallet
    ) {

        self.sourceAmount =
            sourceAmount

        self.destinationAmount =
            destinationAmount

        self.date =
            date

        self.note =
            note

        self.sourceWallet =
            sourceWallet

        self.destinationWallet =
            destinationWallet

        self.sourceCurrencyCode =
            sourceWallet.currencyCode

        self.destinationCurrencyCode =
            destinationWallet.currencyCode

        self.createdAt =
            Date()
    }
}
