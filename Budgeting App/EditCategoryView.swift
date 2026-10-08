import SwiftUI

struct EditCategoryView: View {

    @Environment(\.dismiss) private var dismiss

    let category: SpendingCategory

    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedColor: String

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

    init(category: SpendingCategory) {
        self.category = category

        _name = State(initialValue: category.name)
        _selectedIcon = State(initialValue: category.icon)
        _selectedColor = State(initialValue: category.colorName)
    }

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
                            .foregroundStyle(colorFromName(selectedColor))
                            .frame(width: 46, height: 46)
                            .background(
                                colorFromName(selectedColor).opacity(0.14)
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
                                    .font(.system(size: 24))
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
                            .accessibilityLabel(FormPalette.categoryIconTitle(icon))
                            .accessibilityAddTraits(selectedIcon == icon ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Colour") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 48))], spacing: 12) {
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
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(colorName.capitalized)
                            .accessibilityAddTraits(selectedColor == colorName ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(
                        name.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                    )
                }
            }
        }
    }

    private func saveChanges() {

        category.name = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        category.icon = selectedIcon
        category.colorName = selectedColor

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
