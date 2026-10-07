import SwiftUI

struct SettingsView: View {

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

                    Label(
                        "Appearance",
                        systemImage:
                            "circle.lefthalf.filled"
                    )

                    Label(
                        "General",
                        systemImage:
                            "slider.horizontal.3"
                    )
                }

                Section("Data") {

                    Label(
                        "Export Data",
                        systemImage:
                            "square.and.arrow.up"
                    )
                }
            }

            .navigationTitle(
                "More"
            )
        }
    }
}
