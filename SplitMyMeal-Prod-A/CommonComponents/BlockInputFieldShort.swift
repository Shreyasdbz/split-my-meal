//
//  BlockInputFieldShort.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/24/24.
//

import SwiftUI

struct BlockInputFieldShort: View {

    let label: String
    let placeholder: String
    var useSmallValue: Bool = false
    var onClick: () -> ()

    var body: some View {
        HStack{
            VStack(alignment: .leading){
                Text("\(label)")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
            }
            Spacer()
            Button{
                onClick()
            } label: {
                RoundedRectangle(cornerRadius: 12)
                    .foregroundStyle(Color.init(uiColor: .systemGray6))
                    .frame(width: 120, height: 60, alignment: .center)
                    .overlay(alignment: .center) {
                        Text(placeholder)
                            .font(useSmallValue == true ? .headline : .title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }
}

//#Preview {
//    BlockInputFieldShort()
//}
