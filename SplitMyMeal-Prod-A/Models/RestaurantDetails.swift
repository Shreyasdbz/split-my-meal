import Foundation
import SwiftData
import CoreLocation

/// Restaurant coordinates in degrees and display metadata owned by one meal. The legacy lattitude spelling is preserved on disk.
@Model
class RestaurantDetails {
    
    @Relationship(inverse: \Meal.restaurantDetails)
    var relatedMeal: Meal?
    
    var id: String = UUID().uuidString
    var title: String = ""
    var address: String = ""
    var lattitude: CLLocationDegrees = 0
    var longitude: CLLocationDegrees = 0
    
    init() {}
}
