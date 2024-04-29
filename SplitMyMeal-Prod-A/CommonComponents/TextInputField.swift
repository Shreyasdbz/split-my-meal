//
//  TextInputField.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/24/24.
//

import SwiftUI

struct TextInputField: View {
    
    let label: String
    let placeholder: String
    
    @State var inputString: Binding<String>
    @State var showError: Bool
    @State var useLighterBg: Bool = false

    var body: some View {
        VStack(spacing: 5.0){
            HStack{
                Text("\(label)")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                Spacer()
            }
            TextField("\(placeholder)", text: inputString)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .background(
                    Color.init(
                        uiColor: useLighterBg == true ? .systemGray5 : .systemGray6
                    )
                )
                .cornerRadius(8)
                .overlay(showError == true ?
                         RoundedRectangle(cornerRadius: 8)
                    .stroke(.red.opacity(0.7), lineWidth: 1)
                         : nil
                )
                .textInputAutocapitalization(.words)
        }
    }
}

//#Preview {
//    TextInputField()
//}
