//
//  SplitMyMeal_Prod_AApp.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/24/24.
//

import SwiftUI
import SwiftData

@main
struct SplitMyMeal_Prod_AApp: App {
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Meal.self,
            MealItem.self,
            MealPerson.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create Model Container \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            HomeScreen()
        }
        .modelContainer(sharedModelContainer)
    }
}
