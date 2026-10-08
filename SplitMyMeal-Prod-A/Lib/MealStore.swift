import Foundation
import SwiftData

/// A value draft isolates restaurant edits from the saved relationship until Save succeeds.
struct RestaurantDraft {
    var title: String
    var address: String
    var latitude: Double
    var longitude: Double

    init(title: String, address: String, latitude: Double, longitude: Double) {
        self.title = title
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ details: RestaurantDetails) {
        self.init(title: details.title, address: details.address, latitude: details.lattitude, longitude: details.longitude)
    }
}

/// Owns coupled local mutations and explicitly saves them. Editors keep value drafts until invoking this boundary.
/// A failed save rolls back and restores displayed baseline values, which older SwiftData runtimes may mark pending.
/// Callers retain their drafts and present the error; a retry or autosave only re-saves that unchanged baseline.
@MainActor
enum MealStore {
    enum ValidationError: LocalizedError {
        case name, charm, price, charge, location, assignment, unavailable, mealTotal, readOnly
        var errorDescription: String? {
            switch self {
            case .readOnly: return "This meal store is read-only. Close and reopen the app before editing."
            case .name: return "Enter a name with at least one visible character."
            case .charm: return "Choose one emoji for the meal."
            case .price: return "Enter a price from $0.01 to $1,000,000,000."
            case .charge: return "Enter a valid, nonnegative amount or percentage."
            case .location: return "This restaurant has an invalid location. Select another result."
            case .assignment: return "An assigned person or item no longer belongs to this meal. Reopen the editor and try again."
            case .unavailable: return "This meal, item, or person is no longer available. Close the editor and reopen it from the meal list."
            case .mealTotal: return "Keep the meal subtotal at or below $1,000,000,000."
            }
        }
    }

    /// Creates or updates meal details. Nil restaurant and receipt drafts intentionally remove those values.
    static func saveMeal(_ meal: Meal, title: String, charm: String, restaurant: RestaurantDraft?, receiptPhoto: Data?, isNew: Bool = false, in context: ModelContext) throws {
        try validateModel(meal, isNew: isNew, in: context)
        let name = try validName(title)
        let icon = try validCharm(charm)
        if let restaurant {
            guard restaurant.latitude.isFinite, restaurant.longitude.isFinite,
                  (-90...90).contains(restaurant.latitude), (-180...180).contains(restaurant.longitude) else { throw ValidationError.location }
        }
        try persist(meal: meal, in: context) {
            if meal.modelContext == nil { context.insert(meal) }
            meal.title = name
            meal.charm = icon
            meal.receiptPhoto = receiptPhoto
            if let restaurant {
                let details = meal.restaurantDetails ?? RestaurantDetails()
                if details.modelContext == nil { context.insert(details) }
                details.title = restaurant.title.trimmingCharacters(in: .whitespacesAndNewlines)
                details.address = restaurant.address.trimmingCharacters(in: .whitespacesAndNewlines)
                details.lattitude = restaurant.latitude
                details.longitude = restaurant.longitude
                meal.restaurantDetails = details
                details.relatedMeal = meal
            } else if let previous = meal.restaurantDetails {
                meal.restaurantDetails = nil
                context.delete(previous)
            }
            meal.modifiedAt = Date()
        }
    }

    /// Saves an item's cent-normalized price and authoritative consumer IDs, deriving each person's reverse index.
    static func saveItem(_ item: MealItem, meal: Meal, name: String, price: Double, category: MealItemCategory, consumerIDs: [String], isNew: Bool = false, in context: ModelContext) throws {
        try validateModel(meal, isNew: false, in: context)
        try validateModel(item, isNew: isNew, in: context)
        if !isNew, !(meal.items ?? []).contains(where: { $0 === item }) { throw ValidationError.assignment }
        let name = try validName(name)
        if let owner = item.relatedMeal, owner !== meal { throw ValidationError.assignment }
        guard let cents = Money.cents(price), cents > 0 else { throw ValidationError.price }
        var subtotal = cents
        for existing in meal.items ?? [] where existing !== item {
            guard let existingCents = Money.cents(existing.price) else { continue }
            guard subtotal <= Money.maximumCents - existingCents else { throw ValidationError.mealTotal }
            subtotal += existingCents
        }
        let consumerIDs = Array(Set(consumerIDs)).sorted()
        guard Set(consumerIDs).isSubset(of: Set((meal.people ?? []).map(\.id))) else { throw ValidationError.assignment }
        try persist(meal: meal, in: context) {
            if item.modelContext == nil { context.insert(item) }
            item.relatedMeal = meal
            if !(meal.items ?? []).contains(where: { $0 === item }) { meal.items = (meal.items ?? []) + [item] }
            item.name = name
            item.price = Double(cents) / 100
            item.category = category
            item.consumerIds = consumerIDs
            synchronizeAssignments(meal)
            meal.modifiedAt = Date()
        }
    }

