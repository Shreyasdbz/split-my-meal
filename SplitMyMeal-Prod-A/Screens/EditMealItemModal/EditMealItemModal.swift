//
//  EditMealItemModal.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/25/24.
//

import SwiftUI

enum MealItemInputField: Int, Hashable {
    case name
    case price
}

struct EditMealItemModal: View {

    private let STRING_NAVINGATION_TITLE_NEW = "New item"
    private let STRING_NAVINGATION_TITLE_EDIT = "Edit item"
    private let STRING_SAVE_CHANGES_NEW = "Add new item"
    private let STRING_SAVE_CHANGES_EDIT = "Save changes"
    
    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @Bindable private var meal: Meal
    @Bindable private var mealItem: MealItem
    
    @State private var isNewMealItem: Bool
    @State private var navigationTitleText: String
    @State private var saveButtonText: String
    
    @State private var nameInput: String
    @State private var showNameInputError: Bool
    
    @State private var priceInput: Double?
    @State private var showPriceInputError: Bool
    
    @State private var categoryInput: MealItemCategory
    @State private var consumersInput: [String]
    
    @FocusState private var focusedField: MealItemInputField?
    
    init(meal: Meal, mealItem: MealItem){
        self.meal = meal
        self.mealItem = mealItem
        self.categoryInput = mealItem.category
        
        if(mealItem.name.isEmpty) {
            // New Item
            self.isNewMealItem = true
            self.navigationTitleText = STRING_NAVINGATION_TITLE_NEW
            self.saveButtonText = STRING_SAVE_CHANGES_NEW
            self.nameInput = ""
            self.priceInput = 0.0
            self.showNameInputError = false
            self.showPriceInputError = false
            self.consumersInput = []
        } else {
            // Existing item
            self.isNewMealItem = false
            self.navigationTitleText = STRING_NAVINGATION_TITLE_EDIT
            self.saveButtonText = STRING_SAVE_CHANGES_EDIT
            self.nameInput = mealItem.name
            self.showNameInputError = false
            self.showPriceInputError = false
            self.priceInput = mealItem.price
            self.consumersInput = mealItem.consumerIds
        }
    }
    
    var body: some View {
        NavigationStack{
            ScrollView(.vertical) {
                VStack(spacing: 30){
                    inputFieldName
                    inputFieldPrice
                    inputFieldCategory
                    inputFieldMealPersons
                    if(!isNewMealItem){
                        deleteItemView
                    }
                }
                .padding(.horizontal)
                .padding(.vertical)
                .navigationTitle(navigationTitleText)
            }
            .background(colorScheme == .dark ? Color.black : Color.white)
            .toolbar{
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    
                    Button("Done") {
                        focusedField = nil
                    }
                }
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
            .onChange(of: mealItem) { oldValue, newValue in
                if(oldValue.name == "" && newValue.name != ""){
                    updateStateForEdit(newMeal: meal, newItem: newValue)
                }
            }
        }
    }
    
    private var inputFieldName: some View {
        TextInputField(
            label: "Name",
            placeholder: "Give your item a name",
            inputString: $nameInput,
            showError: showNameInputError
        )
        .submitLabel(.next)
        .focused($focusedField, equals: .name)
        .onSubmit {
            focusedField = .price
        }
    }
    
