//
//  Meal.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/24/24.
//

import Foundation
import SwiftData

@Model
class Meal {
    var id: String = UUID().uuidString
    var title: String = ""
    var charm: String = "🍱"
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()

    var items: [MealItem]? = [MealItem]()
    var people: [MealPerson]? = [MealPerson]()

    init() {
        //
    }
    
    
}
