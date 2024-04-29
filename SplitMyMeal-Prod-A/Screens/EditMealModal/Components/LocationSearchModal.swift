//
//  LocationSearchModal.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/28/24.
//

import SwiftUI

struct LocationSearchModal: View {

    @Environment(\.dismiss) private var dismiss

    let locationService: LocationService = LocationService(.init())

    @Bindable private var meal: Meal

    @State private var isNewLocation: Bool
    
    @State private var searchString: String
    @State private var searchResults: [SearchResult] = []
    
    var onSetLocation: (_ service: LocationService, _ details: SearchCompletions?) async -> ()
    var onClearLocation: () -> ()
    
    init(
        meal: Meal,
        searchString: String = "",
        onSetLocation: @escaping (_ service: LocationService, _ details: SearchCompletions?) async -> (),
        onClearLocation: @escaping () -> ()
    ){
        self.meal = meal
        self.searchString = searchString
        if(!searchString.isEmpty){
            self.locationService.update(queryFragment: searchString)
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
        Button {
            Task {
                await onSetLocation(locationService, completion)
            }
        } label: {
            VStack(alignment: .leading){
                Text("\(completion.title)")
                    .fontWeight(.medium)
                Text("\(completion.subTitle)")
            }
            .font(.callout)
        }
    }
    
    private var searchResultsList: some View {
        List {
            ForEach(locationService.completions){ location in
                searchResultRow(completion: location)
            }
        }
        .listStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.top, 10)
    }
}

//#Preview {
//    LocationSearchModal()
//}
