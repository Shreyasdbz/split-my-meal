//
//  DividerElement.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/24/24.
//

import SwiftUI

struct DividerElement: View {
    
    @State var removePadding: Bool = false
    @State var customColor: Color? = nil
    
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .foregroundStyle(customColor ?? Color(uiColor: .systemGray4))
            .frame(height: 0.5, alignment: .center)
            .padding(removePadding == true ? 0 : 15)
    }
}

#Preview {
    DividerElement()
}
