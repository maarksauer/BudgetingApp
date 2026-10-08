import SwiftUI

nonisolated enum MoreRoute: Hashable {
    case budgets, categories, recurringPayments, currencies, appearance, export, backup
}

struct SettingsView: View {
    @Binding var path: [MoreRoute]
    @AppStorage(CurrencyPreferences.storageKey) private var storedCurrencyPreferences = CurrencyPreferences.defaultStorageValue
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("Organisation") {
                    NavigationLink(value: MoreRoute.budgets) {
                        Label("Budgets", systemImage: "chart.pie")
                    }
                    .accessibilityIdentifier("openBudgets")

                    NavigationLink(value: MoreRoute.categories) {
                        Label("Categories", systemImage: "square.grid.2x2")
                    }

                    NavigationLink(value: MoreRoute.recurringPayments) {
                        Label("Recurring Payments", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                    }
                    .accessibilityIdentifier("openRecurringPayments")

                    NavigationLink(value: MoreRoute.currencies) {
                        AdaptiveValueRow {
                            Label("Currencies", systemImage: "eurosign.circle")
                        } trailing: {
                            Text("\(CurrencyPreferences.decode(storedCurrencyPreferences).enabledCodes.count) enabled")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("openCurrenciesSettings")
                }

                Section("Preferences") {
                    NavigationLink(value: MoreRoute.appearance) {
                        AdaptiveValueRow {
                            Label("Appearance", systemImage: "circle.lefthalf.filled")
                        } trailing: {
                            Text(appearance.title).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("openAppearanceSettings")
                }

                Section("Data") {
                    NavigationLink(value: MoreRoute.export) {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("openExportData")

                    NavigationLink(value: MoreRoute.backup) {
                        Label("Backup & Restore", systemImage: "externaldrive")
                    }
                    .accessibilityIdentifier("openBackupRestore")
                }
            }
            .navigationTitle("More")
            .navigationDestination(for: MoreRoute.self) { route in
                switch route {
                case .budgets: BudgetsView(embedded: true)
                case .categories: CategoriesView()
                case .recurringPayments: RecurringPaymentsView()
                case .currencies: CurrenciesSettingsView()
                case .appearance: AppearanceSettingsView()
                case .export: ExportDataView()
                case .backup: BackupRestoreView()
                }
            }
        }
    }
}
