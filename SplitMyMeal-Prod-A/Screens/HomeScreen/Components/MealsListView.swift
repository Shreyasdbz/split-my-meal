//
//  MealsListView.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/24/24.
//

import SwiftUI
import SwiftData

struct MealsListView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Query private var meals: [Meal]

    init(
        searchString: String,
        sortOrder: [SortDescriptor<Meal>] = []
    ){
//        _meals = Query(
//            filter: #Predicate { meal in
//                if searchString.isEmpty{
//                    true
//                } else {
//                    meal.title.localizedStandardContains(searchString)
//                }
//            },
//            sort: sortOrder
//        )
        
        _meals = Query(
            filter: #Predicate <Meal> {
                if(searchString.isEmpty) { true }
                else {
                    $0.title.localizedStandardContains(searchString)
//                    || ($0.items.flatMap {
//                        $0.contains { $0.name.localizedStandardContains(searchString) }
//                    } != nil)
//                    || ($0.people.flatMap {
//                        $0.contains { $0.name.localizedStandardContains(searchString) }
//                    } != nil)
                }
            }
        )
    }
    
    var body: some View {
        if(meals.isEmpty){
            EmptyAreaText(emptyTextFor: .Meals)
        } else {
            List {
                ForEach(meals) { meal in
                    NavigationLink(value: meal) {
                        MealRowView(meal: meal)
                    }
                }
                .onDelete(perform: onDelete)
            }
        }
    }
    
    private func onDelete(at offsets: IndexSet){
        for offset in offsets {
            let mealToDelete = meals[offset]
            modelContext.delete(mealToDelete)
        }

    }
}

//#Preview {
//    MealsListView()
//}
