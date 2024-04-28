//
//  MealPerson.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/24/24.
//

import Foundation
import SwiftData

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
