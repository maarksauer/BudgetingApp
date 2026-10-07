import SwiftUI
import SwiftData

struct CreateCategoryView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var selectedIcon = "square.grid.2x2.fill"
    @State private var selectedColor = "blue"

    let icons = [
        "fork.knife",
        "car.fill",
        "house.fill",
        "bag.fill",
        "doc.text.fill",
        "heart.fill",
        "cross.case.fill",
        "gamecontroller.fill",
        "airplane",
        "gift.fill",
        "graduationcap.fill",
        "pawprint.fill",
        "dumbbell.fill",
        "cup.and.saucer.fill",
        "cart.fill",
        "phone.fill"
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

                Section("Category") {
                    TextField(
                        "Category name",
                        text: $name
                    )
                }

                Section("Preview") {
                    HStack(spacing: 14) {

                        Image(systemName: selectedIcon)
                            .foregroundStyle(.white)
                            .frame(width: 46, height: 46)
                            .background(
                                colorFromName(selectedColor)
                            )
                            .clipShape(
                                RoundedRectangle(cornerRadius: 12)
                            )

                        Text(
                            name.isEmpty
                            ? "Category"
                            : name
                        )
                        .font(.headline)
                    }
                }

                Section("Icon") {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 52))
                        ],
                        spacing: 12
                    ) {
                        ForEach(icons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .frame(width: 48, height: 48)
                                    .background(
                                        selectedIcon == icon
                                        ? Color.accentColor.opacity(0.18)
                                        : Color.secondary.opacity(0.08)
                                    )
                                    .clipShape(
                                        RoundedRectangle(cornerRadius: 12)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Colour") {
                    HStack(spacing: 14) {
                        ForEach(colors, id: \.self) { colorName in
                            Button {
                                selectedColor = colorName
                            } label: {
                                Circle()
                                    .fill(
                                        colorFromName(colorName)
                                    )
                                    .frame(width: 34, height: 34)
                                    .overlay {
                                        if selectedColor == colorName {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    Button {
                        createCategory()
                    } label: {
                        Text("Create Category")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(
                        name.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                    )
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func createCategory() {

        let category = SpendingCategory(
            name: name.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            icon: selectedIcon,
            colorName: selectedColor
        )

        modelContext.insert(category)

        dismiss()
    }

    private func colorFromName(_ name: String) -> Color {
        switch name {
        case "blue":
            return .blue
        case "green":
            return .green
        case "orange":
            return .orange
        case "purple":
            return .purple
        case "red":
            return .red
        case "pink":
            return .pink
        case "teal":
            return .teal
        case "gray":
            return .gray
        default:
            return .blue
        }
    }
}
