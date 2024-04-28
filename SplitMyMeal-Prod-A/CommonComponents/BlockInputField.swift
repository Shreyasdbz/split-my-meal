//
//  BlockInputField.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/24/24.
//

import SwiftUI

struct BlockInputField: View {

    let label: String
    let caption: String
    let placeholder: String
    var onClick: () -> ()

    var body: some View {
        HStack{
            LabelWithCaptionLeading(label: label, caption: caption)
            Spacer()
            Button{
                onClick()
            } label: {
                RoundedRectangle(cornerRadius: 12)
                    .overlay(alignment: .center) {
                        Text("\(placeholder)")
                            .font(.title)
                    }
                    .foregroundStyle(Color.init(uiColor: .systemGray6))
                    .frame(width: 120, height: 90, alignment: .center)
            }
        }
    }
}

//#Preview {
//    BlockInputField()
//}
