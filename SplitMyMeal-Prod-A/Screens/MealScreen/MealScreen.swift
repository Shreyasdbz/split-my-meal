//
//  MealScreen.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/24/24.
//

import SwiftUI

enum MealDetailsViewType: String, CaseIterable, Identifiable {
    case items
    case people
    
    var id: Self { self }
}

struct MealScreen: View {
    
    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @Binding var navigationPath: NavigationPath
    @Bindable var meal: Meal
    
    @State private var selectedDetailsView: MealDetailsViewType = .people
    
    @State private var showEditMealModal: Bool = false
    
    @State var mealItemToEdit: MealItem? = nil
    @State var mealPersonToEdit: MealPerson? = nil
    
    var body: some View {
        ScrollView{
            VStack{
                InfoSectionView(meal: meal)
                DividerElement()
                sliderSelector
                if(selectedDetailsView == .items) {
                    MealItemsView(
                        meal: meal,
                        onNewClick: openMealItemModalNewItem,
                        onEditClick: openMealItemModalEditItem
                    )
                } else {
                    MealPeopleView(
                        meal: meal,
                        onNewClick: openMealPersonModalNewItem,
                        onEditClick: openMealPersonModalEditItem
                    )
                }
            }
        }
        .navigationTitle("\(meal.charm) \(meal.title)")
        .toolbar{
            ToolbarItem(placement: .bottomBar) {
                Button("Get split"){
                    //
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("", systemImage: "square.and.arrow.up") {
                    //
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("", systemImage: "slider.vertical.3") {
                    showEditMealModal.toggle()
                }
            }
        }
        .sheet(isPresented: $showEditMealModal, content: {
            EditMealModal(navigationPath: $navigationPath, meal: meal)
        })
        .sheet(
            item: $mealItemToEdit) {
                mealItemToEdit = nil
            } content: { mealItem in
                EditMealItemModal(
                    meal: meal,
                    mealItem: mealItemToEdit ?? MealItem(relatedMeal:nil, category: .Snack)
                )
            }
            .sheet(
                item: $mealPersonToEdit) {
                    mealPersonToEdit = nil
                } content: { mealPerson in
                    EditMealPersonModal(
                        meal: meal,
                        mealPerson: mealPersonToEdit ?? MealPerson(relatedMeal:nil)
                    )
                }
    }
    
    private var mapSection: some View {
        BlockInputField(
            label: "Location",
            caption: "Select the restaurant",
            placeholder: "📍") {
                //
            }
    }
    
    private var receiptSection: some View {
        BlockInputField(
            label: "Receipt",
            caption: "Attach a photo",
            placeholder: "🧾") {
                //
            }
    }
    
    private var sliderSelector: some View {
        Picker("Details", selection: $selectedDetailsView){
            Text("People")
                .tag(MealDetailsViewType.people)
            Text("Items")
                .tag(MealDetailsViewType.items)
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 300)
    }
    
    // ================================================
    // Meal Item Modal Functions
    // ================================================
    /**
     Sets the @State mealItemToEdit to a new mealItem without related meal
     */
    private func openMealItemModalNewItem(category: MealItemCategory){
        let newMealItem = MealItem(relatedMeal: nil, category: category)
        mealItemToEdit = newMealItem
    }
    /**
     Sets the @State mealItemToEdit to the existing meal item that was clicked on
     */
    private func openMealItemModalEditItem(item: MealItem){
        mealItemToEdit = item
    }
    
    
    // ================================================
    // Meal Person Modal Functions
    // ================================================
    /**
     Sets the @State mealItemToEdit to a new mealItem without related meal
     */
    private func openMealPersonModalNewItem(){
        let newMealPerson = MealPerson(relatedMeal: nil)
        mealPersonToEdit = newMealPerson
    }
    /**
     Sets the @State mealPersonToEdit to the existing meal person that was clicked on
     */
    private func openMealPersonModalEditItem(person: MealPerson){
        mealPersonToEdit = person
    }
}

//#Preview {
//    MealScreen()
//}
