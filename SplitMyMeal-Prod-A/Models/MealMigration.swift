import Foundation
import SwiftData

/// The shipped 2024 storage schema, including its incorrect restaurant inverse, retained solely for migration.
enum MealSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [Meal.self, MealItem.self, MealPerson.self, RestaurantDetails.self] }

    @Model final class Meal {
        var id: String = UUID().uuidString
        var createdAt: Date = Date()
        var modifiedAt: Date = Date()
        var title: String = ""
        var charm: String = "🍱"
        var taxPercentage: Double?
        var taxAmount: Double?
        var tipPercentage: Double?
        var tipAmount: Double?
        var items: [MealItem]? = [MealItem]()
        var people: [MealPerson]? = [MealPerson]()
        var restaurantDetails: RestaurantDetails?
        @Attribute(.externalStorage) var receiptPhoto: Data?
        init() {}
    }
    @Model final class MealItem {
        @Relationship(inverse: \Meal.items) var relatedMeal: Meal?
        var id: String = UUID().uuidString
        var name: String = ""
        var price: Double = 0
        var category: MealItemCategory = MealItemCategory.Snack
        var consumerIds: [String] = []
        init() {}
    }
    @Model final class MealPerson {
        @Relationship(inverse: \Meal.people) var relatedMeal: Meal?
        var id: String = UUID().uuidString
        var name: String = ""
        var itemIds: [String] = []
        init() {}
    }
    @Model final class RestaurantDetails {
        @Relationship(inverse: \Meal.items) var relatedMeal: Meal?
        var id: String = UUID().uuidString
        var title: String = ""
        var address: String = ""
        var lattitude: Double = 0
        var longitude: Double = 0
        init() {}
    }
}

/// Corrects only relationship metadata; all stored field names, optionality, and types match the shipped schema.
enum MealSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    static var models: [any PersistentModel.Type] { [Meal.self, MealItem.self, MealPerson.self, RestaurantDetails.self] }
}

enum MealMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [MealSchemaV1.self, MealSchemaV2.self] }
    static var stages: [MigrationStage] { [.lightweight(fromVersion: MealSchemaV1.self, toVersion: MealSchemaV2.self)] }
}
