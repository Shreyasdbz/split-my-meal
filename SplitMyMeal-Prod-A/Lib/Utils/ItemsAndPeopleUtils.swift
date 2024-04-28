//
//  itemsAndPeopleUtils.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/25/24.
//

import Foundation
import SwiftUI

/**
 Get the string to show in Home screen meal row
 */
func getPeopleInMealString(meal: Meal) -> String {
    let STRING_NO_PEOPLE = "No people added yet"
    guard let mealPeople = meal.people else { return STRING_NO_PEOPLE }
    if(mealPeople.isEmpty) { return STRING_NO_PEOPLE }
    
    var names: [String] = []
    mealPeople
        .sorted(by: { personA, personB in
            personA.name <  personB.name
        }) 
        .forEach { person in
            var nameString = person.name
            if(nameString.last == " "){
                nameString = String(nameString.dropLast())
            }
            names.append(nameString)
        }
    
    // Case: 1 Person -- Return 'name'
    if(names.count == 1){
        return "\(names[0])"
    }
    // Case: 2 People -- Return 'name' & 'name'
    else if(names.count == 2){
        return "\(names[0]) & \(names[1])"
    }
    // Case: 3 People -- Return 'name', 'name' & 'name'
    else if(names.count == 3){
        return "\(names[0]), \(names[1]) & \(names[2])"
    }
    // Case: + People -- Return 'name', 'name' & '(n-2) others'
    else {
        return "\(names[0]), \(names[1]) & \(names.count-2) others"
    }
}

/**
 Returns all the meal persons for a given meal, returns nil if empty
 */
func getAllMealPersonsForMeal(meal: Meal) -> [MealPerson]? {
    guard let people = meal.people else { return nil }
    if(people.isEmpty) { return nil }
    else { return people }
}

/**
 Returns the person name based on the consumer or person id that's passed in for a meal
 */
func getPersonNameById(meal: Meal, personId: String) -> String {
    var personName = "Name not found"
    if let mealPeople = meal.people {
        if(!mealPeople.isEmpty){
            mealPeople.forEach { person in
                if(person.id == personId) {
                    personName = person.name
                }
            }
        }
    }
    return personName
}

/**
 For a given meal, returns a list of the meal persons that belong to the passed in item. Returns nil if empty
 */
func getPeopleForMealItem(meal: Meal, item: MealItem) -> [MealPerson]? {
    guard let mealPersons = meal.people else { return nil }
    if(mealPersons.isEmpty) { return nil }
    var people: [MealPerson] = []
    mealPersons.forEach { person in
        if(person.itemIds.contains(item.id)) { people.append(person) }
    }
    if(people.isEmpty) { return nil }
    return people
}

/**
 Returns all the meal items for a given meal, returns nil if empty
 */
func getAllMealItemsForMeal(meal: Meal) -> [MealItem]?{
    guard let items = meal.items else { return nil }
    if(items.isEmpty) { return nil }
    else { return items }
}

/**
 For a given meal, returns a list of the mealsItems that are of the passed in category. Returns nil if empty
 */
func getItemsForCategory(meal: Meal, category: MealItemCategory) -> [MealItem]? {
    guard let mealItems = meal.items else { return nil }
    if(mealItems.isEmpty) { return nil }
    var items: [MealItem] = []
    mealItems.forEach { item in
        if(item.category == category) { items.append(item) }
    }
    if(items.isEmpty) { return nil }
    return items
}

/**
 For a given meal, returns a list of the mealItems that belong to the passed in person. Returns nil if empty
 */
func getItemsForMealPerson(meal: Meal, person: MealPerson) -> [MealItem]? {
    guard let mealItems = meal.items else { return nil }
    if(mealItems.isEmpty) { return nil }
    var items: [MealItem] = []
    mealItems.forEach { item in
        if(item.consumerIds.contains(person.id)) { items.append(item) }
    }
    if(items.isEmpty) { return nil }
    return items
}

/**
 Returns the first letter capitalized name of the Meal Item Category
 */
func getFormattedNameForMealItemCategory(_ category: MealItemCategory) -> String{
    switch category {
    case MealItemCategory.Snack:
        return "Snack"
    case MealItemCategory.Entree:
        return "Entree"
    case MealItemCategory.Dessert:
        return "Dessert"
    case MealItemCategory.Drink:
        return "Drink"
    }
}

/**
 Returns the Color of the Meal Item Category
 */
func getColorByMealItemCategory(category: MealItemCategory) -> Color {
    switch category {
    case MealItemCategory.Snack:
        return Color.mealItemSnack
    case MealItemCategory.Entree:
        return Color.mealItemEntree
    case MealItemCategory.Dessert:
        return Color.mealItemDessert
    case MealItemCategory.Drink:
        return Color.mealItemDrink
    }
}
