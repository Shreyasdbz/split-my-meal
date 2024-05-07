//
//  LocationSearchModal.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/28/24.
//

import SwiftUI
import MapKit

struct LocationSearchModal: View {

    @Environment(\.dismiss) private var dismiss
    let locationService: LocationService = LocationService(.init())
    @StateObject var locationManager = LocationManager()

    @Bindable private var meal: Meal
    @Binding private var searchString: String

    @State private var isNewLocation: Bool
    @State private var searchResults: [SearchResult] = []
    
    var onSetLocation: (_ restaurantDetails: RestaurantDetails?) async -> ()
    var onClearLocation: () -> ()
    
    init(
        meal: Meal,
        searchString: Binding<String>,
        onSetLocation: @escaping (_ restaurantDetails: RestaurantDetails?) async -> (),
        onClearLocation: @escaping () -> ()
    ){
        self.meal = meal
        self._searchString = searchString
        if(!searchString.wrappedValue.isEmpty){
            self.locationService.update(queryFragment: searchString.wrappedValue)
            self.isNewLocation = false
        } else {
            self.isNewLocation = true
        }
        self.onSetLocation = onSetLocation
        self.onClearLocation = onClearLocation
    }
    
    var body: some View {
        NavigationStack{
            VStack{
                searchField
                if(isNewLocation == false){
                    clearLocationButton
                }
                if(!locationService.completions.isEmpty){
                    searchResultsList
                }
                Spacer()
            }
            .navigationTitle("Location")
            .padding(.horizontal)
            .padding(.top, 30)
            .presentationBackground(.ultraThinMaterial)
            .toolbar{
                ToolbarItem(placement: .topBarLeading) {
                    Button("Dismiss"){
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var searchField: some View {
        TextInputField(
            label: "Search",
            placeholder: "Look for a restaurant name",
            inputString: $searchString,
            showError: false,
            useLighterBg: true
        )
        .submitLabel(.search)
        .autocorrectionDisabled()
        .onChange(of: searchString, { _, newValue in
            if(newValue.count > 2){
                locationService.update(queryFragment: searchString)
            }
        })
        .onSubmit {
            locationService.update(queryFragment: searchString)
        }
    }
    
    private var clearLocationButton: some View {
        Button {
            onClearLocation()
        } label: {
            HStack(spacing: 10){
                Image(systemName: "trash")
                Text("Clear location")
            }
            .padding()
            .foregroundStyle(Color.red)
        }
        .padding(.top)
        .padding(.horizontal)
    }
    
    private func searchResultRow(completion: SearchCompletions) -> some View {        
        return(
            Button {
                Task {
                    await onLocationClick(completion: completion)
                }
            } label: {
                VStack(alignment: .leading){
                    Text("\(completion.title)")
                        .fontWeight(.medium)
                    Text("\(completion.subTitle)")
                    Text("12.3 miles away")
                }
                .font(.callout)
            }
        )
    }
    
    private var searchResultsList: some View {
        List {
            ForEach(locationService.completions){ location in
                SearchResultRow(
                    locationService: locationService,
                    userLatitude: locationManager.lastLocation?.coordinate.latitude ?? 0.0,
                    userLongitude: locationManager.lastLocation?.coordinate.longitude ?? 0.0,
                    completion: location,
                    onClick: onLocationClick
                )
            }
        }
        .listStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.top, 10)
    }
    
    private func onLocationClick(completion: SearchCompletions) async {
        let restaurant = await convertSearchToLocation(
            locationService: locationService,
            title: completion.title,
            address: completion.subTitle
        )
        if let details = restaurant {
            let restaurantDetails = RestaurantDetails()
            restaurantDetails.title = completion.title
            restaurantDetails.address = completion.subTitle
            restaurantDetails.lattitude = details.location.latitude
            restaurantDetails.longitude = details.location.longitude
            
            await onSetLocation(restaurantDetails)
        }
    }
}

//#Preview {
//    LocationSearchModal()
//}
