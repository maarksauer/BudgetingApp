import SwiftUI

struct SettingsView: View {
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system

    var body: some View {

        NavigationStack {

            List {

                Section("Organisation") {

                    NavigationLink {

                        CategoriesView()

                    } label: {

                        Label(
                            "Categories",
                            systemImage:
                                "square.grid.2x2"
                        )
                    }

                    NavigationLink {

                        RecurringPaymentsView()

                    } label: {

                        Label(
                            "Recurring Payments",
                            systemImage:
                                "arrow.trianglehead.2.clockwise.rotate.90"
                        )
                    }

                    Label(
                        "Currencies",
                        systemImage:
                            "eurosign.circle"
                    )
                }

                Section("Preferences") {

                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        HStack {
                            Label("Appearance", systemImage: "circle.lefthalf.filled")
                            Spacer()
                            Text(appearance.title).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("openAppearanceSettings")

                    Label(
                        "General",
                        systemImage:
                            "slider.horizontal.3"
                    )
                }

                Section("Data") {

                    NavigationLink {
                        ExportDataView()
                    } label: {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("openExportData")
                }
            }

            .navigationTitle(
                "More"
            )
        }
    }
}
