//
//  RestaurantInputRow.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/30/24.
//

import SwiftUI
import MapKit

let STRING_EMPTY_RESTAURANT_SELECTION = "Select the restaurant"

struct RestaurantInputRow: View {

    @Bindable private var meal: Meal
    @Bindable private var restaurantDetails: RestaurantDetails?
    @State private var caption: String = STRING_EMPTY_RESTAURANT_SELECTION
    @State private var mapRegion: CLLocationCoordinate2D?
    
    init(
        meal: Meal
    ) {
        self.meal = meal
        if let details = meal.restaurantDetails {
            self.restaurantDetails = details
        } else {
            
        }
    }
    
    var body: some View {
        HStack{
            LabelWithCaptionLeading(
                label: "Location",
                caption: caption
            )
            Spacer()
            Button {
                // on click
            } label: {
                if let region = mapRegion {
                    Map(
                        position: .constant(
                            .region(
                                MKCoordinateRegion(
                                    center: region,
                                    span: MKCoordinateSpan(
                                        latitudeDelta: 0.015,
                                        longitudeDelta: 0.015
                                    )
                                )
                            )
                        )
                    )
                    .frame(width: 120, height: 90, alignment: .center)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                 BlockInputTrailing(placeholder: "📍")
                }
            }
        }
    }
}

//#Preview {
//    RestaurantInputRow()
//}
