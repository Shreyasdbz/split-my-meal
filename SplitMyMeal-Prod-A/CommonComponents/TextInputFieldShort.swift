//
//  TextInputFieldShort.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/25/24.
//

import SwiftUI

struct TextInputFieldShort: View {
    
    let label: String
    let placeholder: String
    let caption: String
    let prefix: String?
    
    @State var inputValue: Binding<String>
    @State var showError: Bool

    var body: some View {
        HStack{
            VStack(alignment: .leading){
                Text("\(label)")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    Text("\(caption)")
                    .foregroundStyle(.secondary)
                        .fontWeight(.light)
            }
            
            Spacer()

            TextField("\(placeholder)", value: $inputValue)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .background(Color.init(uiColor: .systemGray6))
                .overlay(showError == true ?
                         RoundedRectangle(cornerRadius: 8)
                    .stroke(.red.opacity(0.7), lineWidth: 0.7)
                         : nil
                )
                .cornerRadius(8)
                .textContentType(.username)
        }
    }
}

//#Preview {
//    TextInputFieldShort()
//}
