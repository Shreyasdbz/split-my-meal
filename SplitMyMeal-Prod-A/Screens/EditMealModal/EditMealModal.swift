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

struct EditMealModal: View {
    
    let STRING_EMPTY_RESTAURANT_SELECTION = "Select the restaurant"
    
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

    @State private var mapSearchString: String
    @State private var mapInputCaption: String
    @State private var mapRegion: CLLocationCoordinate2D?
    @State private var showRestaurantPickerSheet: Bool = false
    
    
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
            self.mapInputCaption = STRING_EMPTY_RESTAURANT_SELECTION
        } else {
            self.isNewMeal = false
            
            self.navigationTitleText = "Edit meal"
            self.saveButtonText = "Save changes"
            self.titleInput = meal.title
            self.charmInput = meal.charm
            
            if let existingDetails = meal.restaurantDetails {
                if let title = existingDetails.title, let subtitle = existingDetails.address {
                    self.mapSearchString = title
                    self.mapInputCaption = "\(title)\n\(subtitle)"
                } else {
                    self.mapSearchString = ""
                    self.mapInputCaption = STRING_EMPTY_RESTAURANT_SELECTION
                }
                if let lattitude = existingDetails.lattitude, let longitude = existingDetails.longitude {
                    self.mapRegion = CLLocationCoordinate2D(
                        latitude: lattitude, longitude: longitude
                    )
                }
            } else {
                self.mapSearchString = ""
                self.mapInputCaption = STRING_EMPTY_RESTAURANT_SELECTION
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
            .sheet(isPresented: $showRestaurantPickerSheet, content: {
                LocationSearchModal(
                    meal: meal,
                    searchString: mapSearchString,
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
    
    private func mapBlock(map: CLLocationCoordinate2D) -> some View {
        Map(
            initialPosition: .region(
                MKCoordinateRegion(
                    center: map,
                    span: MKCoordinateSpan(
                        latitudeDelta: 0.015,
                        longitudeDelta: 0.015
                    )
                )
            )
        ){
            Annotation(
                "",
                coordinate: map,
                anchor: .center) {
                    Image(systemName: "mappin")
                        .font(.subheadline)
                        .tint(.red)
                        .padding()
                }
        }
        .frame(width: 120, height: 90, alignment: .center)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var inputFieldLocation: some View{
        HStack{
            LabelWithCaptionLeading(
                label: "Location",
                caption: mapInputCaption
            )
            Spacer()
            Button{
                showRestaurantPickerSheet = true
            } label: {
                if let map = mapRegion {
                    mapBlock(map: map)
                } else {
                    BlockInputTrailing(placeholder: "📍")
                }
            }
        }
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
    
    private func onSetLocation(_ service: LocationService, _ details: SearchCompletions?) async {
        guard let restaurantDetails = details else { return }
        let conversion = await convertSearchToLocation(
            locationService: service,
            title: restaurantDetails.title,
            address: restaurantDetails.subTitle
        )
        guard let convertedDetails = conversion else { return }

        //
        // TODO: Move to save. Currently it's creating new meals on search press
        //
        
        if let currentDetails = meal.restaurantDetails {
            currentDetails.title = restaurantDetails.title
            currentDetails.address = restaurantDetails.subTitle
            currentDetails.lattitude = convertedDetails.location.latitude
            currentDetails.longitude = convertedDetails.location.longitude
        } else {
            let newDetails = RestaurantDetails()
            newDetails.relatedMeal = meal
            newDetails.title = restaurantDetails.title
            newDetails.address = restaurantDetails.subTitle
            newDetails.lattitude = convertedDetails.location.latitude
            newDetails.longitude = convertedDetails.location.longitude
            modelContext.insert(newDetails)
        }
        mapRegion = CLLocationCoordinate2D(
            latitude: convertedDetails.location.latitude,
            longitude: convertedDetails.location.longitude
        )
        mapSearchString = restaurantDetails.subTitle
        mapInputCaption = "\(restaurantDetails.title)\n\(restaurantDetails.subTitle)"
        showRestaurantPickerSheet = false
    }

    private func onClearLocation() {
        //
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
