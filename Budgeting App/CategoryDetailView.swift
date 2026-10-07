import SwiftUI
import SwiftData

struct CategoryDetailView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query
    private var transactions: [ExpenseTransaction]

    let category: SpendingCategory

    @State private var showingAddSubcategory = false
    @State private var newSubcategoryName = ""

    @State private var showingEditCategory = false

    @State private var showingRenameSubcategory = false
    @State private var subcategoryBeingEdited: SpendingSubcategory?
    @State private var editedSubcategoryName = ""

    @State private var showingDeleteCategoryConfirmation = false

    var body: some View {
        List {

            Section {
                HStack(spacing: 14) {

                    Image(systemName: category.icon)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(
                            colorFromName(category.colorName)
                        )
                        .clipShape(
                            RoundedRectangle(cornerRadius: 14)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.name)
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text(
                            "\(category.subcategories.count) subcategories"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Subcategories") {

                if category.subcategories.isEmpty {

                    Text("No subcategories yet")
                        .foregroundStyle(.secondary)

                } else {

                    ForEach(sortedSubcategories) { subcategory in

                        HStack {

                            Image(systemName: "circle.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(.secondary)

                            Text(subcategory.name)

                            Spacer()

                            Button {
                                startRenaming(subcategory)
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .onDelete(perform: deleteSubcategories)
                }

                Button {
                    showingAddSubcategory = true
                } label: {
                    Label(
                        "Add Subcategory",
                        systemImage: "plus.circle.fill"
                    )
                }
            }

            Section {
                Button(
                    "Delete Category",
                    role: .destructive
                ) {
                    showingDeleteCategoryConfirmation = true
                }
            } footer: {
                Text(
                    "Deleting this category will not delete existing expenses."
                )
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)

        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditCategory = true
                }
            }
        }

        .sheet(isPresented: $showingEditCategory) {
            EditCategoryView(category: category)
        }

        .alert(
            "New Subcategory",
            isPresented: $showingAddSubcategory
        ) {
            TextField(
                "Subcategory name",
                text: $newSubcategoryName
            )

            Button("Cancel", role: .cancel) {
                newSubcategoryName = ""
            }

            Button("Add") {
                addSubcategory()
            }

        } message: {
            Text(
                "Add a subcategory to \(category.name)."
            )
        }

        .alert(
            "Rename Subcategory",
            isPresented: $showingRenameSubcategory
        ) {
            TextField(
                "Subcategory name",
                text: $editedSubcategoryName
            )

            Button("Cancel", role: .cancel) {
                subcategoryBeingEdited = nil
                editedSubcategoryName = ""
            }

            Button("Save") {
                renameSubcategory()
            }

        } message: {
            Text("Enter a new name.")
        }

        .confirmationDialog(
            "Delete \(category.name)?",
            isPresented: $showingDeleteCategoryConfirmation,
            titleVisibility: .visible
        ) {

            Button(
                "Delete Category",
                role: .destructive
            ) {
                deleteCategory()
            }

            Button("Cancel", role: .cancel) { }

        } message: {
            Text(
                "Existing transactions will remain, but their category will be removed."
            )
        }
    }

    private var sortedSubcategories: [SpendingSubcategory] {
        category.subcategories.sorted {
            $0.name.localizedCaseInsensitiveCompare(
                $1.name
            ) == .orderedAscending
        }
    }

    private func addSubcategory() {

        let cleanedName = newSubcategoryName
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanedName.isEmpty else {
            return
        }

        let subcategory = SpendingSubcategory(
            name: cleanedName,
            category: category
        )

        category.subcategories.append(subcategory)

        modelContext.insert(subcategory)

        newSubcategoryName = ""
    }

    private func startRenaming(
        _ subcategory: SpendingSubcategory
    ) {

        subcategoryBeingEdited = subcategory
        editedSubcategoryName = subcategory.name
        showingRenameSubcategory = true
    }

    private func renameSubcategory() {

        let cleanedName = editedSubcategoryName
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard
            !cleanedName.isEmpty,
            let subcategory = subcategoryBeingEdited
        else {
            return
        }

        subcategory.name = cleanedName

        subcategoryBeingEdited = nil
        editedSubcategoryName = ""
    }

    private func deleteSubcategories(
        at offsets: IndexSet
    ) {

        let items = sortedSubcategories

        for index in offsets {

            let subcategory = items[index]

            removeSubcategoryFromTransactions(
                subcategory
            )

            category.subcategories.removeAll {
                $0.persistentModelID ==
                subcategory.persistentModelID
            }

            modelContext.delete(subcategory)
        }
    }

    private func removeSubcategoryFromTransactions(
        _ subcategory: SpendingSubcategory
    ) {

        for transaction in transactions {

            if transaction.subcategory?.persistentModelID ==
                subcategory.persistentModelID {

                transaction.subcategory = nil
            }
        }
    }

    private func deleteCategory() {

        for transaction in transactions {

            if transaction.category?.persistentModelID ==
                category.persistentModelID {

                transaction.category = nil
                transaction.subcategory = nil
            }
        }

        let subcategoriesToDelete =
            Array(category.subcategories)

        category.subcategories.removeAll()

        for subcategory in subcategoriesToDelete {
            modelContext.delete(subcategory)
        }

        modelContext.delete(category)

        dismiss()
    }

    private func colorFromName(
        _ name: String
    ) -> Color {

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
