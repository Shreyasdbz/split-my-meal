//
//  MealRowView.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/24/24.
//

import SwiftUI

struct MealRowView: View {

    @Environment(\.colorScheme) var colorScheme

    @State var meal: Meal
    
    var body: some View {
        mealRowInList
    }
    
    private var mealRowInList: some View {
        HStack(alignment: .center){
            // Charm
            Text("\(meal.charm)")
                .font(.title2)
                .padding(.trailing)
            // Details Text
            VStack(alignment: .leading, spacing: 6){
                Text("\(meal.title)")
                    .font(.title3)
                    .fontWeight(.medium)
                Text("\(getPeopleInMealString(meal: meal))")
                    .foregroundStyle(Color.init(uiColor: .systemGray))
                if let mealTotal = getMealTotal(meal: meal) {
                    Text("\(mealTotal.formatted(.currency(code: "USD")))")
                } else {
                    Text("No items added yet")
                }
            }
            Spacer()
        }
    }
}

//#Preview {
//    MealRowView(meal: Meal())
//}
