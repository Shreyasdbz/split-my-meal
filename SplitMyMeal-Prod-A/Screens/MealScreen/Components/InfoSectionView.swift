//
//  InfoSectionView.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/24/24.
//

import SwiftUI

struct InfoSectionView: View {

    let meal: Meal

    var body: some View {
        VStack(spacing: 10){
            mapSection
            receiptSection
            taxSection
            tipSection
        }
        .padding(.horizontal)
    }
    
    private var mapSection: some View {
        VStack{
            BlockInputField(
                label: "Location",
                caption: "Select the restaurant",
                placeholder: "📍"
            ) {
                    //
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
}

//#Preview {
//    InfoSectionView()
//}
