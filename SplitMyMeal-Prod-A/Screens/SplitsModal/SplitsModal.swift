//
//  SplitsModal.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 5/6/24.
//

import SwiftUI

struct SplitsModal: View {
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var meal: Meal
    
    var body: some View {
        NavigationStack{
            ScrollView(.vertical) {
                VStack(spacing: 15){
                    totalsSection
                    DividerElement(removePadding: true)
                    splitsSection
                }
                .padding(.horizontal)
                .padding(.top, 15)
            }
            .navigationTitle("\(meal.charm) \(meal.title)")
            .background(colorScheme == .dark ? Color.black : Color.white)
            .toolbar{
                ToolbarItem(placement: .topBarLeading) {
                    Button("Dismiss"){
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var totalsSection: some View {
        HStack{
            VStack(alignment: .leading){
                Text("Totals")
                    .font(.title3)
                    .fontWeight(.medium)
                    .padding(.bottom, 5)
                VStack(spacing: 8) {
                    HStack{
                        Text("Subtotal")
                            .fontWeight(.regular)
                        Spacer()
                        Text("\(getMealTotalPreTax(meal: meal).formatted(.currency(code: "USD")))")
                            .fontWeight(.light)
                    }
                    HStack{
                        Text("Tip")
                            .fontWeight(.regular)
                        Spacer()
                        Text(getMealTaxText(meal: meal))
                            .fontWeight(.light)
                    }
                    HStack{
                        Text("Tax")
                            .fontWeight(.regular)
                        Spacer()
                        Text(getMealTipText(meal: meal))
                            .fontWeight(.light)
                    }
                    HStack{
                        Text("Grand total")
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(getMealTotal(meal: meal).formatted(.currency(code: "USD")))")
                            .fontWeight(.medium)
                    }
                }
                .font(.headline)
            }
            Spacer()
        }
    }
    
    private func splitsRowText(person: MealPerson) -> some View {
        return(
            HStack{
                Text("\(person.name)")
                if let items = getItemsForMealPerson(meal: meal, person: person){
                    ForEach(items.sorted(by: { itemA, itemB in
                        itemA.category.rawValue < itemB.category.rawValue
                    })){ item in
                        HStack(spacing: 4){
                            Circle()
                                .frame(width: 8, height: 8, alignment: .center)
                                .foregroundStyle(getColorByMealItemCategory(category: item.category))
                        }
                    }
                } 
                Spacer()
                Text("\(getSplitTotalForPerson(meal: meal, person: person).formatted(.currency(code: "USD")))")
            }
                .padding()
        )
    }
    
    private func splitsRow(person: MealPerson) -> some View {
        return(
            splitsRowText(person: person)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .foregroundStyle(colorScheme == .light ? .white : Color.init(uiColor: .systemGray6))
                        .overlay(alignment: .center, content: {
                            splitsRowText(person: person)
                        })
                        .shadow(color: .primary.opacity(0.075), radius: 6, x: 0, y: 0)
                }
        )
    }
    
    private var splitsSection: some View {
        VStack{
            HStack{
                Text("Splits")
                    .font(.title3)
                    .fontWeight(.medium)
                    .padding(.bottom, 5)
                Spacer()
            }
            VStack{
                if let mealPeople = meal.people {
                    ForEach(mealPeople.sorted(by: { personA, personB in
                        personA.name < personB.name
                    })){ person in
                        splitsRow(person: person)
                    }
                }
            }
        }
    }
}

//#Preview {
//    SplitsModal()
//}
