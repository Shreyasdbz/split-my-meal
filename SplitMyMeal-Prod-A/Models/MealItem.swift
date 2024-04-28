//
//  MealItem.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/24/24.
//

import Foundation
import SwiftData

/**
 Different cateogries that a meal item can belong to
 */
enum MealItemCategory: String, Codable, CaseIterable {
    case Snack = "00_Snack"
    case Entree = "10_Entree"
    case Dessert = "20_Dessert"
    case Drink = "30_Drink"
    
    var id: Self { self }
}

/**
 An item within a meal that represents a single item that was consumed
 */
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
