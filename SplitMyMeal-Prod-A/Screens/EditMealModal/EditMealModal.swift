//
//  EditMealModal.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/24/24.
//

import SwiftUI
import SwiftData
import MCEmojiPicker

struct EditMealModal: View {

    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss

    @Binding var navigationPath: NavigationPath
    @Bindable var meal: Meal

    @State private var isNewMeal: Bool
    @State private var navigationTitleText: String
    @State private var saveButtonText: String

    @State private var titleInput: String
    @State private var charmInput: String
    
    @FocusState private var titleFocusState: Bool
    @State private var showEmojiPicker: Bool = false
    @State private var showNameError: Bool = false

    
    init(navigationPath: Binding<NavigationPath>, meal: Meal){
        self._navigationPath = navigationPath
        self.meal = meal
        
        if(meal.title == ""){
            self.isNewMeal = true

            self.navigationTitleText = "New meal"
            self.saveButtonText = "Add new meal"
            self.titleInput = ""
            self.charmInput = "🍱"
        } else {
            self.isNewMeal = false

            self.navigationTitleText = "Edit meal"
            self.saveButtonText = "Save changes"
            self.titleInput = meal.title
            self.charmInput = meal.charm
        }
    }
    
    var body: some View {
        NavigationStack{
            ScrollView {
                VStack(spacing: 10){
                    inputFieldTitle
                    inputFieldCharm
                    inputFieldLocation
                    inputFieldReceipt
                }
                .padding(.horizontal)
                .padding(.vertical)
                .navigationTitle(navigationTitleText)
            }
            .background(colorScheme == .dark ? Color.black : Color.white)
            .toolbar{
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel"){
                        dismiss()
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button(saveButtonText){
                        saveChanges()
                    }
                }
            }
            .onChange(of: titleInput, { oldValue, newValue in
                if(newValue.isEmpty){
                    showNameError = true
                } else {
                    showNameError = false
                }
            })
            .onAppear(perform: {
                titleFocusState = true
            })
        }
    }
    
    private var inputFieldTitle: some View {
        TextInputField(
            label: "Title",
            placeholder: "Give your meal a name",
            inputString: $titleInput,
            showError: showNameError
        )
        .focused($titleFocusState)
    }
    
    private var inputFieldCharm: some View {
        //TODO: Add keyboard dismiss
        BlockInputField(
            label: "Charm",
            caption: "Add a charm icon",
            placeholder: charmInput,
            onClick: {
                titleFocusState = false
                showEmojiPicker.toggle()
            }
        )
        .emojiPicker(
            isPresented: $showEmojiPicker,
            selectedEmoji: $charmInput,
            arrowDirection: MCPickerArrowDirection.up,
            isDismissAfterChoosing: true
        )
    }
    
    private var inputFieldLocation: some View{
        BlockInputField(
            label: "Location",
            caption: "Select the restaurant",
            placeholder: "📍",
            onClick: {
                //
            }
        )
    }    
    
    private var inputFieldReceipt: some View{
        BlockInputField(
            label: "Receipt",
            caption: "Attach a photo",
            placeholder: "🧾",
            onClick: {
                //
            }
        )
    }
    
    private func saveChanges(){
        if(isNewMeal){
            
            if(!titleInput.isEmpty && !charmInput.isEmpty){
                meal.title = titleInput
                meal.charm = charmInput
                
                modelContext.insert(meal)
                dismiss()
                navigationPath.append(meal)
            } else {
                showNameError = true
            }
        } else {
            // TODO: Save
            if(meal.title != titleInput && !titleInput.isEmpty){
                meal.title = titleInput
            }
            if(meal.charm != charmInput && !charmInput.isEmpty){
                meal.charm = charmInput
            }
            meal.modifiedAt = Date()
            dismiss()
        }
        
    }
}

//#Preview {
//    EditMealModal()
//}
