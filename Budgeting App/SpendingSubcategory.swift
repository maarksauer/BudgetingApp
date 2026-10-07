import Foundation
import SwiftData

@Model
final class SpendingSubcategory {

    var name: String
    var createdAt: Date

    var category: SpendingCategory?

    init(
        name: String,
        category: SpendingCategory? = nil
    ) {
        self.name = name
        self.category = category
        self.createdAt = Date()
    }
}
