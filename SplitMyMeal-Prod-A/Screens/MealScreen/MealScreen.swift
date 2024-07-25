//
//  MealScreen.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/24/24.
//

import SwiftUI
import MapKit

enum MealDetailsViewType: String, CaseIterable, Identifiable {
    case items
    case people
    
    var id: Self { self }
}


struct MealScreen: View {
    
    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @Binding private var navigationPath: NavigationPath
    @Bindable private var meal: Meal
    private var restaurantDetails: RestaurantDetails? {
        return meal.restaurantDetails
    }
    
    @State private var selectedDetailsView: MealDetailsViewType = .people
    
    @State private var showEditMealModal: Bool = false
    @State private var showMapViewModal: Bool = false
    
    @State private var showTaxModal: Bool = false
    @State private var showTipModal: Bool = false
    @State private var showSplitsModal: Bool = false
    
    @State var mealItemToEdit: MealItem? = nil
    @State var mealPersonToEdit: MealPerson? = nil
    
    init(navigationPath: Binding<NavigationPath>, meal: Meal){
        self._navigationPath = navigationPath
        self.meal = meal
    }
    
    var body: some View {
        ScrollView{
            VStack{
                InfoSectionView(
                    meal: meal,
                    onMapClick: openMapView,
                    onTaxClick: openTaxModal,
                    onTipClick: openTipModal
                )
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
                    showSplitsModal.toggle()
                }
            }
//            TODO: Implement after iOS 18 adds cloudkit sharing via swiftdata
//            ToolbarItem(placement: .topBarTrailing) {
//                Button("", systemImage: "square.and.arrow.up") {
//                    //
//                }
//            }
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
        .sheet(isPresented: $showMapViewModal, content: {
                if let details = restaurantDetails {
                    MapViewModal(
                        meal: meal,
                        map: CLLocationCoordinate2D(
                            latitude: details.lattitude,
                            longitude: details.longitude
                        )
                    )
                }
            })
        .sheet(isPresented: $showTaxModal, content: {
            TaxModal(meal: meal, onSave: saveTax)
                .presentationDetents([.medium])
        })
        .sheet(isPresented: $showTipModal, content: {
            TipModal(meal: meal, onSave: saveTip)
                .presentationDetents([.medium])
        })
        .sheet(isPresented: $showSplitsModal, content: {
            SplitsModal(meal: meal)
        })
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
    // Map Functions
    // ================================================
    private func openMapView(){
        showMapViewModal = true
    }
    
    // ================================================
    // Tax & Tip Functions
    // ================================================
    private func openTaxModal(){
        showTaxModal = true
    }
    private func saveTax(percentage: Double?, amount: Double?, delete: Bool?){
        if let toDelete = delete {
            if(toDelete == true){
                meal.taxPercentage = nil
                meal.taxAmount = nil
            }
        }
        if let usePercentage = percentage {
            meal.taxPercentage = usePercentage
            meal.taxAmount = nil
        }
        if let useAmount = amount {
            meal.taxAmount = useAmount
            meal.taxPercentage = nil
        }
        showTaxModal = false
    }

    private func openTipModal(){
        showTipModal = true
    }
    private func saveTip(percentage: Double?, amount: Double?, delete: Bool?){
        if let toDelete = delete {
            if(toDelete == true){
                meal.tipPercentage = nil
                meal.tipAmount = nil
            }
        }
        if let usePercentage = percentage {
            meal.tipPercentage = usePercentage
            meal.tipAmount = nil
        }
        if let useAmount = amount {
            meal.tipAmount = useAmount
            meal.tipPercentage = nil
        }
        showTipModal = false
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
