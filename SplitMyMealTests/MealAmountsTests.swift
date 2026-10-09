import XCTest
@testable import SplitMyMeal_Prod_A

@MainActor
final class MealAmountsTests: XCTestCase {
    private func meal(price: Double, consumerIDs: [String], peopleIDs: [String]) -> Meal {
        let meal = Meal()
        meal.people = peopleIDs.map { id in let person = MealPerson(relatedMeal: nil); person.id = id; person.name = id; return person }
        let item = MealItem(relatedMeal: nil, category: .Entree)
        item.price = price
        item.consumerIds = consumerIDs
        meal.items = [item]
        return meal
    }

    func testPercentageChargeRoundsHalfCentOnceForPreviewAndSavedTotals() {
        XCTAssertEqual(Money.percentageCents(0.5, baseCents: 100), 1)
        XCTAssertEqual(Money.percentageCents(1.005, baseCents: 10_000), 101)
        XCTAssertNil(Money.percentageCents(.nan, baseCents: 100))
        XCTAssertNil(Money.percentageCents(-1, baseCents: 100))
        XCTAssertNil(Money.percentageCents(10_001, baseCents: 100))
        XCTAssertNil(Money.percentageCents(10, baseCents: -1))
        XCTAssertNil(Money.percentageCents(10_000, baseCents: Money.maximumCalculatedCents))
        let meal = Meal()
        let item = MealItem(relatedMeal: meal, category: .Snack)
        item.price = 1
        meal.items = [item]
        meal.taxPercentage = 0.5
        meal.tipPercentage = 0.5
        let amounts = MealAmounts(meal: meal)
        XCTAssertEqual(amounts.taxCents, Money.percentageCents(0.5, baseCents: amounts.subtotalCents))
        XCTAssertEqual(amounts.tipCents, Money.percentageCents(0.5, baseCents: amounts.subtotalCents + amounts.taxCents))
        XCTAssertEqual(amounts.totalCents, 102)
    }

    func testSharedItemRemainderIsStableAndConserved() {
        let meal = meal(price: 10, consumerIDs: ["c", "a", "b"], peopleIDs: ["c", "b", "a"])
        let amounts = MealAmounts(meal: meal)
        XCTAssertEqual(amounts.totalCents, 1000)
        XCTAssertEqual(amounts.cents(for: meal.people!.first { $0.id == "a" }!), 334)
        XCTAssertEqual(meal.people!.map { amounts.cents(for: $0) }.reduce(0, +), 1000)
        meal.people!.reverse()
        meal.items![0].consumerIds.reverse()
        XCTAssertEqual(MealAmounts(meal: meal).cents(for: meal.people!.first { $0.id == "a" }!), 334)
    }

