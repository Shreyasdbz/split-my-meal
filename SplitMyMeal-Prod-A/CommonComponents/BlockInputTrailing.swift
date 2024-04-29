//
//  BlockInputTrailing.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/28/24.
//

import SwiftUI

struct BlockInputTrailing: View {

    @State var placeholder: String
    @State var short: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .overlay(alignment: .center) {
                Text("\(placeholder)")
                    .font(.title)
            }
            .foregroundStyle(Color.init(uiColor: .systemGray6))
            .frame(width: 120, height: short == true ? 60 : 90, alignment: .center)
    }
}

//#Preview {
//    BlockInputTrailing()
//}
