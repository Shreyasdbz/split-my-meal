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
                    .fontWeight(.semibold)
                Text("Kendrick, Natalie & 3 others")
                    .foregroundStyle(Color.init(uiColor: .systemGray))
                Text("$238.49")
            }
            Spacer()
        }
    }

    private var mealRowCustom: some View {
        HStack(alignment: .center){
            // Charm
            Text("\(meal.charm)")
                .font(.largeTitle)
                .padding(.trailing)
            // Details Text
            VStack(alignment: .leading){
                Text("\(meal.title)")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Kendrick, Natalie & 3 others")
                    .foregroundStyle(Color.init(uiColor: .systemGray))
                Text("$238.49")
            }
            Spacer()
        }
        .padding()
        .background(colorScheme == .light ? Color.white : Color.init(uiColor: .systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(height: 120)
        .shadow(color: .black.opacity(0.10), radius: 15, x: 2, y: 2)
    }
}

//#Preview {
//    MealRowView(meal: Meal())
//}
