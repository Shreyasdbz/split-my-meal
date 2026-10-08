import XCTest
import SwiftData
import CoreData
@testable import SplitMyMeal_Prod_A

@MainActor
final class MealStoreTests: XCTestCase {
    private func container(at url: URL? = nil) throws -> ModelContainer {
        let schema = Schema(versionedSchema: MealSchemaV2.self)
        let config: ModelConfiguration
        if let url { config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none) }
        else { config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none) }
        return try ModelContainer(for: schema, migrationPlan: MealMigrationPlan.self, configurations: [config])
    }

    func testNamesRequireVisibleContentWithoutChangingUnicodeNames() throws {
        let container = try container()
        let context = container.mainContext
        let meal = Meal()
        try MealStore.saveMeal(meal, title: "Original", charm: "🍱", restaurant: nil, receiptPhoto: nil, isNew: true, in: context)
        for name in ["\u{2060}", "\u{FEFF}", " \u{2060}\u{FEFF} ", "\u{0000}\u{0007}", "\n\t"] {
            XCTAssertThrowsError(try MealStore.saveMeal(meal, title: name, charm: "🍱", restaurant: nil, receiptPhoto: nil, in: context))
            XCTAssertThrowsError(try MealStore.savePerson(MealPerson(relatedMeal: nil), meal: meal, name: name, itemIDs: [], isNew: true, in: context))
            XCTAssertThrowsError(try MealStore.saveItem(MealItem(relatedMeal: nil, category: .Snack), meal: meal, name: name, price: 1, category: .Snack, consumerIDs: [], isNew: true, in: context))
            XCTAssertEqual(meal.title, "Original")
            XCTAssertEqual(meal.people?.count, 0)
            XCTAssertEqual(meal.items?.count, 0)
            XCTAssertFalse(context.hasChanges)
        }
        for name in ["東京", "العشاء", "👨‍👩‍👧‍👦", "A\u{2060}B", "\u{2060}東京\u{FEFF}"] {
            try MealStore.saveMeal(meal, title: name, charm: "🍱", restaurant: nil, receiptPhoto: nil, in: context)
            XCTAssertEqual(meal.title, name)
        }
        let person = MealPerson(relatedMeal: nil)
        try MealStore.savePerson(person, meal: meal, name: "ليلى", itemIDs: [], isNew: true, in: context)
        XCTAssertEqual(person.name, "ليلى")
        let item = MealItem(relatedMeal: nil, category: .Entree)
        try MealStore.saveItem(item, meal: meal, name: "👩🏽‍🍳", price: 1, category: .Entree, consumerIDs: [person.id], isNew: true, in: context)
        XCTAssertEqual(item.name, "👩🏽‍🍳")
        XCTAssertEqual(item.consumerIds, [person.id])
    }

    func testSaveAssignmentsAndDeletionAreConsistent() throws {
        let container = try container()
        let context = container.mainContext
        let meal = Meal()
        try MealStore.saveMeal(meal, title: " Dinner ", charm: "🍱", restaurant: nil, receiptPhoto: nil, isNew: true, in: context)
        let a = MealPerson(relatedMeal: nil)
        let b = MealPerson(relatedMeal: nil)
        try MealStore.savePerson(a, meal: meal, name: "A", itemIDs: [], isNew: true, in: context)
        try MealStore.savePerson(b, meal: meal, name: "B", itemIDs: [], isNew: true, in: context)
        let item = MealItem(relatedMeal: nil, category: .Entree)
        try MealStore.saveItem(item, meal: meal, name: "Noodles", price: 10.005, category: .Entree, consumerIDs: [a.id, a.id], isNew: true, in: context)
        XCTAssertEqual(meal.title, "Dinner")
        XCTAssertEqual(item.price, 10.01)
        XCTAssertEqual(item.consumerIds, [a.id])
        XCTAssertEqual(a.itemIds, [item.id])
        try MealStore.savePerson(b, meal: meal, name: "B", itemIDs: [item.id], in: context)
        XCTAssertEqual(Set(item.consumerIds), Set([a.id, b.id]))
        try MealStore.deletePerson(a, in: context)
        XCTAssertEqual(item.consumerIds, [b.id])
        try MealStore.deleteItem(item, in: context)
        XCTAssertEqual(b.itemIds, [])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealItem>()), 0)
    }

    func testInvalidInputsDoNotMutateSavedState() throws {
        let container = try container()
        let context = container.mainContext
        let meal = Meal()
        try MealStore.saveMeal(meal, title: "Saved", charm: "🍱", restaurant: nil, receiptPhoto: Data([1, 2, 3]), isNew: true, in: context)
        XCTAssertThrowsError(try MealStore.saveMeal(meal, title: " \n ", charm: "🍱", restaurant: nil, receiptPhoto: nil, in: context))
        XCTAssertEqual(meal.title, "Saved")
        XCTAssertEqual(meal.receiptPhoto, Data([1, 2, 3]))
        for value in [Double.nan, .infinity, -1, Money.maximumAmount + 1] {
            XCTAssertThrowsError(try MealStore.setTax(meal, percentage: nil, amount: value, in: context))
            XCTAssertNil(meal.taxAmount)
        }
        let item = MealItem(relatedMeal: nil, category: .Entree)
        XCTAssertThrowsError(try MealStore.saveItem(item, meal: meal, name: "Item", price: 10, category: .Entree, consumerIDs: ["absent"], isNew: true, in: context))
        XCTAssertNil(item.modelContext)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealItem>()), 0)
    }

    func testMealAndOwnedRowsSurviveDiskReopenAndDeleteTogether() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("meals.store")
        try autoreleasepool {
            let container = try container(at: url)
            let context = container.mainContext
            let meal = Meal()
            try MealStore.saveMeal(meal, title: "Disk meal", charm: "🍜", restaurant: RestaurantDraft(title: "Cafe", address: "1 Main St", latitude: 40.7, longitude: -74), receiptPhoto: Data(repeating: 7, count: 100_000), isNew: true, in: context)
            let person = MealPerson(relatedMeal: nil)
            try MealStore.savePerson(person, meal: meal, name: "Alex", itemIDs: [], isNew: true, in: context)
            try MealStore.saveItem(MealItem(relatedMeal: nil, category: .Entree), meal: meal, name: "Pasta", price: 20, category: .Entree, consumerIDs: [person.id], isNew: true, in: context)
        }
        try autoreleasepool {
            let reopened = try container(at: url)
            let context = reopened.mainContext
            let meal = try XCTUnwrap(context.fetch(FetchDescriptor<Meal>()).first)
            XCTAssertEqual(meal.title, "Disk meal")
            XCTAssertEqual(meal.receiptPhoto?.count, 100_000)
            XCTAssertEqual(meal.restaurantDetails?.title, "Cafe")
            XCTAssertTrue(meal.restaurantDetails?.relatedMeal === meal)
            XCTAssertEqual(meal.items?.count, 1)
            XCTAssertEqual(meal.people?.count, 1)
            XCTAssertEqual(MealAmounts(meal: meal).totalCents, 2000)
            try MealStore.deleteMeal(meal, in: context)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<Meal>()), 0)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealItem>()), 0)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealPerson>()), 0)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<RestaurantDetails>()), 0)
        }
    }

    func testLegacyFixtureRetainsOriginal2024EntityHashes() throws {
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Legacy26Fixture", withExtension: "bundle"))
        let url = fixture.appendingPathComponent("legacy.store")
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: url, options: nil)
        let hashes = try XCTUnwrap(metadata[NSStoreModelVersionHashesKey] as? [String: Data])
        // These hashes were read from a real store made by the unchanged, top-level models at git revision dd68cba.
        let expected = [
            "Meal": "9c830718ff94f16183ad811e9cce9c41db3cf5cbd7943922bd2928897f90b3af",
            "MealItem": "360198eac6090efb05d60ebf29609317aa2d4cec5d332a6c0590cfde684f8b0c",
            "MealPerson": "bed3d27e3d823c17da85b535b057dd201df7a3b5097ae1f93a35dfd56c6c12a4",
            "RestaurantDetails": "31e1e08764220949db8a0387e7601d9f3b934db78eb4b03faaf3cd2445c75cb7"
        ]
        XCTAssertEqual(hashes.mapValues { $0.map { String(format: "%02x", $0) }.joined() }, expected)
    }

    func testActualIOS26OriginalStoreUpgradesWithoutLosingExternalReceipt() throws {
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Legacy26Fixture", withExtension: "bundle"))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("legacy.store")
        try FileManager.default.copyItem(at: fixture.appendingPathComponent("legacy.store"), to: url)
        try FileManager.default.copyItem(at: fixture.appendingPathComponent("ExternalStorage"), to: directory.appendingPathComponent(".legacy_SUPPORT"))
        try autoreleasepool {
            let upgraded = try container(at: url)
            let meal = try XCTUnwrap(upgraded.mainContext.fetch(FetchDescriptor<Meal>()).first)
            XCTAssertEqual(meal.id, "fixture-meal-2024")
            XCTAssertEqual(meal.title, "2024 synthetic dinner")
            XCTAssertEqual(meal.receiptPhoto, Data(repeating: 4, count: 1_500_000))
            XCTAssertEqual(meal.items?.first?.name, "Pasta")
            XCTAssertEqual(meal.items?.first?.price, 12.34)
            XCTAssertEqual(meal.items?.first?.category, .Entree)
            XCTAssertEqual(meal.people?.first?.name, "Alex")
            XCTAssertTrue(meal.items?.first?.relatedMeal === meal)
            XCTAssertTrue(meal.people?.first?.relatedMeal === meal)
            XCTAssertTrue(meal.restaurantDetails?.relatedMeal === meal)
            XCTAssertEqual(meal.items?.first?.consumerIds, ["fixture-person"])
            XCTAssertEqual(meal.people?.first?.itemIds, ["fixture-item"])
            XCTAssertEqual(meal.restaurantDetails?.title, "Example cafe")
            XCTAssertEqual(meal.restaurantDetails?.address, "1 Example Street")
            XCTAssertEqual(meal.restaurantDetails?.lattitude, 40)
            XCTAssertEqual(meal.restaurantDetails?.longitude, -74)
            XCTAssertEqual(meal.taxPercentage, 8.875)
            XCTAssertEqual(meal.tipPercentage, 18)
            XCTAssertEqual(MealAmounts(meal: meal).totalCents, 1586)
            // Exercise editing real migrated records, not a V2 demo seed, before closing and reopening the store.
            let person = try XCTUnwrap(meal.people?.first)
            let item = try XCTUnwrap(meal.items?.first)
            try MealStore.saveMeal(meal, title: "Upgraded dinner", charm: "🍱", restaurant: RestaurantDraft(title: "Updated cafe", address: "2 Example Street", latitude: 41, longitude: -73), receiptPhoto: meal.receiptPhoto, in: upgraded.mainContext)
            try MealStore.savePerson(person, meal: meal, name: "Updated Alex", itemIDs: [], in: upgraded.mainContext)
            XCTAssertEqual(item.consumerIds, [])
            try MealStore.saveItem(item, meal: meal, name: "Updated pasta", price: 14.50, category: .Dessert, consumerIDs: [person.id], in: upgraded.mainContext)
            try MealStore.setTax(meal, percentage: nil, amount: 2, in: upgraded.mainContext)
            try MealStore.setTip(meal, percentage: 20, amount: nil, in: upgraded.mainContext)
        }
        try autoreleasepool {
            let reopened = try container(at: url)
            let meal = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<Meal>()).first)
            XCTAssertEqual(meal.title, "Upgraded dinner")
            XCTAssertEqual(meal.id, "fixture-meal-2024")
            XCTAssertEqual(meal.receiptPhoto, Data(repeating: 4, count: 1_500_000))
            XCTAssertEqual(meal.items?.count, 1)
            XCTAssertEqual(meal.people?.count, 1)
            XCTAssertEqual(meal.items?.first?.id, "fixture-item")
            XCTAssertEqual(meal.items?.first?.name, "Updated pasta")
            XCTAssertEqual(meal.items?.first?.price, 14.50)
            XCTAssertEqual(meal.items?.first?.category, .Dessert)
            XCTAssertEqual(meal.items?.first?.consumerIds, ["fixture-person"])
            XCTAssertEqual(meal.people?.first?.id, "fixture-person")
            XCTAssertEqual(meal.people?.first?.name, "Updated Alex")
            XCTAssertEqual(meal.people?.first?.itemIds, ["fixture-item"])
            XCTAssertTrue(meal.items?.first?.relatedMeal === meal)
            XCTAssertTrue(meal.people?.first?.relatedMeal === meal)
            XCTAssertTrue(meal.restaurantDetails?.relatedMeal === meal)
            XCTAssertEqual(meal.restaurantDetails?.title, "Updated cafe")
            XCTAssertEqual(meal.restaurantDetails?.address, "2 Example Street")
            XCTAssertEqual(meal.restaurantDetails?.lattitude, 41)
            XCTAssertEqual(meal.restaurantDetails?.longitude, -73)
            XCTAssertEqual(meal.taxAmount, 2)
            XCTAssertNil(meal.taxPercentage)
            XCTAssertEqual(meal.tipPercentage, 20)
            XCTAssertNil(meal.tipAmount)
            XCTAssertEqual(MealAmounts(meal: meal).totalCents, 1980)
        }
    }

    func testConfiguredReadOnlyStoreRejectsBeforeMutation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("readonly.store")
        try autoreleasepool {
            let container = try container(at: url)
            try MealStore.saveMeal(Meal(), title: "Read only", charm: "🍱", restaurant: nil, receiptPhoto: nil, isNew: true, in: container.mainContext)
        }
        try autoreleasepool {
            let schema = Schema(versionedSchema: MealSchemaV2.self)
            let configuration = ModelConfiguration(schema: schema, url: url, allowsSave: false, cloudKitDatabase: .none)
            let readonly = try ModelContainer(for: schema, migrationPlan: MealMigrationPlan.self, configurations: [configuration])
            let meal = try XCTUnwrap(readonly.mainContext.fetch(FetchDescriptor<Meal>()).first)
            XCTAssertThrowsError(try MealStore.saveMeal(meal, title: "Rejected", charm: "🍜", restaurant: nil, receiptPhoto: nil, in: readonly.mainContext))
            XCTAssertEqual(meal.title, "Read only")
            XCTAssertEqual(meal.charm, "🍱")
            XCTAssertFalse(readonly.mainContext.hasChanges)
        }
    }

    func testCommitRestoresGraphAfterNativeReadOnlySaveRejection() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("readonly.store")
        try autoreleasepool {
            let container = try container(at: url)
            let context = container.mainContext
            let meal = Meal()
            try MealStore.saveMeal(meal, title: "Before failure", charm: "🍱", restaurant: RestaurantDraft(title: "Before cafe", address: "1 Main", latitude: 40, longitude: -74), receiptPhoto: Data([1, 2, 3]), isNew: true, in: context)
            let person = MealPerson(relatedMeal: nil)
            try MealStore.savePerson(person, meal: meal, name: "Before person", itemIDs: [], isNew: true, in: context)
            try MealStore.saveItem(MealItem(relatedMeal: nil, category: .Entree), meal: meal, name: "Before item", price: 10, category: .Entree, consumerIDs: [person.id], isNew: true, in: context)
        }
        try autoreleasepool {
            let schema = Schema(versionedSchema: MealSchemaV2.self)
            let configuration = ModelConfiguration(schema: schema, url: url, allowsSave: false, cloudKitDatabase: .none)
            let readonly = try ModelContainer(for: schema, migrationPlan: MealMigrationPlan.self, configurations: [configuration])
            let meal = try XCTUnwrap(readonly.mainContext.fetch(FetchDescriptor<Meal>()).first)
            XCTAssertThrowsError(try MealStore.persist(meal: meal, in: readonly.mainContext) {
                meal.title = "After failure"
                meal.charm = "🍜"
                meal.receiptPhoto = Data([4])
                meal.restaurantDetails?.title = "After cafe"
            })
            XCTAssertEqual(meal.title, "Before failure")
            XCTAssertEqual(meal.charm, "🍱")
            XCTAssertEqual(meal.receiptPhoto, Data([1, 2, 3]))
            XCTAssertEqual(meal.restaurantDetails?.title, "Before cafe")
            let person = try XCTUnwrap(meal.people?.first)
            let item = try XCTUnwrap(meal.items?.first)
            XCTAssertThrowsError(try MealStore.persist(meal: meal, in: readonly.mainContext) {
                person.name = "After person"
                person.itemIds = []
                item.consumerIds = []
            })
            XCTAssertEqual(person.name, "Before person")
            XCTAssertEqual(person.itemIds, [item.id])
            XCTAssertEqual(item.consumerIds, [person.id])
            XCTAssertThrowsError(try MealStore.persist(meal: meal, in: readonly.mainContext) {
                meal.items = []
                person.itemIds = []
                readonly.mainContext.delete(item)
            })
            XCTAssertTrue(meal.items?.first === item)
            XCTAssertEqual(person.itemIds, [item.id])
            XCTAssertThrowsError(try MealStore.persist(meal: meal, in: readonly.mainContext) {
                readonly.mainContext.delete(item)
                readonly.mainContext.delete(person)
                if let restaurant = meal.restaurantDetails { readonly.mainContext.delete(restaurant) }
                readonly.mainContext.delete(meal)
            })
            XCTAssertFalse(meal.isDeleted)
            XCTAssertTrue(meal.items?.first === item)
            XCTAssertTrue(meal.people?.first === person)
            XCTAssertEqual(meal.restaurantDetails?.title, "Before cafe")
            XCTAssertEqual(meal.receiptPhoto, Data([1, 2, 3]))
        }
        try autoreleasepool {
            let reopened = try container(at: url)
            let baseline = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<Meal>()).first)
            XCTAssertEqual(baseline.title, "Before failure")
            XCTAssertEqual(baseline.receiptPhoto, Data([1, 2, 3]))
            XCTAssertEqual(baseline.items?.count, 1)
            XCTAssertEqual(baseline.people?.count, 1)
            try MealStore.saveMeal(baseline, title: "Successful retry", charm: "🍜", restaurant: RestaurantDraft(title: "Retry cafe", address: "3 Main", latitude: 42, longitude: -72), receiptPhoto: Data([5, 6]), in: reopened.mainContext)
        }
        try autoreleasepool {
            let reopened = try container(at: url)
            let meal = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<Meal>()).first)
            XCTAssertEqual(meal.title, "Successful retry")
            XCTAssertEqual(meal.receiptPhoto, Data([5, 6]))
            XCTAssertEqual(meal.restaurantDetails?.title, "Retry cafe")
            XCTAssertEqual(meal.items?.count, 1)
        }
    }

    func testDeletedMealCannotBeResurrectedFromStaleEditor() throws {
        let container = try container()
        let context = container.mainContext
        let meal = Meal()
        try MealStore.saveMeal(meal, title: "Deleted", charm: "🍱", restaurant: nil, receiptPhoto: nil, isNew: true, in: context)
        try MealStore.deleteMeal(meal, in: context)
        XCTAssertThrowsError(try MealStore.saveMeal(meal, title: "Resurrected", charm: "🍜", restaurant: nil, receiptPhoto: nil, in: context))
        XCTAssertThrowsError(try MealStore.saveMeal(meal, title: "Resurrected", charm: "🍜", restaurant: nil, receiptPhoto: nil, isNew: true, in: context))
        XCTAssertThrowsError(try MealStore.setTax(meal, percentage: 10, amount: nil, in: context))
        XCTAssertThrowsError(try MealStore.saveItem(MealItem(relatedMeal: nil, category: .Entree), meal: meal, name: "Item", price: 10, category: .Entree, consumerIDs: [], isNew: true, in: context))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Meal>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealItem>()), 0)
    }

    func testForeignContextAndCrossMealEditsAreRejected() throws {
        let container = try container()
        let context = container.mainContext
        let first = Meal(), second = Meal()
        for meal in [first, second] { try MealStore.saveMeal(meal, title: "Meal", charm: "🍱", restaurant: nil, receiptPhoto: nil, isNew: true, in: context) }
        let person = MealPerson(relatedMeal: nil)
        try MealStore.savePerson(person, meal: first, name: "Alex", itemIDs: [], isNew: true, in: context)
        let item = MealItem(relatedMeal: nil, category: .Entree)
        try MealStore.saveItem(item, meal: first, name: "Pasta", price: 10, category: .Entree, consumerIDs: [person.id], isNew: true, in: context)
        XCTAssertThrowsError(try MealStore.savePerson(person, meal: second, name: "Moved", itemIDs: [], in: context))
        XCTAssertThrowsError(try MealStore.saveItem(item, meal: second, name: "Moved", price: 20, category: .Drink, consumerIDs: [], in: context))
        let foreign = ModelContext(container)
        XCTAssertThrowsError(try MealStore.saveMeal(first, title: "Foreign", charm: "🍜", restaurant: nil, receiptPhoto: nil, in: foreign))
        XCTAssertThrowsError(try MealStore.deleteMeal(first, in: foreign))
        XCTAssertEqual(person.name, "Alex")
        XCTAssertEqual(item.name, "Pasta")
        XCTAssertTrue(person.relatedMeal === first)
        XCTAssertTrue(item.relatedMeal === first)
        XCTAssertTrue(second.items?.isEmpty ?? true)
        XCTAssertTrue(second.people?.isEmpty ?? true)
    }

    func testCharmAcceptsOnePresentedEmojiAndRejectsText() throws {
        let container = try container()
        let context = container.mainContext
        for charm in ["🍱", "👨‍👩‍👧‍👦", "🇺🇸", "1️⃣", "1⃣", "❤️", "  🍜  "] {
            let meal = Meal()
            try MealStore.saveMeal(meal, title: "Meal", charm: charm, restaurant: nil, receiptPhoto: nil, isNew: true, in: context)
            XCTAssertEqual(meal.charm, charm.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let before = try context.fetchCount(FetchDescriptor<Meal>())
        let oversizedGrapheme = "🍱" + String(repeating: "\u{0301}", count: 1000)
        XCTAssertEqual(oversizedGrapheme.count, 1)
        XCTAssertFalse(MealStore.isValidCharm(oversizedGrapheme))
        XCTAssertEqual(mealDisplayCharm(oversizedGrapheme), "🍱")
        for charm in ["Cafe", "A", "1", "#", "🍱🍜", "🍱\n🍜", " ", String(repeating: "A", count: 1000), oversizedGrapheme] {
            let meal = Meal()
            XCTAssertThrowsError(try MealStore.saveMeal(meal, title: "Meal", charm: charm, restaurant: nil, receiptPhoto: nil, isNew: true, in: context))
            XCTAssertNil(meal.modelContext)
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Meal>()), before)
    }
}
