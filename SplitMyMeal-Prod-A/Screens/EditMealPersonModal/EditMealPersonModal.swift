//
//  EditMealPersonModal.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/26/24.
//

import SwiftUI


struct EditMealPersonModal: View {
    
    private let STRING_NAVINGATION_TITLE_NEW = "Add person"
    private let STRING_NAVINGATION_TITLE_EDIT = "Edit person"
    private let STRING_SAVE_CHANGES_NEW = "Add new person"
    private let STRING_SAVE_CHANGES_EDIT = "Save changes"
    
    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @Bindable private var meal: Meal
    @Bindable private var mealPerson: MealPerson
    
    @State private var isNewMealPerson: Bool
    @State private var navigationTitleText: String
    @State private var saveButtonText: String
    
    @State private var nameInput: String
    @State private var showNameInputError: Bool = false
    @State private var itemsInput: [String]
    
    @FocusState private var nameInputFocused: Bool
    
    init(meal: Meal, mealPerson: MealPerson){
        self.meal = meal
        self.mealPerson = mealPerson
        
        if(mealPerson.name.isEmpty){
            // New Person
            self.isNewMealPerson = true
            self.navigationTitleText = STRING_NAVINGATION_TITLE_NEW
            self.saveButtonText = STRING_SAVE_CHANGES_NEW
            self.nameInput = ""
            self.itemsInput = []
        } else {
            // Existing Person
            self.isNewMealPerson = false
            self.navigationTitleText = STRING_NAVINGATION_TITLE_EDIT
            self.saveButtonText = STRING_SAVE_CHANGES_EDIT
            self.nameInput = mealPerson.name
            self.itemsInput = mealPerson.itemIds
        }
    }
    
    var body: some View {
        NavigationStack{
            ScrollView(.vertical){
                VStack(spacing: 30){
                    inputFieldName
                    inputFieldMealItems
                    if(!isNewMealPerson){
                        deletePersonView
                    }
                }
                .padding(.horizontal)
                .padding(.vertical)
            }
            .background(colorScheme == .dark ? Color.black : Color.white)
            .navigationTitle("\(navigationTitleText)")
            .toolbar{
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel"){
                        dismiss()
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("\(saveButtonText)"){
                        saveChanges()
                    }
                }
            }
            .onChange(of: mealPerson) { oldValue, newValue in
                if(oldValue.name == "" && newValue.name != ""){
                    updateStateForEdit(newMeal: meal, newPerson: newValue)
                }
            }
        }
    }
    
    private var inputFieldName: some View {
        TextInputField(
            label: "Name",
            placeholder: "Give the person a name",
            inputString: $nameInput,
            showError: showNameInputError
        )
        .focused($nameInputFocused)
        .onSubmit {
            nameInputFocused = false
        }
    }
    
    private var noItemsInMealView: some View {
        VStack(alignment: .center){
            Text("No items in this meal")
            Text("Add an item from the Items tab")
        }
        .foregroundStyle(.secondary)
        .padding(.vertical, 30)
    }
    
    private var inputFieldMealItems: some View {
        VStack(alignment: .leading, spacing: 10){
            HStack{
                LabelWithCaptionLeading(label: "Items", caption: "Select the items that this person had")
                Spacer()
            }
            
            if let mealItems = getAllMealItemsForMeal(meal: meal){
                FlexStack{
                    ForEach(mealItems.sorted(by: { itemA, itemB in
                        itemA.category.rawValue < itemB.category.rawValue
                    })){ item in
                        Button("\(item.name)",
                               systemImage:
                                itemsInput.contains(item.id) ? "checkmark.circle.fill" : "circle.dotted"
                        ) {
                            toggleMealItemSelection(itemId: item.id)
                        }
                        .foregroundStyle(getColorByMealItemCategory(category: item.category))
                        .padding(.horizontal)
                        .padding(.vertical)
                        .background(Color.init(uiColor: .systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            } else {
                noItemsInMealView
            }
        }
    }
    
    private var deletePersonView: some View {
        Button("Delete person", systemImage: "trash", role: .destructive) {
            // Clean up personId from meal's items
            if let mealItems = meal.items {
                mealItems.forEach { item in
                    item.consumerIds = item.consumerIds.filter({ consumerId in
                        consumerId != mealPerson.id
                    })
                }
            }
            
            mealPerson.relatedMeal = meal
            modelContext.delete(mealPerson)
            dismiss()
        }
        .padding(.vertical, 30)
    }

    /**
     Updates the meal with selected value
     */
    private func toggleMealItemSelection(itemId: String){
        if(itemsInput.contains(itemId)){
            itemsInput = itemsInput.filter({ $0 != itemId })
        } else {
            itemsInput.append(itemId)
        }
    }
    
    /**
     Tackles the problem of mealPersonToEdit not updating quick enough when editing existing
     */
    private func updateStateForEdit(newMeal: Meal, newPerson: MealPerson){
        isNewMealPerson = false
        
        mealPerson.relatedMeal = newMeal
        mealPerson.id = newPerson.id
        mealPerson.name = newPerson.name
        mealPerson.itemIds = newPerson.itemIds
        
        navigationTitleText = STRING_NAVINGATION_TITLE_EDIT
        saveButtonText = STRING_SAVE_CHANGES_EDIT
        nameInput = newPerson.name
        itemsInput = newPerson.itemIds
    }
    
    /**
     Saves changes (both add or edit)
     */
    private func saveChanges(){
        var validationPass: Bool = true
        
        if(nameInput.isEmpty || nameInput == ""){
            validationPass = false
            showNameInputError = true
        } else {
            validationPass = true
            showNameInputError = false
        }
        
        if(validationPass == true){
            mealPerson.name = nameInput
            mealPerson.itemIds = itemsInput

            // Update meal's items with person's selection
            if let mealItems = meal.items {
                mealItems.forEach { item in
                    // inInput & inItem -- NA
                    // NOT inInput & NOT inItem -- NA
                    // inInput & NOT inItem: -- APPEND
                    if(itemsInput.contains(item.id) && !item.consumerIds.contains(mealPerson.id)){
                        item.consumerIds.append(mealPerson.id)
                    }
                    // NOT inInput & inItem: -- FILTER OUT
                    if(!itemsInput.contains(item.id) && item.consumerIds.contains(mealPerson.id)){
                        item.consumerIds = item.consumerIds.filter({ consumerId in
                            consumerId != mealPerson.id
                        })
                    }
                }
            }

            
            if(isNewMealPerson){
                mealPerson.relatedMeal = meal
                modelContext.insert(mealPerson)
            }
            meal.modifiedAt = Date()
            dismiss()
        }
    }
    

}

//#Preview {
//    EditMealPersonModal()
//}