    /// Saves a person's selected items and updates each item's authoritative consumer list in the same save.
    static func savePerson(_ person: MealPerson, meal: Meal, name: String, itemIDs: [String], isNew: Bool = false, in context: ModelContext) throws {
        try validateModel(meal, isNew: false, in: context)
        try validateModel(person, isNew: isNew, in: context)
        if !isNew, !(meal.people ?? []).contains(where: { $0 === person }) { throw ValidationError.assignment }
        let name = try validName(name)
        if let owner = person.relatedMeal, owner !== meal { throw ValidationError.assignment }
        let itemIDs = Set(itemIDs)
        guard itemIDs.isSubset(of: Set((meal.items ?? []).map(\.id))) else { throw ValidationError.assignment }
        try persist(meal: meal, in: context) {
            if person.modelContext == nil { context.insert(person) }
            person.relatedMeal = meal
            if !(meal.people ?? []).contains(where: { $0 === person }) { meal.people = (meal.people ?? []) + [person] }
            person.name = name
            for item in meal.items ?? [] {
                var consumers = Set(item.consumerIds)
                if itemIDs.contains(item.id) { consumers.insert(person.id) } else { consumers.remove(person.id) }
                item.consumerIds = consumers.sorted()
            }
            synchronizeAssignments(meal)
            meal.modifiedAt = Date()
        }
    }

    /// Applies one tax mode; both nil clears tax. Fixed amount wins if both values are supplied.
    static func setTax(_ meal: Meal, percentage: Double?, amount: Double?, in context: ModelContext) throws {
        try setCharge(meal, percentage: percentage, amount: amount, isTax: true, in: context)
    }
    /// Applies one tip mode; percentage tips include tax. Both nil clears tip.
    static func setTip(_ meal: Meal, percentage: Double?, amount: Double?, in context: ModelContext) throws {
        try setCharge(meal, percentage: percentage, amount: amount, isTax: false, in: context)
    }

    /// Recognizes one emoji grapheme within 64 UTF-8 bytes, including selectors, keycaps, flags, and joined sequences.
    /// Callers can safely display a fallback for malformed legacy charms without changing saved data.
    nonisolated static func isValidCharm(_ charm: String) -> Bool {
        (try? validCharm(charm)) != nil
    }

    /// Deletes all owned rows explicitly, preserving the existing schema's delete rules and preventing orphan records.
    static func deleteMeal(_ meal: Meal, in context: ModelContext) throws {
        try validateModel(meal, isNew: false, in: context)
        try persist(meal: meal, in: context) {
            for item in meal.items ?? [] { context.delete(item) }
            for person in meal.people ?? [] { context.delete(person) }
            if let restaurant = meal.restaurantDetails { context.delete(restaurant) }
            context.delete(meal)
        }
    }
    /// Deletes the item and its reverse assignment indexes in one save.
    static func deleteItem(_ item: MealItem, in context: ModelContext) throws {
        try validateModel(item, isNew: false, in: context)
        try persist(meal: item.relatedMeal, in: context) {
            if let meal = item.relatedMeal {
                meal.items = (meal.items ?? []).filter { $0 !== item }
                for person in meal.people ?? [] { person.itemIds.removeAll { $0 == item.id } }
                meal.modifiedAt = Date()
            }
            context.delete(item)
        }
    }
    /// Deletes the person and removes their consumer IDs in one save.
    static func deletePerson(_ person: MealPerson, in context: ModelContext) throws {
        try validateModel(person, isNew: false, in: context)
        try persist(meal: person.relatedMeal, in: context) {
            if let meal = person.relatedMeal {
                meal.people = (meal.people ?? []).filter { $0 !== person }
                for item in meal.items ?? [] { item.consumerIds.removeAll { $0 == person.id } }
                meal.modifiedAt = Date()
            }
            context.delete(person)
        }
    }

    private static func setCharge(_ meal: Meal, percentage: Double?, amount: Double?, isTax: Bool, in context: ModelContext) throws {
        try validateModel(meal, isNew: false, in: context)
        let normalizedAmount: Double?
        if let amount {
            guard let cents = Money.cents(amount) else { throw ValidationError.charge }
            normalizedAmount = Double(cents) / 100
        } else {
            if let percentage, !Money.validPercentage(percentage) { throw ValidationError.charge }
            normalizedAmount = nil
        }
        let normalizedPercentage = normalizedAmount == nil ? percentage : nil
        if let normalizedPercentage {
            let current = MealAmounts(meal: meal)
            let base = isTax ? current.subtotalCents : current.subtotalCents + current.taxCents
            guard Money.percentageCents(normalizedPercentage, baseCents: base) != nil else { throw ValidationError.charge }
        }
        try persist(meal: meal, in: context) {
            if isTax { meal.taxAmount = normalizedAmount; meal.taxPercentage = normalizedPercentage }
            else { meal.tipAmount = normalizedAmount; meal.tipPercentage = normalizedPercentage }
            meal.modifiedAt = Date()
        }
    }

