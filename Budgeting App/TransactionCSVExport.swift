import Foundation
import SwiftData

@MainActor
enum TransactionCSVExport {
    nonisolated enum Separator: String, CaseIterable, Identifiable {
        case comma = ","
        case semicolon = ";"

        var id: String { rawValue }
        var title: String { self == .comma ? "Comma (,)" : "Semicolon (;)" }
    }

    nonisolated struct Options {
        var separator: Separator = .comma
        var includeTransfers = true
        var startDate: Date?
        var endDate: Date?
    }

    struct Export {
        let data: Data
        let rowCount: Int
    }

    private enum Cell {
        case text(String)
        case number(Decimal)
    }

    private struct Row {
        let id: String
        let date: Date
        let cells: [Cell]
    }

    static func rowCount(
        transactions: [ExpenseTransaction], transfers: [WalletTransfer],
        options: Options, calendar: Calendar = .current
    ) -> Int {
        let transactionCount = transactions.filter { includes($0.date, options: options, calendar: calendar) }.count
        let transferCount = options.includeTransfers
            ? transfers.filter { includes($0.date, options: options, calendar: calendar) }.count : 0
        return transactionCount + transferCount
    }

    static func makeExport(
        transactions: [ExpenseTransaction], transfers: [WalletTransfer],
        options: Options = Options(), calendar: Calendar = .current
    ) -> Export {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var rows = transactions.filter { includes($0.date, options: options, calendar: calendar) }.map { transaction in
            Row(id: "transaction-\(transaction.persistentModelID)", date: transaction.date, cells: [
                .text(dateFormatter.string(from: transaction.date)),
                .text(transaction.typeName),
                .text(transaction.wallet?.name ?? ""),
                .number(transaction.balanceImpact),
                .text(transaction.wallet?.currencyCode ?? ""),
                .text(transaction.category?.name ?? ""),
                .text(transaction.subcategory?.name ?? ""),
                .text(transaction.note),
                .text(""), .text(""), .text(""),
                .text(transaction.recurringPayment?.name ?? "")
            ])
        }
        if options.includeTransfers {
            rows += transfers.filter { includes($0.date, options: options, calendar: calendar) }.map { transfer in
                Row(id: "transfer-\(transfer.persistentModelID)", date: transfer.date, cells: [
                    .text(dateFormatter.string(from: transfer.date)),
                    .text("Transfer"),
                    .text(transfer.sourceWallet?.name ?? ""),
                    .number(-transfer.sourceAmount),
                    .text(transfer.sourceCurrencyCode),
                    .text(""), .text(""), .text(transfer.note),
                    .text(transfer.destinationWallet?.name ?? ""),
                    .number(transfer.destinationAmount),
                    .text(transfer.destinationCurrencyCode),
                    .text("")
                ])
            }
        }
        rows.sort {
            if $0.date == $1.date { return $0.id < $1.id }
            return $0.date < $1.date
        }
        let headers = [
            "Date", "Type", "Wallet", "Amount", "Currency", "Category", "Subcategory", "Note",
            "Destination Wallet", "Destination Amount", "Destination Currency", "Recurring Payment"
        ]
        var lines = [headers.map { encode(.text($0), separator: options.separator) }.joined(separator: options.separator.rawValue)]
        lines += rows.map { row in
            row.cells.map { encode($0, separator: options.separator) }.joined(separator: options.separator.rawValue)
        }
        // Excel recognises UTF-8 accents reliably when a BOM is present.
        let csv = "\u{FEFF}" + lines.joined(separator: "\r\n") + "\r\n"
        return Export(data: Data(csv.utf8), rowCount: rows.count)
    }

    static func filename(now: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "Budgeting-Transactions-\(formatter.string(from: now)).csv"
    }

    private static func includes(_ date: Date, options: Options, calendar: Calendar) -> Bool {
        if let start = options.startDate, date < calendar.startOfDay(for: start) { return false }
        if let end = options.endDate {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end)),
                  date < nextDay else { return false }
        }
        return true
    }

    private static func encode(_ cell: Cell, separator: Separator) -> String {
        switch cell {
        case .number(let number):
            // Match the two common Excel regional CSV formats without grouping separators.
            let value = NSDecimalNumber(decimal: number).stringValue
            return separator == .semicolon ? value.replacingOccurrences(of: ".", with: ",") : value
        case .text(let value):
            var literal = value
            // Notes and names must remain text when opened in a spreadsheet.
            if let first = value.trimmingCharacters(in: .whitespacesAndNewlines).first,
               "=+-@".contains(first) {
                literal = "'" + value
            }
            return "\"" + literal.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
    }
}
