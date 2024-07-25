//
//  TaxTipPercentAmountSlider.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 5/14/24.
//

import SwiftUI


enum TaxTipViewType: String, CaseIterable, Identifiable {
    case percentage
    case amount
    
    var id: Self { self }
}


struct TaxTipPercentAmountSlider: View {
    
    @Binding var selectedViewType: TaxTipViewType
    
    var body: some View {
        Picker("", selection: $selectedViewType){
            Text("Percentage")
                .tag(TaxTipViewType.percentage)
            Text("Amount")
                .tag(TaxTipViewType.amount)
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 300)
    }
}

//#Preview {
//    TaxTipPercentAmountSlider()
//}