    func testDraftItemSharesMatchSavedAllocationAndRejectInvalidBounds() {
        let consumers: Set<String> = ["c", "a", "b"]
        let expected: [String: Int64] = ["a": 334, "b": 334, "c": 333]
        XCTAssertEqual(Money.itemShares(cents: 1001, consumerIDs: consumers), expected)
        XCTAssertNil(Money.itemShares(cents: -1, consumerIDs: consumers))
        XCTAssertNil(Money.itemShares(cents: Money.maximumCents + 1, consumerIDs: consumers))
        XCTAssertNil(Money.itemShares(cents: -1, consumerIDs: []))
        XCTAssertEqual(Money.itemShares(cents: 1001, consumerIDs: []), [:])
        XCTAssertEqual(Money.itemShares(cents: 0, consumerIDs: consumers), ["a": 0, "b": 0, "c": 0])
        let maximumShares = Money.itemShares(cents: Money.maximumCents, consumerIDs: consumers)
        XCTAssertEqual(maximumShares?.values.reduce(0, +), Money.maximumCents)

        let meal = meal(price: 10.01, consumerIDs: ["c", "a", "deleted", "b", "a"], peopleIDs: ["c", "b", "a"])
        let item = meal.items![0]
        for reverseOrder in [false, true] {
            if reverseOrder {
                meal.people!.reverse()
                item.consumerIds.reverse()
            }
            let amounts = MealAmounts(meal: meal)
            XCTAssertEqual(amounts.totalCents, 1001)
            XCTAssertTrue(amounts.isFullyAssigned)
            for person in meal.people! {
                XCTAssertEqual(amounts.cents(for: item, person: person), expected[person.id])
                XCTAssertEqual(amounts.subtotalCents(for: person), expected[person.id])
            }
            XCTAssertEqual(meal.people!.map { amounts.cents(for: $0) }.reduce(0, +), 1001)
        }

        let empty = Meal()
        XCTAssertFalse(MealAmounts(meal: empty).isFullyAssigned)
        empty.taxAmount = 1
        XCTAssertFalse(MealAmounts(meal: empty).isFullyAssigned)
        let zeroPrice = self.meal(price: 0, consumerIDs: [], peopleIDs: ["a"])
        let unassigned = MealAmounts(meal: zeroPrice)
        XCTAssertEqual(unassigned.unassignedCents, 0)
        XCTAssertEqual(unassigned.unassignedItemCount, 1)
        XCTAssertFalse(unassigned.isFullyAssigned)
        let invalid = self.meal(price: -1, consumerIDs: ["a"], peopleIDs: ["a"])
        XCTAssertFalse(MealAmounts(meal: invalid).isFullyAssigned)
    }

    func testFixedChargesTakePrecedenceAndTipIncludesTax() {
        let meal = meal(price: 100, consumerIDs: ["a"], peopleIDs: ["a"])
        meal.taxPercentage = 50
        meal.taxAmount = 10
        meal.tipPercentage = 20
        meal.tipAmount = 5
        XCTAssertEqual(MealAmounts(meal: meal).totalCents, 11500)
        meal.tipAmount = nil
        XCTAssertEqual(MealAmounts(meal: meal).tipCents, 2200)
        XCTAssertEqual(MealAmounts(meal: meal).totalCents, 13200)
    }

    func testUnassignedItemsAndChargesReconcileToGrandTotal() {
        let meal = meal(price: 10, consumerIDs: ["a"], peopleIDs: ["a", "b"])
        let item = MealItem(relatedMeal: nil, category: .Drink)
        item.price = 20
        meal.items!.append(item)
        meal.taxAmount = 3
        meal.tipAmount = 6
        let amounts = MealAmounts(meal: meal)
        XCTAssertEqual(amounts.unassignedItemCount, 1)
        XCTAssertEqual(amounts.unassignedCents, 2600)
        XCTAssertEqual(amounts.cents(for: meal.people![0]), 1300)
        XCTAssertEqual(amounts.totalCents, 3900)
        XCTAssertEqual(meal.people!.map { amounts.cents(for: $0) }.reduce(amounts.unassignedCents, +), amounts.totalCents)
    }

    func testUnknownAndDuplicateConsumersDoNotLoseMoney() {
        let meal = meal(price: 10, consumerIDs: ["a", "a", "deleted"], peopleIDs: ["a"])
        XCTAssertEqual(MealAmounts(meal: meal).cents(for: meal.people![0]), 1000)
        meal.items![0].consumerIds = ["deleted"]
        XCTAssertEqual(MealAmounts(meal: meal).unassignedCents, 1000)
    }

    func testEmptyMealWithFixedChargesHasFiniteUnassignedAmount() {
        let meal = Meal()
        meal.taxAmount = 5
        meal.tipAmount = 2
        let amounts = MealAmounts(meal: meal)
        XCTAssertEqual(amounts.totalCents, 700)
        XCTAssertEqual(amounts.unassignedCents, 700)
        XCTAssertTrue(amounts.total.isFinite)
    }