    private static func validName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // Paste can contain only invisible Unicode format characters that whitespace trimming does not remove.
        // Require visible content without stripping meaningful joiners or directional marks from real names.
        let hasVisibleContent = trimmed.unicodeScalars.contains {
            !$0.properties.isWhitespace && !$0.properties.isDefaultIgnorableCodePoint && $0.properties.generalCategory != .control
        }
        guard hasVisibleContent else { throw ValidationError.name }
        return trimmed
    }
    nonisolated private static func validCharm(_ charm: String) throws -> String {
        let trimmed = charm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.utf8.count <= 64, trimmed.count == 1 else { throw ValidationError.charm }
        let scalars = trimmed.unicodeScalars
        let hasPresentation = scalars.contains { $0.properties.isEmojiPresentation }
        let hasEmojiVariation = scalars.contains { $0.value == 0xFE0F } && scalars.contains { $0.properties.isEmoji }
        let isKeycap = scalars.contains { $0.value == 0x20E3 } && scalars.first.map { "0123456789#*".unicodeScalars.contains($0) } == true
        guard hasPresentation || hasEmojiVariation || isKeycap else { throw ValidationError.charm }
        return trimmed
    }
    private static func synchronizeAssignments(_ meal: Meal) {
        let people = meal.people ?? []
        let validIDs = Set(people.map(\.id))
        for item in meal.items ?? [] { item.consumerIds = Array(Set(item.consumerIds).intersection(validIDs)).sorted() }
        for person in people { person.itemIds = (meal.items ?? []).filter { $0.consumerIds.contains(person.id) }.map(\.id).sorted() }
    }
    private static func validateModel<Model: PersistentModel>(_ model: Model, isNew: Bool, in context: ModelContext) throws {
        guard context.container.configurations.allSatisfy(\.allowsSave) else { throw ValidationError.readOnly }
        guard !model.isDeleted else { throw ValidationError.unavailable }
        if isNew {
            guard model.modelContext == nil, model.persistentModelID.storeIdentifier == nil else { throw ValidationError.unavailable }
        } else {
            guard model.modelContext === context else { throw ValidationError.unavailable }
            let identifier = model.persistentModelID
            var descriptor = FetchDescriptor<Model>(predicate: #Predicate { $0.persistentModelID == identifier })
            descriptor.fetchLimit = 1
            guard try !context.fetch(descriptor).isEmpty else { throw ValidationError.unavailable }
        }
    }

    /// Commits a validated local mutation and restores the affected graph if native persistence rejects the save.
    /// Restored baseline values may remain pending on older runtimes; autosave or retry only re-saves those original values.
    static func persist(meal: Meal?, in context: ModelContext, mutation: () -> Void) throws {
        let snapshot = meal.flatMap { $0.modelContext == nil ? nil : MealSnapshot($0) }
        do {
            mutation()
            context.processPendingChanges()
            try context.save()
        }
        catch {
            context.rollback()
            // SwiftData rollback can leave held models stale; restore only the pre-edit owned graph.
            // A second rollback would discard this restoration on older runtimes.
            snapshot?.restore()
            context.processPendingChanges()
            throw error
        }
    }
}

/// Captures only this meal's owned graph so a failed save restores the displayed state as well as durable storage.
private struct MealSnapshot {
    let restore: () -> Void

    init(_ meal: Meal) {
        let title = meal.title, charm = meal.charm, modifiedAt = meal.modifiedAt, photo = meal.receiptPhoto
        let items = meal.items, people = meal.people, restaurant = meal.restaurantDetails
        let taxAmount = meal.taxAmount, taxPercentage = meal.taxPercentage, tipAmount = meal.tipAmount, tipPercentage = meal.tipPercentage
        let itemRestorations: [() -> Void] = (items ?? []).map { item in
            let name = item.name, price = item.price, category = item.category, consumers = item.consumerIds
            return { item.name = name; item.price = price; item.category = category; item.consumerIds = consumers; item.relatedMeal = meal }
        }
        let personRestorations: [() -> Void] = (people ?? []).map { person in
            let name = person.name, itemIDs = person.itemIds
            return { person.name = name; person.itemIds = itemIDs; person.relatedMeal = meal }
        }
        let restaurantDraft = restaurant.map(RestaurantDraft.init)
        restore = {
            meal.title = title; meal.charm = charm; meal.modifiedAt = modifiedAt; meal.receiptPhoto = photo
            meal.taxAmount = taxAmount; meal.taxPercentage = taxPercentage; meal.tipAmount = tipAmount; meal.tipPercentage = tipPercentage
            meal.items = items; meal.people = people; meal.restaurantDetails = restaurant
            itemRestorations.forEach { $0() }; personRestorations.forEach { $0() }
            if let restaurant, let restaurantDraft {
                restaurant.title = restaurantDraft.title; restaurant.address = restaurantDraft.address
                restaurant.lattitude = restaurantDraft.latitude; restaurant.longitude = restaurantDraft.longitude; restaurant.relatedMeal = meal
            }
        }
    }
}
