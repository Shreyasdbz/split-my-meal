import Foundation
import SwiftData

/// Persisted category raw values are stable across releases and determine category ordering.
enum MealItemCategory: String, Codable, CaseIterable {
    case Snack = "00_Snack"
    case Entree = "10_Entree"
    case Dessert = "20_Dessert"
    case Drink = "30_Drink"
}

/// An owned meal item. Price remains USD Double storage for migration compatibility; MealStore writes cent-normalized values.
/// consumerIds is the authoritative sharing assignment. MealAmounts divides its price equally and conserves remainder cents.
@Model
class MealItem {

    @Relationship(inverse: \Meal.items)
    var relatedMeal: Meal?

    var id: String = UUID().uuidString
    var name: String = ""
    var price: Double = 0.0
    var category: MealItemCategory = MealItemCategory.Snack
    var consumerIds: [String] = []
    
    init(relatedMeal: Meal?, category: MealItemCategory) {
        self.relatedMeal = relatedMeal
        self.category = category
    }
}
