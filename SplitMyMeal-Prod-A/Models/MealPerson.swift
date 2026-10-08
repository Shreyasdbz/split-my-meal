import Foundation
import SwiftData

/// A person belongs to one meal. itemIds is the legacy reverse index, derived from item consumerIds by MealStore.
@Model
class MealPerson {

    @Relationship(inverse: \Meal.people)
    var relatedMeal: Meal?
    
    var id: String = UUID().uuidString
    var name: String = ""
    var itemIds: [String] = []

    init(relatedMeal: Meal?) {
        self.relatedMeal = relatedMeal
    }
}
