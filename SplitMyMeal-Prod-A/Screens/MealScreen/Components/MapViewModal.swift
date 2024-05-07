//
//  MapViewModal.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/30/24.
//

import SwiftUI
import MapKit

struct MapViewModal: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @State var meal: Meal
    @State var map: CLLocationCoordinate2D
    
    var body: some View {
        NavigationStack{
            ZStack{
                mapView
                if let details = meal.restaurantDetails {
                    overlayView(title: details.title, subTitle: details.address)
                }
            }
            .toolbar{
                ToolbarItem(placement: .topBarLeading) {
                    Button("Dismiss"){
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func overlayViewText(title: String, subTitle: String) -> some View {
        VStack(alignment: .center, spacing: 5){
            Text("\(title)")
                .font(.headline)
            DividerElement(removePadding: true)
            Text("\(subTitle)")
                .font(.callout)
                .fontWeight(.light)
        }
        .padding()
    }
    
    private func overlayView(title: String, subTitle: String) -> some View {
        VStack{
            Spacer()
            overlayViewText(title: title, subTitle: subTitle)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .foregroundStyle(.regularMaterial)
                        .overlay(alignment: .center, content: {
                            overlayViewText(title: title, subTitle: subTitle)
                        })
                        .shadow(color: .primary.opacity(0.075), radius: 6, x: 0, y: 0)
                }
                .padding()
        }
    }
    
    private var mapView: some View {
        Map(
            position: .constant(
                .region(
                    MKCoordinateRegion(
                        center: map,
                        span: MKCoordinateSpan(
                            latitudeDelta: 0.05,
                            longitudeDelta: 0.05
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
                        .font(.title)
                        .padding()
                }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
            MapPitchToggle()
            MapUserLocationButton()
        }
    }
}

//#Preview {
//    MapViewModal()
//}
