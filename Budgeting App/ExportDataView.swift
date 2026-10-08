import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Foundation
#if os(iOS) || os(visionOS)
import UIKit
#endif

struct ExportDataView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseTransaction.date) private var transactions: [ExpenseTransaction]
    @Query(sort: \WalletTransfer.date) private var transfers: [WalletTransfer]

    @State private var separator: TransactionCSVExport.Separator = .comma
    @State private var includeTransfers = true
    @State private var useDateRange = false
    @State private var startDate = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var endDate = Date()
    @State private var document = TransactionCSVDocument(data: Data())
    @State private var exportFilename = "Budgeting-Transactions.csv"
    @State private var showingFileExporter = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    #if os(iOS) || os(visionOS)
    @State private var shareFile: CSVShareFile?
    @State private var temporaryShareDirectory: URL?
    #endif

    private var options: TransactionCSVExport.Options {
        TransactionCSVExport.Options(
            separator: separator, includeTransfers: includeTransfers,
            startDate: useDateRange ? startDate : nil,
            endDate: useDateRange ? endDate : nil
        )
    }

    private var rowCount: Int {
        TransactionCSVExport.rowCount(transactions: transactions, transfers: transfers, options: options)
    }

    var body: some View {
        Form {
            Section {
                Text("Export your transactions to a CSV file for Excel or another spreadsheet app.")
                    .foregroundStyle(.secondary)
                ReadableDetailRow(title: "Rows to export", value: "\(rowCount)")
                    .accessibilityIdentifier("csvExportRowCount")
                Toggle("Include wallet transfers", isOn: $includeTransfers)
                    .accessibilityIdentifier("csvIncludeTransfers")
            }
            Section("Date Range") {
                Toggle("Use date range", isOn: $useDateRange)
                    .accessibilityIdentifier("csvUseDateRange")
                if useDateRange {
                    DatePicker("From", selection: $startDate, in: ...Date(), displayedComponents: .date)
                    DatePicker("To", selection: $endDate, in: startDate...Date(), displayedComponents: .date)
                } else {
                    Text("All saved transactions")
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Picker("Separator", selection: $separator) {
                    ForEach(TransactionCSVExport.Separator.allCases) { separator in
                        Text(separator.title).tag(separator)
                    }
                }
                .accessibilityIdentifier("csvSeparator")
            } header: {
                Text("CSV Format")
            } footer: {
                Text("Comma uses decimal points. Semicolon uses decimal commas. If Excel opens everything in one column, try the other format or import the file with the matching separator.")
            }
            Section {
                Button(action: saveCSV) {
                    Label("Save CSV", systemImage: "square.and.arrow.down")
                }
                .accessibilityIdentifier("saveTransactionCSV")
                .disabled(rowCount == 0)
                #if os(iOS) || os(visionOS)
                Button(action: shareCSV) {
                    Label("Share CSV", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("shareTransactionCSV")
                .disabled(rowCount == 0)
                #endif
                if rowCount == 0 {
                    Text("No transactions match these options.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("Income amounts are positive and expenses are negative. Each transfer has one row with both wallet amounts and currencies.")
            }
        }
        .navigationTitle("Export Data")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: startDate) {
            if startDate > endDate { endDate = startDate }
        }
        .fileExporter(
            isPresented: $showingFileExporter, document: document,
            contentType: .commaSeparatedText, defaultFilename: exportFilename
        ) { result in
            switch result {
            case .success(let url):
                showAlert(title: "CSV Saved", message: "Saved \(url.lastPathComponent).")
            case .failure(let error):
                let cocoaError = error as NSError
                if cocoaError.domain != NSCocoaErrorDomain || cocoaError.code != NSUserCancelledError {
                    showAlert(title: "Couldn’t export CSV", message: error.localizedDescription)
                }
            }
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        #if os(iOS) || os(visionOS)
        .sheet(item: $shareFile, onDismiss: removeTemporaryShareFile) { file in
            CSVShareSheet(url: file.url) { shareFile = nil }
        }
        #endif
    }

    private func prepareExport() throws -> TransactionCSVExport.Export {
        // Flush pending edits before taking the export snapshot.
        try modelContext.save()
        return TransactionCSVExport.makeExport(transactions: transactions, transfers: transfers, options: options)
    }

    private func saveCSV() {
        do {
            let export = try prepareExport()
            guard export.rowCount > 0 else { return }
            document = TransactionCSVDocument(data: export.data)
            exportFilename = TransactionCSVExport.filename()
            showingFileExporter = true
        } catch {
            showAlert(title: "Couldn’t export CSV", message: error.localizedDescription)
        }
    }

    #if os(iOS) || os(visionOS)
    private func shareCSV() {
        do {
            let export = try prepareExport()
            guard export.rowCount > 0 else { return }
            removeTemporaryShareFile()
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("CSV-\(UUID().uuidString)", isDirectory: true)
            temporaryShareDirectory = directory
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(TransactionCSVExport.filename())
            try export.data.write(to: url, options: .atomic)
            shareFile = CSVShareFile(url: url)
        } catch {
            removeTemporaryShareFile()
            showAlert(title: "Couldn’t share CSV", message: error.localizedDescription)
        }
    }

    private func removeTemporaryShareFile() {
        if let directory = temporaryShareDirectory {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryShareDirectory = nil
    }
    #endif

    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

// FileDocument reads and writes can run off the main actor. Only immutable bytes
// cross that boundary; SwiftData models are read when preparing the export.
nonisolated struct TransactionCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

#if os(iOS) || os(visionOS)
private struct CSVShareFile: Identifiable {
    let id = UUID()
    let url: URL
}

private struct CSVShareSheet: UIViewControllerRepresentable {
    let url: URL
    let onComplete: @MainActor @Sendable () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        let completion = onComplete
        controller.completionWithItemsHandler = { _, _, _, _ in
            Task { @MainActor in completion() }
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}
#endif
