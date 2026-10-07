import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Foundation

struct BackupRestoreView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(CurrencyPreferences.storageKey) private var storedCurrencyPreferences = CurrencyPreferences.defaultStorageValue
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system
    @AppStorage(AppBackup.restoreRevisionKey) private var restoreRevision = ""
    @AppStorage(AppBackup.restoreNoticeKey) private var showRestoreNotice = false
    @State private var document = BackupDocument(data: Data())
    @State private var exportFilename = "Budgeting-Backup.json"
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var isWorking = false
    @State private var preview: BackupPreview?
    @State private var requestedRestore: AppBackup.Snapshot?
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingAlert = false

    var body: some View {
        Form {
            Section {
                Text("Save a complete backup of your wallets, transactions, transfers, categories, budgets, recurring payments, appearance preference, and currency settings.")
                    .foregroundStyle(.secondary)
                Button(action: saveBackup) {
                    Label("Save Backup", systemImage: "square.and.arrow.down")
                }
                .accessibilityIdentifier("saveAppBackup")
            } header: {
                Text("Backup")
            } footer: {
                Text("The JSON file can restore your data on another installation of Budgeting App. CSV exports cannot be used for restoration.")
            }
            Section {
                Button { showingImporter = true } label: {
                    Label("Choose Backup to Restore", systemImage: "arrow.counterclockwise")
                }
                .accessibilityIdentifier("chooseAppBackup")
            } header: {
                Text("Restore")
            } footer: {
                Text("Review the backup before confirming. Restoring replaces all current data and clears unfinished transaction drafts. A recovery copy of the current data is kept before replacement.")
            }
            if AppBackup.hasRecoveryBackup {
                Section {
                    Button(action: saveRecoveryBackup) {
                        Label("Save Recovery Copy", systemImage: "square.and.arrow.down")
                    }
                    .accessibilityIdentifier("saveRecoveryBackup")
                    Button(action: previewRecoveryBackup) {
                        Label("Review Recovery Copy", systemImage: "clock.arrow.circlepath")
                    }
                    .accessibilityIdentifier("reviewRecoveryBackup")
                } header: {
                    Text("Before Last Restore")
                } footer: {
                    Text("This copy contains the data from immediately before your last restore. Each restore replaces this recovery copy, so save it if you want to keep it.")
                }
            }
            if isWorking {
                Section { ProgressView("Reading backup…") }
            }
        }
        .disabled(isWorking)
        .navigationTitle("Backup & Restore")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(isPresented: $showingExporter, document: document,
                      contentType: .json, defaultFilename: exportFilename) { result in
            switch result {
            case .success(let url): showAlert("Backup Saved", "Saved \(url.lastPathComponent).")
            case .failure(let error): report(error, title: "Couldn’t Save Backup")
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): loadBackup(url: url, name: url.lastPathComponent)
            case .failure(let error): report(error, title: "Couldn’t Open Backup")
            }
        }
        .sheet(item: $preview, onDismiss: restoreIfRequested) { preview in
            BackupPreviewView(preview: preview) {
                requestedRestore = preview.snapshot
                self.preview = nil
            }
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: { Text(alertMessage) }
    }

    private func saveBackup() {
        do {
            let snapshot = try BackupStore.capture(context: modelContext, appearance: appearance,
                                                   currencyPreferences: CurrencyPreferences.decode(storedCurrencyPreferences))
            document = BackupDocument(data: try AppBackup.encode(snapshot))
            exportFilename = AppBackup.filename(date: snapshot.createdAt)
            showingExporter = true
        } catch { report(error, title: "Couldn’t Create Backup") }
    }

    private func saveRecoveryBackup() {
        do {
            let snapshot = try AppBackup.read(from: AppBackup.recoveryURL())
            document = BackupDocument(data: try AppBackup.encode(snapshot))
            exportFilename = "Recovery-" + AppBackup.filename(date: snapshot.createdAt)
            showingExporter = true
        } catch { report(error, title: "Couldn’t Open Recovery Copy") }
    }

    private func previewRecoveryBackup() {
        do { loadBackup(url: try AppBackup.recoveryURL(), name: "Before Last Restore") }
        catch { report(error, title: "Couldn’t Open Recovery Copy") }
    }

    private func loadBackup(url: URL, name: String) {
        isWorking = true
        Task { @MainActor in
            do {
                let snapshot = try await Task.detached(priority: .userInitiated) {
                    try AppBackup.read(from: url)
                }.value
                isWorking = false
                preview = BackupPreview(name: name, snapshot: snapshot)
            } catch {
                isWorking = false
                report(error, title: "Couldn’t Read Backup")
            }
        }
    }

    private func restoreIfRequested() {
        guard let snapshot = requestedRestore else { return }
        requestedRestore = nil
        do {
            // Refuse replacement if we cannot first retain a complete recovery copy.
            let current = try BackupStore.capture(context: modelContext, appearance: appearance,
                                                   currencyPreferences: CurrencyPreferences.decode(storedCurrencyPreferences))
            try AppBackup.encode(current).write(to: AppBackup.recoveryURL(), options: .atomic)
            try BackupStore.restore(snapshot, context: modelContext)
            // Preferences only change after the model save succeeds. Rebuild the
            // tab hierarchy to discard drafts and links to replaced model objects.
            appearance = AppAppearance(rawValue: snapshot.appearance) ?? .system
            if let preferences = snapshot.currencyPreferences {
                storedCurrencyPreferences = preferences.storageValue
            }
            restoreRevision = UUID().uuidString
            showRestoreNotice = true
        } catch { report(error, title: "Couldn’t Restore Backup") }
    }

    private func report(_ error: Error, title: String) {
        let cocoa = error as NSError
        if cocoa.domain == NSCocoaErrorDomain && cocoa.code == NSUserCancelledError { return }
        showAlert(title, error.localizedDescription)
    }

    private func showAlert(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

private struct BackupPreview: Identifiable {
    let id = UUID()
    let name: String
    let snapshot: AppBackup.Snapshot
}

private struct BackupPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let preview: BackupPreview
    let onRestore: () -> Void
    @State private var confirmingRestore = false

    private var snapshot: AppBackup.Snapshot { preview.snapshot }

    var body: some View {
        NavigationStack {
            Form {
                Section("Backup File") {
                    LabeledContent("File", value: preview.name)
                    LabeledContent("Created", value: snapshot.createdAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Appearance", value: AppAppearance(rawValue: snapshot.appearance)?.title ?? "System")
                    if let preferences = snapshot.currencyPreferences {
                        LabeledContent("Added Currencies", value: preferences.listedCodes.joined(separator: ", "))
                        LabeledContent("Enabled Currencies", value: preferences.enabledCodes.joined(separator: ", "))
                        LabeledContent("Default Currency", value: preferences.defaultCode)
                    } else {
                        LabeledContent("Currency Settings", value: "Not included; current settings kept")
                    }
                }
                Section("Contents") {
                    LabeledContent("Wallets", value: "\(snapshot.wallets.count)")
                    LabeledContent("Transactions", value: "\(snapshot.transactions.count)")
                    LabeledContent("Transfers", value: "\(snapshot.transfers.count)")
                    LabeledContent("Categories", value: "\(snapshot.categories.count)")
                    LabeledContent("Subcategories", value: "\(snapshot.subcategories.count)")
                    LabeledContent("Budgets", value: "\(snapshot.budgets.count)")
                    LabeledContent("Recurring Payments", value: "\(snapshot.recurringPayments.count)")
                }
                Section {
                    if snapshot.recordCount == 0 {
                        Text("This backup is empty. Restoring it removes all current data.")
                            .foregroundStyle(.red)
                    }
                    Button("Restore This Backup", role: .destructive) { confirmingRestore = true }
                        .accessibilityIdentifier("restoreAppBackup")
                } footer: {
                    Text("Restoring replaces all current data; it does not merge records. The current data is kept as the recovery copy before replacement.")
                }
            }
            .navigationTitle("Review Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Replace Current Data?", isPresented: $confirmingRestore) {
                Button("Cancel", role: .cancel) { }
                Button("Replace & Restore", role: .destructive, action: onRestore)
            } message: {
                Text("All current wallets, transactions, transfers, categories, budgets and recurring payments will be replaced with this backup. Your current data will be kept as the recovery copy.")
            }
        }
    }
}

nonisolated struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        data = contents
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