    private var inputFieldPrice: some View {
        HStack{
            LabelWithCaptionLeading(label: "Price", caption: "Set the price for the item")
            Spacer()
            HStack(spacing: 5){
                Text("$")
                    .font(.headline)
                    .fontWeight(.light)
                    .foregroundStyle(.secondary)
                
                TextField("0.0", value: $priceInput, format: .number)
                    .submitLabel(.next)
                    .frame(width: 65)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    .background(Color.init(uiColor: .systemGray6))
                    .overlay(showPriceInputError == true ?
                             RoundedRectangle(cornerRadius: 8)
                        .stroke(.red.opacity(0.7), lineWidth: 1)
                             : nil
                    )
                    .cornerRadius(8)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .price)
                    .onChange(of: focusedField, { oldValue, newValue in
                        if(newValue == .price && priceInput == 0.0){
                            // Entering price input
                            $priceInput.wrappedValue = nil
                        }
                    })
                    .onChange(of: priceInput ?? 0.0) { oldValue, newValue in
                        if(newValue <= 0.0){
                            showPriceInputError = true
                        } else {
                            showPriceInputError = false
                        }
                    }
            }
            .padding(.leading, 10)
        }
    }
    
    private var inputFieldCategory: some View {
        HStack{
            LabelWithCaptionLeading(label: "Category", caption: "Pick the category for the item")
            Spacer()
            Menu("\(getFormattedNameForMealItemCategory(categoryInput))", systemImage: "chevron.up.chevron.down"){
                Picker(
                    "\(getFormattedNameForMealItemCategory(categoryInput))",
                    selection: $categoryInput
                ){
                    ForEach(MealItemCategory.allCases, id: \.rawValue) { categorySelection in
                        Text("\(getFormattedNameForMealItemCategory(categorySelection))")
                            .tag(categorySelection)
                    }
                }
            }
            .foregroundStyle(getColorByMealItemCategory(category: categoryInput))
            .fontWeight(.medium)
            .onTapGesture {
                focusedField = nil
            }
        }
    }
    
    private var inputFieldMealPersons: some View {
        VStack{
            HStack{
                LabelWithCaptionLeading(label: "People", caption: "Select the people that had this item")
                Spacer()
            }
            if let mealPersons = getAllMealPersonsForMeal(meal: meal){
                FlexStack{
                    ForEach(mealPersons.sorted(by: { personA, personB in
                        personA.name < personB.name
                    })){ person in
                        Button("\(person.name)",
                               systemImage:
                                consumersInput.contains(person.id) ? "checkmark.circle.fill" : "circle.dotted"
                        ) {
                            toggleMealPersonSelection(personId: person.id)
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal)
                        .padding(.vertical)
                        .background(Color.init(uiColor: .systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            } else {
                noPeopleInMealView
            }
        }
    }
    
    private var noPeopleInMealView: some View {
        VStack(alignment: .center){
            Text("No people in this meal")
            Text("Add a person from the People tab")
        }
        .foregroundStyle(.secondary)
        .padding(.vertical, 30)
    }
        
    private var deleteItemView: some View {
        Button("Delete item", systemImage: "trash", role: .destructive) {
            // Clean up personId from meal's items
            if let mealPeople = meal.people {
                mealPeople.forEach { person in
                    person.itemIds = person.itemIds.filter({ itemId in
                        itemId != mealItem.id
                    })
                }
            }
            
            mealItem.relatedMeal = meal
            modelContext.delete(mealItem)
            dismiss()
        }
        .padding(.vertical, 30)
    }

    /**
     Updates the meal with selected value
     */
    private func toggleMealPersonSelection(personId: String){
        if(consumersInput.contains(personId)){
            consumersInput = consumersInput.filter({ $0 != personId })
        } else {
            consumersInput.append(personId)
        }
    }
    
    /**
     Tackles the problem of mealItemToEdit not updating quick enough when editing existing
     */
    private func updateStateForEdit(newMeal: Meal, newItem: MealItem){
        isNewMealItem = false

        mealItem.relatedMeal = newMeal
        mealItem.id = newItem.id
        mealItem.name = newItem.name
        mealItem.price = newItem.price
        mealItem.category = newItem.category
        mealItem.consumerIds = newItem.consumerIds
        
        navigationTitleText = STRING_NAVINGATION_TITLE_EDIT
        saveButtonText = STRING_SAVE_CHANGES_EDIT
        nameInput = newItem.name
        priceInput = newItem.price
        categoryInput = newItem.category
        consumersInput = newItem.consumerIds
    }

    /**
     Saves changes (both add or edit)
     */
    private func saveChanges() {
        var validationPass: Bool = true
        
        if let priceInputForSave = priceInput {
            if(priceInputForSave <= 0.0){
                showPriceInputError = true
                validationPass = false
            } else {
                showNameInputError = false
            }
        } else {
            validationPass = false
            showPriceInputError = true
        }
        
        if(nameInput == ""){
            validationPass = false
            showNameInputError = true
        } else {
            showNameInputError = false
        }
        
        if(validationPass == true){
            mealItem.name = nameInput
            mealItem.price = priceInput ?? 9.99
            mealItem.category = categoryInput
            mealItem.consumerIds = consumersInput
            
            // Update meal's people with item's persons selections
            if let mealPeople = meal.people {
                mealPeople.forEach { person in
                    // inInput & inPerson -- NA
                    // NOT inInput & NOT inPerson -- NA
                    // inInput & NOT inPerson: -- APPEND
                    if(consumersInput.contains(person.id) && !person.itemIds.contains(mealItem.id)){
                        person.itemIds.append(mealItem.id)
                    }
                    // NOT inInput & inPerson: -- FILTER OUT
                    if(!consumersInput.contains(person.id) && person.itemIds.contains(mealItem.id)){
                        person.itemIds = person.itemIds.filter({ itemId in
                            itemId != mealItem.id
                        })
                    }
                }
            }

            if(isNewMealItem){
                mealItem.relatedMeal = meal
                modelContext.insert(mealItem)
            }
            meal.modifiedAt = Date()
            dismiss()
        }
    }
}

//#Preview {
//    EditMealItemModal()
//}
