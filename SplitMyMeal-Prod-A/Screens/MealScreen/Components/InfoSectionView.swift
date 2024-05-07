//
//  InfoSectionView.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/24/24.
//

import SwiftUI
import MapKit

struct InfoSectionView: View {

    let meal: Meal
    var onMapClick: () -> ()

    var body: some View {
        VStack(spacing: 10){
            mapSection
            receiptSection
            taxSection
            tipSection
        }
        .padding(.top)
        .padding(.horizontal)
    }
    
    private var mapSection: some View {
        HStack{
            if let details = meal.restaurantDetails {
                LabelWithCaptionLeading(
                    label: "Location",
                    caption: "\(details.title)\n\(details.address)",
                    useSmallCaption: true
                )
                Spacer()
                Button {
                    onMapClick()
                } label: {
                    mapBlock(
                        map: CLLocationCoordinate2D(
                            latitude: details.lattitude,
                            longitude: details.longitude
                        )
                    )
                }
            } else {
                LabelWithCaptionLeading(
                    label: "Location",
                    caption: "Select the restaurant"
                )
                Spacer()
                BlockInputTrailing(placeholder: "📍")
            }
        }
    }

    private var receiptSection: some View {
        VStack{
            BlockInputField(
                label: "Receipt",
                caption: "Attach a photo",
                placeholder: "🧾"
            ) {
                    //
            }
        }
    }

    private var taxSection: some View {
        VStack{
            BlockInputFieldShort(
                label: "Tax",
                placeholder: "🗳️"
            ) {
                    //
            }
        }
    }

    private var tipSection: some View {
        VStack{
            BlockInputFieldShort(
                label: "Tip",
                placeholder: "✨"
            ) {
                    //
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
}

//#Preview {
//    InfoSectionView()
//}
