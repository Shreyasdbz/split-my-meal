//
//  SearchResultRow.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 5/3/24.
//

import SwiftUI
import MapKit
import CoreLocation

struct SearchResultRow: View {

    let locationService: LocationService
    let userLatitude: Double
    let userLongitude: Double
    let completion: SearchCompletions
    var onClick: (_ completion: SearchCompletions) async -> ()

    @State private var distanceAway: String = ""
    
    var body: some View {
        Button {
            Task {
                await onClick(completion)
            }
        } label: {
            VStack(alignment: .leading){
                Text("\(completion.title)")
                    .fontWeight(.medium)
                Text("\(completion.subTitle)")
                if (distanceAway != "") {
                    Text("\(distanceAway) miles away")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.callout)
        }
        .onAppear(perform: {
            if(CLLocationManager.headingAvailable()){
                Task {
                    if (userLatitude != 0.0 && userLatitude != 0.0) {
                        let restaurantDetails = await convertSearchToLocation(
                            locationService: locationService,
                            title: completion.title,
                            address: completion.subTitle
                        )
                        if let details = restaurantDetails {
                            // TODO: Get distance
                            let poiCoordinates = CLLocation(
                                latitude: CLLocationDegrees(details.location.latitude),
                                longitude: CLLocationDegrees(details.location.longitude))
                            let userCoordinates = CLLocation(
                                latitude: CLLocationDegrees(userLatitude),
                                longitude: CLLocationDegrees(userLongitude)
                            )
//                            let distance = userCoordinates.distance(from: poiCoordinates) * (0.621371 / 1000)
                            let distance = userCoordinates.distance(from: poiCoordinates) * (1 / 1000)
                            let distanceString = String(
                                format: "%.01f", distance)
                            distanceAway = distanceString
                        }
                    }
                }
            }
        })
    }
}

//#Preview {
//    SearchResultRow()
//}
