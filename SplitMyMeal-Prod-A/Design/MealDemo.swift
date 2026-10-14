#if DEBUG
import SwiftData
import UIKit

/// Fictional data for UI tests and screenshots; never runs in a release build.
@MainActor enum MealDemo {
    @discardableResult static func seed(in context: ModelContext) throws -> Meal {
        let meal = Meal()
        meal.id = "demo-meal"
        meal.title = "Dinner at Juniper"
        meal.charm = "🍜"
        meal.createdAt = Date(timeIntervalSince1970: 1_791_331_200)
        meal.modifiedAt = meal.createdAt
        context.insert(meal)
        let alex = MealPerson(relatedMeal: meal)
        alex.id = "alex"; alex.name = "Alex"
        let jordan = MealPerson(relatedMeal: meal)
        jordan.id = "jordan"; jordan.name = "Jordan"
        let sam = MealPerson(relatedMeal: meal)
        sam.id = "sam"; sam.name = "Sam"
        context.insert(alex); context.insert(jordan); context.insert(sam)
        meal.people = [alex, jordan, sam]
        let entries: [(String, Double, MealItemCategory, [MealPerson])] = [
            ("Edamame", 9, .Snack, [alex, jordan, sam]),
            ("Miso ramen", 19, .Entree, [alex]),
            ("Spicy ramen", 21, .Entree, [jordan]),
            ("Mushroom ramen", 18, .Entree, [sam]),
            ("Matcha ice cream", 8, .Dessert, [alex, sam]),
            ("Iced tea", 12, .Drink, [alex, jordan, sam])
        ]
        for (index, entry) in entries.enumerated() {
            let item = MealItem(relatedMeal: meal, category: entry.2)
            item.id = "demo-item-\(index)"; item.name = entry.0; item.price = entry.1
            item.consumerIds = entry.3.map(\.id)
            context.insert(item)
            for person in entry.3 { person.itemIds.append(item.id) }
        }
        meal.taxPercentage = 8.875
        meal.tipPercentage = 20
        let receipt = demoReceipt()
        meal.receiptPhoto = receipt
        try receipt.write(to: URL.documentsDirectory.appending(path: "UITesting-receipt.jpg"), options: .atomic)
        try demoReceipt(replacement: true).write(to: URL.documentsDirectory.appending(path: "UITesting-replacement.jpg"), options: .atomic)
        let restaurant = RestaurantDetails()
        restaurant.title = "Juniper · sample restaurant"
        restaurant.address = "Fictional dinner for app screenshots"
        restaurant.lattitude = 40.7411; restaurant.longitude = -73.9897
        restaurant.relatedMeal = meal
        context.insert(restaurant)
        meal.restaurantDetails = restaurant
        try context.save()
        return meal
    }

    /// Separate fictional storefront data; the established test fixtures remain unchanged.
    @discardableResult static func seedStore(in context: ModelContext) throws -> Meal {
        let meal = try seed(in: context)
        meal.restaurantDetails?.title = "Juniper"
        meal.restaurantDetails?.address = "New York, NY"
        meal.receiptPhoto = storeReceipt()
        let history: [(String, String, [String], [(String, Double, MealItemCategory)])] = [
            ("Lunch at Grove", "🥗", ["Alex", "Sam"], [("Garden salad", 14, .Entree), ("Grilled sandwich", 16, .Entree)]),
            ("Weekend brunch", "🥞", ["Jordan", "Riley", "Cam"], [("Pancakes", 18, .Entree), ("Avocado toast", 15, .Entree), ("Coffee", 12, .Drink)])
        ]
        for (index, entry) in history.enumerated() {
            let previous = Meal()
            previous.id = "store-history-\(index)"
            previous.title = entry.0
            previous.charm = entry.1
            previous.createdAt = meal.createdAt.addingTimeInterval(-Double(index + 1) * 86_400)
            previous.modifiedAt = previous.createdAt
            context.insert(previous)
            let people = entry.2.enumerated().map { personIndex, name in
                let person = MealPerson(relatedMeal: previous)
                person.id = "store-history-\(index)-person-\(personIndex)"
                person.name = name
                context.insert(person)
                return person
            }
            previous.people = people
            for (itemIndex, itemEntry) in entry.3.enumerated() {
                let item = MealItem(relatedMeal: previous, category: itemEntry.2)
                item.id = "store-history-\(index)-item-\(itemIndex)"
                item.name = itemEntry.0
                item.price = itemEntry.1
                item.consumerIds = people.map(\.id)
                context.insert(item)
                for person in people { person.itemIds.append(item.id) }
            }
            previous.taxPercentage = 8.875
            previous.tipPercentage = 20
        }
        try context.save()
        return meal
    }

    private static func storeReceipt() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 650, height: 960)).jpegData(withCompressionQuality: 0.9) { output in
            UIColor.white.setFill()
            output.fill(CGRect(x: 0, y: 0, width: 650, height: 960))
            let text = "JUNIPER\n\nDinner for three\n\nEdamame                    $9.00\nMiso ramen                $19.00\nSpicy ramen               $21.00\nMushroom ramen            $18.00\nMatcha ice cream           $8.00\nIced tea                  $12.00\n\nSubtotal                  $87.00\nTax                        $7.72\nTip                       $18.94\nTOTAL                    $113.66\n\nThank you for dining with us"
            (text as NSString).draw(in: CGRect(x: 45, y: 55, width: 560, height: 850), withAttributes: [.font: UIFont.monospacedSystemFont(ofSize: 25, weight: .regular), .foregroundColor: UIColor.black])
        }
    }

    private static func demoReceipt(replacement: Bool = false) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 650, height: 960))
        return renderer.jpegData(withCompressionQuality: 0.9) { output in
            UIColor.white.setFill(); output.fill(CGRect(x: 0, y: 0, width: 650, height: 960))
            let text = "JUNIPER\nSAMPLE RECEIPT\n\nEdamame                    $9.00\nMiso ramen                $19.00\nSpicy ramen               $21.00\nMushroom ramen            $18.00\nMatcha ice cream           $8.00\nIced tea                  $12.00\n\nSubtotal                  $87.00\nTax                        $7.72\nTip                       $18.94\nTOTAL                    $113.66\n\nFictional data for app testing"
            let receiptText = replacement ? text.replacingOccurrences(of: "SAMPLE RECEIPT", with: "REPLACEMENT RECEIPT") : text
            (receiptText as NSString).draw(in: CGRect(x: 45, y: 55, width: 560, height: 850), withAttributes: [.font: UIFont.monospacedSystemFont(ofSize: 25, weight: .regular), .foregroundColor: UIColor.black])
        }
    }
}
#endif
