import Foundation
import SwiftData

/// A saved meal owns its items, people, optional restaurant, and receipt. Stored names and types retain 2024 compatibility.
/// Amount and percentage charge fields are mutually exclusive for new writes; calculations favor fixed amounts in older records.
@Model
class Meal {
    var id: String = UUID().uuidString
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()

    var title: String = ""
    var charm: String = "🍱"
    var taxPercentage: Double?
    var taxAmount: Double?
    var tipPercentage: Double?
    var tipAmount: Double?

    var items: [MealItem]? = [MealItem]()
    var people: [MealPerson]? = [MealPerson]()

    var restaurantDetails: RestaurantDetails?

    @Attribute(.externalStorage) var receiptPhoto: Data?
    
    init() {}
}
