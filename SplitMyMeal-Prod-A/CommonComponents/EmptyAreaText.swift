//
//  EmptyAreaText.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/24/24.
//

import SwiftUI


enum EmptyTextFor: String {
    case Meals = "Meal"
    case Items = "Item"
    case People = "Person"
}


struct EmptyAreaText: View {
    
    let emptyTextFor: EmptyTextFor

    var body: some View {
        HStack{
            Spacer()
            VStack{
                Text("Use the add button to")
                    .foregroundStyle(.secondary)
                Text("add a new \(emptyTextFor.rawValue)")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

//#Preview {
//    EmptyAreaText()
//}
