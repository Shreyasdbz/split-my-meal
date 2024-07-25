//
//  HomeScreen.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/24/24.
//

import SwiftUI
import SwiftData

struct HomeScreen: View {

    @Environment (\.modelContext) var modelContext

    @State private var path = NavigationPath()
    @State private var searchText: String = ""
    @State private var sortOrder = [SortDescriptor(\Meal.modifiedAt, order: .reverse)]

    @State private var mealToEdit: Meal? = nil

    var body: some View {
        NavigationStack(path: $path){
            MealsListView(
                searchString: searchText,
                sortOrder: sortOrder
            )
                .searchable(text: $searchText, prompt: "Look for meals")
                .navigationTitle("Split my Meal")
                .navigationDestination(for: Meal.self) { meal in
                    MealScreen(navigationPath: $path, meal: meal)
                }
                .toolbar{
//                    ToolbarItem(placement: .topBarTrailing) {
//                        Menu("Sort", systemImage: "arrow.up.arrow.down"){
//                            Picker("Sort", selection: $sortOrder){
//                                Text("Title (A-Z)")
//                                    .tag([SortDescriptor(\Meal.title)])
//                                Text("Title (Z-A)")
//                                    .tag([SortDescriptor(\Meal.title, order: .reverse)])
//                                Text("Created (Newest)")
//                                    .tag([SortDescriptor(\Meal.createdAt, order: .reverse)])
//                                Text("Created (Oldest)")
//                                    .tag([SortDescriptor(\Meal.modifiedAt)])
//                                Text("Modified (Newest)")
//                                    .tag([SortDescriptor(\Meal.modifiedAt, order: .reverse)])
//                                Text("Modified (Oldest)")
//                                    .tag([SortDescriptor(\Meal.createdAt)])
//                            }
//                        }
//                    }
                    ToolbarItem(placement: .bottomBar) {
                        Button("Add new"){
                            mealToEdit = Meal()
                        }
                    }
                }
                .sheet(item: $mealToEdit) {
                    // On dismiss:
                    mealToEdit = nil
                } content: { meal in
                    EditMealModal(navigationPath: $path,  meal: mealToEdit ?? Meal())
                }
        }
    }
}


//
//#Preview {
//    HomeScreen()
//}
