//
//  LabelWithCaptionLeading.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/26/24.
//

import SwiftUI

struct LabelWithCaptionLeading: View {

    let label: String
    let caption: String
    @State var useSmallCaption: Bool = false

    var body: some View {
        VStack(alignment: .leading){
            Text("\(label)")
                .font(.footnote)
                .fontWeight(.semibold)
                .textCase(.uppercase)
            Text("\(caption)")
                .font(!useSmallCaption ? .body : .callout)
                .foregroundStyle(.secondary)
                .fontWeight(!useSmallCaption ? .light : .regular)
        }
    }
}

//#Preview {
//    LabelWithCaptionLeading(label: "Price", caption: "Set the price for your item")
//}
