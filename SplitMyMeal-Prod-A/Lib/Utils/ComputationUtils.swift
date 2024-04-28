//
//  ComputationUtils.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/28/24.
//

import Foundation

/**
 Returns the total including Tip and Tax in Double format.
 Returns nil if no items added
 */
func getMealTotal(meal: Meal) -> Double? {
    guard let mealItems = meal.items else { return nil }
    if (mealItems.isEmpty) { return nil }
    
    var total: Double = 0.0
    // Add up items
    mealItems.forEach { total += $0.price }
    // Add tax
    if let taxAmount = meal.taxAmount {
        // Use amount to add to total
        total += taxAmount
    } else {
        if let taxPercentage = meal.taxPercentage {
            // Use percentage of total to add tax
            total += (total * (taxPercentage / 100))
        }
    }
    // Add tip
    if let tipAmount = meal.tipAmount {
        // Use amount to add to total
        total += tipAmount
    } else {
        if let tipPercentage = meal.tipPercentage {
            // Use percentage of total to add tip
            total += (total * (tipPercentage / 100))
        }
    }
    return total
}
