//
//  MealItemsRow.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/25/24.
//

import SwiftUI

struct MealItemsRow: View {
    
    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) var colorScheme

    var meal: Meal
    var category: MealItemCategory

    var onNewClick: (_ category: MealItemCategory) -> ()
    var onEditClick: (_ item: MealItem) -> ()
    
    
    var body: some View {
        VStack(spacing: 0){
            rowHeader
            
            if let items = getItemsForCategory(meal: meal, category: category) {
                ScrollView(.horizontal){
                    HStack(alignment: .top, spacing: 15){
                        emptyMealItemCard
                        ForEach(items.sorted(by: { itemA, itemB in
                            itemA.name < itemB.name
                        })){ item in
                            mealItemCard(item: item)
                        }
                        emptyMealItemCard
                        emptyMealItemCard
                    }
                    .padding(.vertical)
                }
            } else {
                emptyItemsText
            }

        }
        .padding(.vertical, 5)
    }
    
    private var rowHeader: some View {
        HStack(alignment: .center){
            Text("\(getFormattedNameForMealItemCategory(category))s")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(getColorByMealItemCategory(category: category))

            Spacer()

            Button {
                onNewClick(category)
            } label: {
                HStack{
                    Image(systemName: "plus")
                        .foregroundStyle(getColorByMealItemCategory(category: category))
                    Text("Add")
                        .foregroundStyle(getColorByMealItemCategory(category: category))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .font(.subheadline)
                .fontWeight(.medium)
                .overlay {
                    RoundedRectangle(cornerRadius: 100)
                        .stroke(getColorByMealItemCategory(category: category), lineWidth: 1.25)
                }
            }
        }
        .padding(.horizontal)
    }

    private var emptyItemsText: some View {
        VStack(alignment: .center){
            Text("Use the + Add button to")
            Text("add a new \(getFormattedNameForMealItemCategory(category).lowercased())")
        }
        .foregroundStyle(.secondary)
        .padding(.vertical, 30)
    }
    
    private func mealItemCardTextPortion(item: MealItem, isPreview: Bool = false) -> some View {
        VStack(spacing: 10){
            HStack{
                Text("\(item.name)")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundStyle(getColorByMealItemCategory(category: category))
                Spacer()
                Text("\(item.price.formatted(.currency(code: "USD")))")
                    .foregroundStyle(getColorByMealItemCategory(category: category))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .overlay {
                        RoundedRectangle(cornerRadius: 100)
                            .stroke(
                                getColorByMealItemCategory(category: category),
                                lineWidth: 0.75)
                    }
                    .padding(.leading, 10)
            }
            DividerElement(
                removePadding: true,
                customColor: getColorByMealItemCategory(category: category)
            )
            if let consumers = getPeopleForMealItem(meal: meal, item: item){
                HStack{
                    VStack(alignment: .leading, spacing: 5){
                        ForEach(consumers.sorted(by: { personA, personB in
                            personA.name < personB.name
                        })){ consumer in
                            Text("\(consumer.name)")
                                .font(.subheadline)
                                .foregroundStyle(
                                    getColorByMealItemCategory(category: category)
                                )
                        }
                    }
                    Spacer()
                }
            } else {
                VStack{
                    Text("No one's had")
                    Text("\(item.name.last == "s" ? "these" : "this") \(item.name)")
                }
                .foregroundStyle(getColorByMealItemCategory(category: category))
                .font(.subheadline)
                .padding(.vertical)
            }
        }
        .padding(.horizontal)
        .padding(.vertical)
        .frame(minWidth: isPreview == true ? 300 : 200)
    }
    
    private func mealItemCard(item: MealItem) -> some View {
        Button {
            onEditClick(item)
        } label: {
            mealItemCardTextPortion(item: item)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .foregroundStyle(colorScheme == .light ? .white : Color.init(uiColor: .systemGray6))
                    .overlay(alignment: .center, content: {
                        mealItemCardTextPortion(item: item)
                    })
                    .shadow(color: .primary.opacity(0.075), radius: 6, x: 0, y: 0)
            }
        }
        .contextMenu {
            Button("Edit", systemImage: "pencil") {
                onEditClick(item)
            }
            Button("Delete", systemImage: "trash", role: .destructive){
                // Clean up personId from meal's items
                if let mealPeople = meal.people {
                    mealPeople.forEach { person in
                        person.itemIds = person.itemIds.filter({ itemId in
                            itemId != item.id
                        })
                    }
                }
                modelContext.delete(item)
            }
        } preview: {
            mealItemCardTextPortion(item: item, isPreview: true)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .foregroundStyle(colorScheme == .light ? .white : Color.init(uiColor: .systemGray6))
                    .overlay(alignment: .center, content: {
                        mealItemCardTextPortion(item: item, isPreview: true)
                    })
                    .shadow(color: .primary.opacity(0.075), radius: 6, x: 0, y: 0)
            }
        }
    }
    
    private var emptyMealItemCard: some View {
        RoundedRectangle(cornerRadius: 12)
            .frame(width: 1, height: 10, alignment: .center)
            .foregroundStyle(.primary.opacity(0))
    }

}

//#Preview {
//    MealItemsRow()
//}
