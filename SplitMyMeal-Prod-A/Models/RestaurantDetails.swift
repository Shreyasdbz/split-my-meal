//
//  MapData.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/28/24.
//

import Foundation
import SwiftData
import MapKit


struct SearchCompletions: Identifiable {
    let id = UUID()
    let title: String
    let subTitle: String
}


struct SearchResult: Identifiable, Hashable {
    let id = UUID()
    let location: CLLocationCoordinate2D
    
    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@Model
class RestaurantDetails {
    
    @Relationship(inverse: \Meal.items)
    var relatedMeal: Meal?
    
    var id: String = UUID().uuidString
    var title: String?
    var address: String?
    var lattitude: CLLocationDegrees?
    var longitude: CLLocationDegrees?
    
    init(){
        //
    }
}
