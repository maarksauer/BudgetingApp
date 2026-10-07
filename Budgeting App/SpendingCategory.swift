import Foundation
import SwiftData

@Model
final class SpendingCategory {

    var name: String
    var icon: String
    var colorName: String
    var createdAt: Date

    var subcategories: [SpendingSubcategory] = []

    init(
        name: String,
        icon: String,
        colorName: String
    ) {
        self.name = name
        self.icon = icon
        self.colorName = colorName
        self.createdAt = Date()
    }
}
