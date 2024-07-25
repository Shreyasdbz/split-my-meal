//
//  Formatter.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 7/20/24.
//

import Foundation

public extension NumberFormatter {
        
    static let twoDigitFormat: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 4
        nf.maximumFractionDigits = 4
        return nf
    }()

    func string(from obj: Double, missing: String = "") -> String {
        string(from: NSNumber(value: obj)) ?? missing
    }
}
