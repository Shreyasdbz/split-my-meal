//
//  InfoSectionView.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/24/24.
//

import SwiftUI
import MapKit
import PhotosUI
import SwiftUIImageViewer

struct InfoSectionView: View {
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isImagePresented = false
    
    let meal: Meal
    var onMapClick: () -> ()
    var onTaxClick: () -> ()
    var onTipClick: () -> ()
    
    private var taxPercentage: Double? {
        return meal.taxPercentage
    }
    private var taxAmount: Double? {
        return meal.taxAmount
    }
    
    var body: some View {
        VStack(spacing: 10){
            mapSection
            receiptSection
            taxSection
            tipSection
        }
        .padding(.top)
        .padding(.horizontal)
        .fullScreenCover(isPresented: $isImagePresented) {
            if let imageData = meal.receiptPhoto, let _ = UIImage(data: imageData) {
                
                SwiftUIImageViewer(image: Image(data: imageData) ?? Image("spinner3D"))
                    .overlay(alignment: .topTrailing) {
                        closeButton
                    }
            }
            
        }
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
            HStack{
                LabelWithCaptionLeading(
                    label: "Receipt",
                    caption: meal.receiptPhoto == nil ? "Attach a photo" : "Tap to view"
                )
                Spacer()
                if let imageData = meal.receiptPhoto, let uiImage = UIImage(data: imageData) {
                    Button{
                        isImagePresented = true
                    } label: {
                        Image(uiImage: uiImage)
                            .resizable()
                            .frame(width: 120, height: 90, alignment: .center)
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                } else {
                    BlockInputTrailing(placeholder: "🧾")
                }
                
            }
        }
    }
    
    private var taxSection: some View {
        var taxDisplayValue: String = "🗳️"
        var useSmallValueTax: Bool = false
        
        if let taxP = meal.taxPercentage {
            taxDisplayValue = "\((taxP/100).formatted(.percent))"
            useSmallValueTax = true
        }
        if let taxA = meal.taxAmount {
            taxDisplayValue = "\(taxA.formatted(.currency(code: "USD")))"
            useSmallValueTax = true
        }
        
        return(
            VStack{
                BlockInputFieldShort(
                    label: "Tax",
                    placeholder: taxDisplayValue,
                    useSmallValue: useSmallValueTax
                ) {
                    onTaxClick()
                }
            }
        )
    }
    
    private var tipSection: some View {
        var tipDisplayValue: String = "✨"
        var useSmallValueTip: Bool = false
        
        if let tipP = meal.tipPercentage {
            tipDisplayValue = "\((tipP/100).formatted(.percent))"
            useSmallValueTip = true
        }
        if let tipA = meal.tipAmount {
            tipDisplayValue = "\(tipA.formatted(.currency(code: "USD")))"
            useSmallValueTip = true
        }
        
        return(
            VStack{
                BlockInputFieldShort(
                    label: "Tip",
                    placeholder: tipDisplayValue,
                    useSmallValue: useSmallValueTip
                ) {
                    onTipClick()
                }
            }
        )
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
    
    private var closeButton: some View {
        Button {
            isImagePresented = false
        } label: {
            Image(systemName: "xmark")
                .font(.title2)
                .fontWeight(.semibold)
        }
        .buttonStyle(.bordered)
        .clipShape(Circle())
        .tint(.gray)
        .padding()
    }
}

//#Preview {
//    InfoSectionView()
//}