    func testDecimalRoundingAndFractionalCharges() {
        XCTAssertEqual(Money.cents(1.005), 101)
        let meal = meal(price: 10.01, consumerIDs: ["a", "b", "c"], peopleIDs: ["a", "b", "c"])
        meal.taxPercentage = 8.875
        meal.tipPercentage = 18
        let amounts = MealAmounts(meal: meal)
        XCTAssertEqual(amounts.taxCents, 89)
        XCTAssertEqual(amounts.tipCents, 196)
        XCTAssertEqual(amounts.totalCents, 1286)
        XCTAssertEqual(meal.people!.map { amounts.cents(for: $0) }.reduce(0, +), 1286)
    }

    func testInvalidLegacyValuesAreFlaggedWithoutNaNOrOverflow() {
        for value in [Double.nan, .infinity, -.infinity, -1, Money.maximumAmount + 1] {
            let meal = meal(price: value, consumerIDs: ["a"], peopleIDs: ["a"])
            meal.taxPercentage = .infinity
            let amounts = MealAmounts(meal: meal)
            XCTAssertTrue(amounts.hasInvalidValues)
            XCTAssertEqual(amounts.totalCents, 0)
            XCTAssertTrue(amounts.total.isFinite)
        }
    }

    func testLargeFormattedChargesAreNeverReparsedAsZero() {
        let meal = meal(price: 20000, consumerIDs: [], peopleIDs: [])
        meal.taxAmount = 1234.56
        XCTAssertEqual(MealAmounts(meal: meal).taxCents, 123456)
        XCTAssertEqual(MealAmounts(meal: meal).tax, 1234.56)
    }

    func testLargestAcceptedInputsRemainFiniteAndConserved() {
        let meal = meal(price: Money.maximumAmount, consumerIDs: ["a"], peopleIDs: ["a"])
        meal.taxPercentage = Money.maximumPercentage
        meal.tipPercentage = Money.maximumPercentage
        let amounts = MealAmounts(meal: meal)
        XCTAssertFalse(amounts.hasInvalidValues)
        XCTAssertEqual(amounts.subtotalCents, 100_000_000_000)
        XCTAssertEqual(amounts.taxCents, 10_000_000_000_000)
        XCTAssertEqual(amounts.tipCents, 1_010_000_000_000_000)
        XCTAssertEqual(amounts.totalCents, 1_020_100_000_000_000)
        XCTAssertEqual(amounts.cents(for: meal.people![0]), amounts.totalCents)
        XCTAssertTrue(amounts.total.isFinite)
    }

    func testItemizedPersonComponentsConserveEveryCent() {
        let meal = meal(price: 10, consumerIDs: ["a", "b", "c"], peopleIDs: ["a", "b", "c"])
        let dessert = MealItem(relatedMeal: nil, category: .Dessert)
        dessert.price = 2.01
        dessert.consumerIds = ["b", "c"]
        meal.items!.append(dessert)
        meal.taxAmount = 1.13
        meal.tipAmount = 2.19
        let amounts = MealAmounts(meal: meal)
        for person in meal.people! {
            XCTAssertEqual(meal.items!.map { amounts.cents(for: $0, person: person) }.reduce(0, +), amounts.subtotalCents(for: person))
            XCTAssertEqual(amounts.subtotalCents(for: person) + amounts.taxCents(for: person) + amounts.tipCents(for: person), amounts.cents(for: person))
        }
        XCTAssertEqual(meal.people!.map { amounts.taxCents(for: $0) }.reduce(0, +), 113)
        XCTAssertEqual(meal.people!.map { amounts.tipCents(for: $0) }.reduce(0, +), 219)
        XCTAssertEqual(meal.people!.map { amounts.cents(for: dessert, person: $0) }.reduce(0, +), 201)
        XCTAssertEqual(amounts.cents(for: dessert, person: meal.people![0]), 0)
        XCTAssertEqual(amounts.cents(for: dessert, person: meal.people![1]), 101)
    }
}
