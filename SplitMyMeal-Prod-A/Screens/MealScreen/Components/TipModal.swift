//
//  TipModal.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 7/15/24.
//

import SwiftUI

enum TipInputField: Int, Hashable {
    case percentage
    case amount
}

struct TipModal: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var meal: Meal
    @State private var selectedViewType: TaxTipViewType
    @State private var isNew: Bool
    @State private var percentageEditValue: Double?
    @State private var amountEditValue: Double?
    
    @FocusState private var focusedField: TaxInputField?
    
    private var onSave: (_ percentage: Double?, _ amount: Double?, _ delete: Bool?) -> ()
    
    init(
        meal: Meal,
        onSave: @escaping (_ percentage: Double?, _ amount: Double?, _ delete: Bool?) -> ()
    ){
        self.meal = meal
        self.onSave = onSave
        
        if let percentage = meal.tipPercentage {
            // check for percentage
            self.isNew = false
            self.selectedViewType = .percentage
            self.percentageEditValue = percentage
            // calculate amount
            let mealTotal = getMealTotalPreTip(meal: meal)
                if(mealTotal != 0){
                    self.amountEditValue = (percentage * mealTotal) / 100
                }
            
        } else {
            if let amount = meal.tipAmount {
                // check for amount
                self.isNew = false
                self.selectedViewType = .amount
                self.amountEditValue = amount
                // calculate percent
                let mealTotal = getMealTotalPreTip(meal: meal) 
                    if(mealTotal != 0){
                        self.percentageEditValue = (amount/mealTotal)*100
                    }
                
            } else {
                // nothing found
                self.isNew = true
                self.percentageEditValue = 0.00
                self.amountEditValue = 0.00
                self.selectedViewType = .percentage
            }
        }
        
    }
    
    var body: some View {
        NavigationStack{
            VStack{
                navTitle
                TaxTipPercentAmountSlider(selectedViewType: $selectedViewType)
                if(selectedViewType == .percentage){
                    percentageInputSection
                } else {
                    amountInputSection
                }
                deleteButtonSection
                Spacer()
            }
            .toolbar{
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    
                    Button("Done") {
                        focusedField = nil
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel"){
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save"){
                        if(selectedViewType == .amount){
                            onSave(nil, amountEditValue, nil)
                        } else {
                            onSave(percentageEditValue, nil, nil)
                        }
                    }
                }
            }
        }
        .background(.thinMaterial)
    }
    
    private var navTitle: some View {
        HStack{
            Text("✨ Tip")
                .font(.title3)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.horizontal)
    }
    
    private var percentInputBlock: some View {
        HStack(spacing: 5){
            if let tipP = meal.tipPercentage {
                TextField("\(tipP, specifier: "%.2f")",
                          value: $percentageEditValue,
                          format: .number
                )
                    .submitLabel(.done)
                    .frame(width: 65)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    .background(Color.init(uiColor: .systemGray6))
                    .cornerRadius(8)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .percentage)
                    .onChange(of: focusedField, { oldValue, newValue in
                        if(newValue == .percentage && percentageEditValue == 0.0){
                            // Entering price input
                            $percentageEditValue.wrappedValue = nil
                        }
                    })

            } else {
                if let tipA = meal.tipAmount {
                    TextField("\(tipA, specifier: "%.2f")",
                              value: $percentageEditValue,
                              format: .number
                    )
                        .submitLabel(.done)
                        .frame(width: 65)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)
                        .background(Color.init(uiColor: .systemGray6))
                        .cornerRadius(8)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .percentage)
                        .onChange(of: focusedField, { oldValue, newValue in
                            if(newValue == .percentage && percentageEditValue == 0.0){
                                // Entering price input
                                $percentageEditValue.wrappedValue = nil
                            }
                        })
                } else {
                    TextField("0.0",
                              value: $percentageEditValue,
                              format: .number
                    )
                        .submitLabel(.done)
                        .frame(width: 65)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)
                        .background(Color.init(uiColor: .systemGray6))
                        .cornerRadius(8)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .percentage)
                        .onChange(of: focusedField, { oldValue, newValue in
                            if(newValue == .percentage && percentageEditValue == 0.0){
                                // Entering price input
                                $percentageEditValue.wrappedValue = nil
                            }
                        })
                }

            }
            Text("%")
                .font(.headline)
                .fontWeight(.light)
                .foregroundStyle(.secondary)
            
        }
    }
    
    private var amountInputBlock: some View {
        HStack(spacing: 5){
            Text("$")
                .font(.headline)
                .fontWeight(.light)
                .foregroundStyle(.secondary)
            TextField("\(meal.tipAmount ?? 0.0)", value: $amountEditValue, format: .number)
                .submitLabel(.done)
                .frame(width: 65)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .background(Color.init(uiColor: .systemGray6))
                .cornerRadius(8)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .amount)
                .onChange(of: focusedField, { oldValue, newValue in
                    if(newValue == .amount && amountEditValue == 0.0){
                        // Entering price input
                        $amountEditValue.wrappedValue = nil
                    }
                })
        }
    }
    
    private var percentageInputSection: some View {
        HStack{
            LabelWithCaptionLeading(label: "Tip Percentage", caption: "% of the total amount")
            Spacer()
            percentInputBlock
        }
        .padding()
    }
    
    private var amountInputSection: some View {
        HStack{
            LabelWithCaptionLeading(label: "Tip Amount", caption: "Amount in $")
            Spacer()
            amountInputBlock
        }
        .padding()
    }
    
    private var deleteButtonSection: some View {
        HStack{
            Spacer()
            Button("Clear", role: .destructive){
                onSave(nil, nil, true)
            }
            Spacer()
        }
    }
}

//#Preview {
//    TaxModal()
//}
