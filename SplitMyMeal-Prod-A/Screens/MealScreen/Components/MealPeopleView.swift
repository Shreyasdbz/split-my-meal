//
//  MealPeopleView.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/25/24.
//

import SwiftUI

struct MealPeopleView: View {
    
    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) var colorScheme
    
    let meal: Meal
    var onNewClick: () -> ()
    var onEditClick: (_ person: MealPerson) -> ()
    
    var body: some View {
        VStack{
            addPersonButton
            if let mealPeople = meal.people {
                if(mealPeople.isEmpty){
                    emptyPeopleText
                } else {
                    VStack(spacing: 15){
                        ForEach(mealPeople.sorted(by: { personA, personB in
                            personA.name < personB.name
                        })){ person in
                            mealPersonRow(person: person)
                        }
                    }
                }
            } else {
                emptyPeopleText
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 100)
    }
    
    private var addPersonButton: some View {
        Button {
            onNewClick()
        } label: {
            HStack{
                Image(systemName: "plus")
                Text("Add person")
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .overlay {
                RoundedRectangle(cornerRadius: 100, style: .continuous)
                    .stroke(.primary, lineWidth: 1)
            }
        }
        .padding(.vertical, 20)
    }
    
    private var emptyPeopleText: some View {
        VStack{
            Text("Use the + Add person button")
            Text("to add a new person")
        }
        .foregroundStyle(.secondary)
        .padding(.vertical, 30)
    }
    
    private func itemBubbleOpenPill(item: MealItem) -> some View{
        Text("\(item.name)")
            .font(.footnote)
            .foregroundStyle(getColorByMealItemCategory(category: item.category))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .overlay {
                RoundedRectangle(cornerRadius: 100, style: .continuous)
                    .stroke(
                        getColorByMealItemCategory(category: item.category),
                        lineWidth: 0.75
                    )
            }
    }
    private func itemBubble(item: MealItem) -> some View{
        Text("\(item.name)")
            .font(.subheadline)
            .fontWeight(.regular)
            .foregroundStyle(.primary)
            .colorInvert()
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(getColorByMealItemCategory(category: item.category).opacity(0.75))
            .overlay {
                RoundedRectangle(cornerRadius: 100, style: .continuous)
                    .stroke(
                        getColorByMealItemCategory(category: item.category).opacity(0.75),
                        lineWidth: 0.75
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 100))
    }
    
    private func mealPersonRowTextPortion(person: MealPerson) -> some View {
        VStack{
            HStack{
                Text("\(person.name)")
                    .font(.headline)
                    .fontWeight(.regular)
                    .foregroundStyle(.primary)
                Spacer()
            }
            if let items = getItemsForMealPerson(meal: meal, person: person) {
                FlexStack{
                    ForEach(items.sorted(by: { itemA, itemB in
                        itemA.category.rawValue < itemB.category.rawValue
                    })) { item in
                        itemBubble(item: item)
                    }
                }
                .padding(.top, 1)
            } else {
                VStack{
                    Text("\(person.name) hasn't had anything")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 15)
            }
        }
        .padding()
    }
    
    private func mealPersonRow(person: MealPerson) -> some View {
        Button {
            onEditClick(person)
        } label: {
            mealPersonRowTextPortion(person: person)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .foregroundStyle(colorScheme == .light ? .white : Color.init(uiColor: .systemGray6))
                        .overlay(alignment: .center, content: {
                            mealPersonRowTextPortion(person: person)
                        })
                        .shadow(color: .primary.opacity(0.075), radius: 6, x: 0, y: 0)
                }
        }
        .contextMenu {
            Button("Edit", systemImage: "pencil") {
                onEditClick(person)
            }
            Button("Delete", systemImage: "trash", role: .destructive){
                // Clean up personId from meal's items
                if let mealItems = meal.items {
                    mealItems.forEach { item in
                        item.consumerIds = item.consumerIds.filter({ consumerId in
                            consumerId != person.id
                        })
                    }
                }
                modelContext.delete(person)
            }
        }
    }
}


//#Preview {
//    MealPeopleView()
//}
