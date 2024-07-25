//
//  EditMealModal.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/24/24.
//

import SwiftUI
import SwiftData
import MapKit
import MCEmojiPicker
import PhotosUI

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
    @FocusState private var titleFocusState: Bool
    @State private var showNameError: Bool = false

    @State private var charmInput: String
    @State private var showEmojiPicker: Bool = false

    @State private var restaurantDetailsInput: RestaurantDetails?
    @State private var mapSearchString: String
    @State private var showRestaurantPickerSheet: Bool = false
    
    @State private var selectedPhoto: PhotosPickerItem?
    
    init(navigationPath: Binding<NavigationPath>, meal: Meal){
        self._navigationPath = navigationPath
        self.meal = meal
        
        if(meal.title == ""){
            self.isNewMeal = true
            
            self.navigationTitleText = "New meal"
            self.saveButtonText = "Add new meal"
            self.titleInput = ""
            self.charmInput = "🍱"
            self.mapSearchString = ""
        } else {
            self.isNewMeal = false
            
            self.navigationTitleText = "Edit meal"
            self.saveButtonText = "Save changes"
            self.titleInput = meal.title
            self.charmInput = meal.charm
            
            if let existingDetails = meal.restaurantDetails {
                self.restaurantDetailsInput = existingDetails
                self.mapSearchString = existingDetails.address
            } else {
                self.mapSearchString = ""
            }
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
                    if(!isNewMeal){
                        deleteView
                    }
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
            .onAppear {
                CLLocationManager().requestWhenInUseAuthorization()
            }
            .sheet(isPresented: $showRestaurantPickerSheet, content: {
                LocationSearchModal(
                    meal: meal,
                    searchString: $mapSearchString,
                    onSetLocation: onSetLocation,
                    onClearLocation: onClearLocation
                )
                    .interactiveDismissDisabled(true)
            })
            .onChange(of: titleInput, { oldValue, newValue in
                if(newValue.isEmpty){
                    showNameError = true
                } else {
                    showNameError = false
                }
            })
            .onChange(of: selectedPhoto, setMealReceiptPhoto)
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
        HStack{
            LabelWithCaptionLeading(
                label: "Charm",
                caption: "Add a charm icon"
            )
            Spacer()
            Button{
                titleFocusState = false
                showEmojiPicker.toggle()
            } label: {
                RoundedRectangle(cornerRadius: 12)
                    .overlay(alignment: .center) {
                        Text("\(charmInput)")
                            .font(.title)
                    }
                    .foregroundStyle(Color.init(uiColor: .systemGray6))
                    .frame(width: 120, height: 90, alignment: .center)
                    .emojiPicker(
                        isPresented: $showEmojiPicker,
                        selectedEmoji: $charmInput,
                        arrowDirection: MCPickerArrowDirection.up,
                        isDismissAfterChoosing: true
                    )
            }
        }
    }
    
    private func mapBlock(map: CLLocationCoordinate2D) -> some View {
        Map(
            position: .constant(
                .region(
                    MKCoordinateRegion(
                        center: map,
                        span: MKCoordinateSpan(
                            latitudeDelta: 0.015,
                            longitudeDelta: 0.015
                        )
                    )
                )
            )
        ){
            Annotation(
                "",
                coordinate: map,
                anchor: .center) {
                    Text("📍")
                        .font(.subheadline)
                        .padding()
                }
        }
        .frame(width: 120, height: 90, alignment: .center)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var inputFieldLocation: some View{
        HStack{
            if let details = restaurantDetailsInput {
                LabelWithCaptionLeading(
                    label: "Location",
                    caption: "\(details.title)\n\(details.address)",
                    useSmallCaption: true
                )
            } else {
                LabelWithCaptionLeading(
                    label: "Location",
                    caption: "Select the restaurant"
                )
            }
            Spacer()
            Button{
                showRestaurantPickerSheet = true
            } label: {
                if let details = restaurantDetailsInput {
                    mapBlock(
                        map: CLLocationCoordinate2D(
                            latitude: details.lattitude,
                            longitude: details.longitude
                        )
                    )
                } else {
                    BlockInputTrailing(placeholder: "📍")
                }
            }
        }
    }
    
    private var inputFieldReceipt: some View{
        VStack{
            HStack{
                VStack(alignment: .leading){
                    LabelWithCaptionLeading(
                        label: "Receipt",
                        caption: "Attach a photo"
                    )
                    if let imageData = meal.receiptPhoto, let _ = UIImage(data: imageData) {
                        Button{
                            meal.receiptPhoto = nil
                            selectedPhoto = nil
                        } label: {
                            HStack(spacing: 5){
                                Image(systemName: "xmark")
                                Text("Remove")
                            }
                            .font(.callout)
                            .fontWeight(.light)
                            .tint(.red)
                        }
                    }

                }
                Spacer()
                PhotosPicker(
                    selection: $selectedPhoto,
                    matching: .images
                ) {
                    if let imageData = meal.receiptPhoto, let uiImage = UIImage(data: imageData) {
                        
                        Image(uiImage: uiImage)
                            .resizable()
                            .frame(width: 120, height: 90, alignment: .center)
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        BlockInputTrailing(placeholder: "🧾")
                    }

                }
            }
        }
    }
    
    private var deleteView: some View {
        Button("Delete meal", systemImage: "trash", role: .destructive) {
            dismiss()
            modelContext.delete(meal)
            navigationPath.removeLast()
        }
        .padding(.vertical, 30)
    }
    
    private func onSetLocation(restaurantDetails: RestaurantDetails?) async {
        self.restaurantDetailsInput = restaurantDetails
        if let details = restaurantDetails {
            mapSearchString = details.address
        }
        showRestaurantPickerSheet = false
    }

    private func onClearLocation() {
        self.restaurantDetailsInput = nil
        self.mapSearchString = ""
        showRestaurantPickerSheet = false
    }
    
    private func setMealReceiptPhoto(){
        Task { @MainActor in
            meal.receiptPhoto = try await selectedPhoto?.loadTransferable(type: Data.self)
        }
    }
    
    private func saveChanges(){
        
        var validationPassed: Bool = true
        
        // Title Validation
        if (titleInput.isEmpty){
            validationPassed = false
            return
        } else {
            meal.title = titleInput
        }
        // Charm Validation
        if(charmInput.isEmpty){
            validationPassed = false
            return
        } else {
            meal.charm = charmInput
        }

        if(validationPassed == true){
            if(isNewMeal){
                modelContext.insert(meal)
                // Location Case - New meal, with map
                if let details = restaurantDetailsInput {
                    details.relatedMeal = meal
                    modelContext.insert(details)
                    meal.restaurantDetails = details
                }
                dismiss()
                navigationPath.append(meal)

            } else {
                if let existingDetails = meal.restaurantDetails {
                    if let newDetails = restaurantDetailsInput {
                        if(existingDetails.address != newDetails.address){
                            // Location Case - Existing meal, modify map
                            existingDetails.title = newDetails.title
                            existingDetails.address = newDetails.address
                            existingDetails.lattitude = newDetails.lattitude
                            existingDetails.longitude = newDetails.longitude
                        }
                    } else {
                        // Location Case - Existing meal, remove map
                        meal.restaurantDetails = nil
                        modelContext.delete(existingDetails)
                    }
                } else {
                    // Location Case - Existing meal, add map
                    if let newDetails = restaurantDetailsInput {
                        newDetails.relatedMeal = meal
                        modelContext.insert(newDetails)
                        meal.restaurantDetails = newDetails
                    }
                }
                
                meal.modifiedAt = Date()
                dismiss()
            }
        }
    }
}

//#Preview {
//    EditMealModal()
//}
