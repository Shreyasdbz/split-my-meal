//
//  ComputationUtils.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/28/24.
//

import Foundation


/**
 Returns the total before tax and tip in Double format.
 Returns nil if no items added
 */
func getMealTotalPreTax(meal: Meal) -> Double {
    guard let mealItems = meal.items else { return 0 }
    if (mealItems.isEmpty) { return 0 }
    var total: Double = 0.0
    // Add up items
    mealItems.forEach { total += $0.price }
    return total
}

/**
 Returns the total including tax but before tip in Double format.
 Returns nil if no items added
 */
func getMealTotalPreTip(meal: Meal) -> Double {
    guard let mealItems = meal.items else { return 0 }
    if (mealItems.isEmpty) { return 0 }
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
    return total
}



/**
 Returns the total including Tip and Tax in Double format.
 Returns nil if no items added
 */
func getMealTotal(meal: Meal) -> Double {
    guard let mealItems = meal.items else { return 0 }
    if (mealItems.isEmpty) { return 0 }
    
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


func getMealTaxText(meal: Meal) -> String {
    
    if let taxPercentage = meal.taxPercentage {
        // calculate amount
        let total = getMealTotalPreTax(meal: meal)
        let amount = taxPercentage * (1/100) * total
        let amountFormatted = Double(NumberFormatter.twoDigitFormat.string(from: amount)) ?? 0.0
        let newPercent = taxPercentage/100
        let newPercentFormatted = Double(NumberFormatter.twoDigitFormat.string(from: newPercent)) ?? 0.0
        return "\(amountFormatted.formatted(.currency(code: "USD"))) (\(newPercentFormatted.formatted(.percent)))"
        
    }
    
    if let taxAmount = meal.taxAmount {
        let taxAmountFormatted = Double(NumberFormatter.twoDigitFormat.string(from: taxAmount)) ?? 0.0
        // calculate percentage
        let total = getMealTotalPreTax(meal: meal)
        let percentage = (taxAmount/total)
        let percentageFormatted = Double(NumberFormatter.twoDigitFormat.string(from: percentage)) ?? 0.0
        return "\(taxAmountFormatted.formatted(.currency(code: "USD"))) (\(percentageFormatted.formatted(.percent)))"
        
    }
    
    return ""
}


func getMealTipText(meal: Meal) -> String {
    
    if let tipPercentage = meal.tipPercentage {
        // calculate amount
        let total = getMealTotalPreTip(meal: meal)
        let amount = tipPercentage * (1/100) * total
        let amountFormatted = Double(NumberFormatter.twoDigitFormat.string(from: amount)) ?? 0.0
        let newPercent = tipPercentage/100
        let newPercentFormatted = Double(NumberFormatter.twoDigitFormat.string(from: newPercent)) ?? 0.0
        return "\(amountFormatted.formatted(.currency(code: "USD"))) (\(newPercentFormatted.formatted(.percent)))"
        
    }
    
    if let tipAmount = meal.tipAmount {
        let tipAmountFormatted = Double(NumberFormatter.twoDigitFormat.string(from: tipAmount)) ?? 0.0
        // calculate percentage
        let total = getMealTotalPreTip(meal: meal)
        let percentage = (tipAmount/total)
        let percentageFormatted = Double(NumberFormatter.twoDigitFormat.string(from: percentage)) ?? 0.0
        return "\(tipAmountFormatted.formatted(.currency(code: "USD"))) (\(percentageFormatted.formatted(.percent)))"
    }
    
    return ""
}


/**
 Computes the total amount a person owes
 What a person owes:
 - Their split of each meal item
 - Tax % of their food total
 - Proportionate split of the tip
 */
func getSplitTotalForPerson(meal: Meal, person: MealPerson) -> Double {
    var splitTotal:Double = 0
    
    // Get meal items split
    if let items = meal.items {
        for item in items {
            if(item.consumerIds.contains(person.id)){
                splitTotal += item.price / Double(item.consumerIds.count)
            }
        }
    }
    
    // Add tax on it
    if let taxPercentage = meal.taxPercentage {
        splitTotal += splitTotal * (taxPercentage/100)
    } else if let taxAmount = meal.taxAmount {
        // get amount for
        let computedPercentage = taxAmount / getMealTotalPreTax(meal: meal)
        splitTotal += splitTotal * computedPercentage
    }
    
    // Add tip
    if (splitTotal > 0) {
        let mealTotal = getMealTotalPreTip(meal: meal)
        let percentShareOfTotal = splitTotal / mealTotal
        if let tipPercentage = meal.tipPercentage {
            let computedAmount = mealTotal * (tipPercentage/100)
            splitTotal += percentShareOfTotal * computedAmount
        } else if let tipAmount = meal.tipAmount {
            splitTotal += percentShareOfTotal * tipAmount
        }
    }
    
    return splitTotal
}
