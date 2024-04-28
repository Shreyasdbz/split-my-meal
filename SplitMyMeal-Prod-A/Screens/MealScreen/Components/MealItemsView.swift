//
//  MealItemsView.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/25/24.
//

import SwiftUI

struct MealItemsView: View {
    
    var meal: Meal
    var onNewClick: (_ category: MealItemCategory) -> ()
    var onEditClick: (_ item: MealItem) -> ()
    
    var body: some View {
        VStack{
            MealItemsRow(
                meal: meal,
                category: .Snack,
                onNewClick: onNewClick,
                onEditClick: onEditClick
            )
            MealItemsRow(
                meal: meal,
                category: .Entree,
                onNewClick: onNewClick,
                onEditClick: onEditClick
            )
            MealItemsRow(
                meal: meal,
                category: .Dessert,
                onNewClick: onNewClick,
                onEditClick: onEditClick
            )
            MealItemsRow(
                meal: meal,
                category: .Drink,
                onNewClick: onNewClick,
                onEditClick: onEditClick
            )
        }
        .padding(.top, 15)
        .padding(.bottom, 100)
    }
}

//#Preview {
//    MealItemsView()
//}
