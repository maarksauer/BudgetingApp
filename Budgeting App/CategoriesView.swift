import SwiftUI
import SwiftData

struct CategoriesView: View {

    @Query(sort: \SpendingCategory.name)
    private var categories: [SpendingCategory]

    @State private var showingCreateCategory = false

    var body: some View {
        List {
            ForEach(categories) { category in

                NavigationLink {
                    CategoryDetailView(category: category)
                } label: {
                    HStack(spacing: 14) {

                        Image(systemName: category.icon)
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(
                                colorFromName(category.colorName)
                            )
                            .clipShape(
                                RoundedRectangle(cornerRadius: 12)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.name)
                                .font(.headline)

                            Text(
                                "\(category.subcategories.count) subcategories"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateCategory = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateCategory) {
            CreateCategoryView()
        }
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
