import Foundation

/// A USD calculation snapshot. Each charge is rounded to cents once; stable ID order resolves tied remainder cents.
/// Fixed charges take precedence over percentages, and percentage tips include tax for compatibility with saved meals.
struct MealAmounts {
    let subtotalCents: Int64
    let taxCents: Int64
    let tipCents: Int64
    let totalCents: Int64
    let unassignedCents: Int64
    let unassignedItemCount: Int
    let hasInvalidValues: Bool
    private let itemCount: Int
    private let personAmounts: [String: Int64]
    private let personSubtotals: [String: Int64]
    private let personTaxes: [String: Int64]
    private let personTips: [String: Int64]
    private let itemShares: [ObjectIdentifier: [String: Int64]]

    var subtotal: Double { dollars(subtotalCents) }
    var tax: Double { dollars(taxCents) }
    var tip: Double { dollars(tipCents) }
    var total: Double { dollars(totalCents) }
    var unassigned: Double { dollars(unassignedCents) }

    /// A nonempty valid bill with no unassigned items or cents; does not certify payment or sharing.
    var isFullyAssigned: Bool {
        itemCount > 0 && !hasInvalidValues && unassignedItemCount == 0 && unassignedCents == 0
    }

    /// Reads the legacy model without mutating or persisting it. Invalid saved money is excluded and explicitly flagged.
    init(meal: Meal) {
        let items = meal.items ?? []
        itemCount = items.count
        let people = Set((meal.people ?? []).map(\.id))
        var bases = Dictionary(uniqueKeysWithValues: people.map { ($0, Int64(0)) })
        let unassignedKey = "\u{0}unassigned"
        bases[unassignedKey] = 0
        var invalid = false
        var unassignedCount = 0
        var subtotal: Int64 = 0
        var sharesByItem: [ObjectIdentifier: [String: Int64]] = [:]

        for item in items {
            let consumers = Set(item.consumerIds).intersection(people)
            guard let cents = Money.cents(item.price), cents >= 0,
                  subtotal <= Money.maximumCents - cents,
                  let shares = Money.itemShares(cents: cents, consumerIDs: consumers) else {
                invalid = true
                continue
            }
            subtotal += cents
            if consumers.isEmpty {
                bases[unassignedKey, default: 0] += cents
                unassignedCount += 1
            } else {
                for (id, share) in shares {
                    bases[id, default: 0] += share
                }
                sharesByItem[ObjectIdentifier(item)] = shares
            }
        }

        func charge(amount: Double?, percentage: Double?, base: Int64) -> Int64 {
            if let amount {
                guard let cents = Money.cents(amount) else { invalid = true; return 0 }
                return cents
            }
            guard let percentage else { return 0 }
            guard let cents = Money.percentageCents(percentage, baseCents: base) else {
                invalid = true
                return 0
            }
            return cents
        }

        let tax = charge(amount: meal.taxAmount, percentage: meal.taxPercentage, base: subtotal)
        let taxed = subtotal + tax
        let tip = charge(amount: meal.tipAmount, percentage: meal.tipPercentage, base: taxed)
        let taxShares = Self.allocate(tax, weights: bases, fallback: unassignedKey)
        var taxedShares = bases
        for (id, cents) in taxShares { taxedShares[id, default: 0] += cents }
        let tipShares = Self.allocate(tip, weights: taxedShares, fallback: unassignedKey)
        var totals = taxedShares
        for (id, cents) in tipShares { totals[id, default: 0] += cents }

        subtotalCents = subtotal
        taxCents = tax
        tipCents = tip
        totalCents = taxed + tip
        unassignedCents = totals.removeValue(forKey: unassignedKey) ?? 0
        personAmounts = totals
        personSubtotals = bases
        personTaxes = taxShares
        personTips = tipShares
        itemShares = sharesByItem
        unassignedItemCount = unassignedCount
        hasInvalidValues = invalid
    }

    /// Returns a person's cent-exact total; people outside this meal owe zero.
    func cents(for person: MealPerson) -> Int64 { personAmounts[person.id] ?? 0 }
    func amount(for person: MealPerson) -> Double { dollars(cents(for: person)) }

    /// Itemized components use the same allocation snapshot as the total, so their sum equals the person's bill exactly.
    func subtotalCents(for person: MealPerson) -> Int64 { personSubtotals[person.id] ?? 0 }
    func taxCents(for person: MealPerson) -> Int64 { personTaxes[person.id] ?? 0 }
    func tipCents(for person: MealPerson) -> Int64 { personTips[person.id] ?? 0 }
    func subtotal(for person: MealPerson) -> Double { dollars(subtotalCents(for: person)) }
    func tax(for person: MealPerson) -> Double { dollars(taxCents(for: person)) }
    func tip(for person: MealPerson) -> Double { dollars(tipCents(for: person)) }

    /// Returns the share of this exact item instance. Unassigned items and nonconsumers have a zero person share.
    func cents(for item: MealItem, person: MealPerson) -> Int64 { itemShares[ObjectIdentifier(item)]?[person.id] ?? 0 }
    func amount(for item: MealItem, person: MealPerson) -> Double { dollars(cents(for: item, person: person)) }

    private func dollars(_ cents: Int64) -> Double { Double(cents) / 100 }

    /// Largest-remainder allocation conserves the charge exactly, including zero-subtotal fixed charges.
    private static func allocate(_ charge: Int64, weights: [String: Int64], fallback: String) -> [String: Int64] {
        let totalWeight = weights.values.reduce(0, +)
        guard totalWeight > 0 else { return [fallback: charge] }
        var shares: [String: Int64] = [:]
        var remainders: [(String, Decimal)] = []
        var allocated: Int64 = 0
        for (id, weight) in weights where weight > 0 {
            let exact = Decimal(charge) * Decimal(weight) / Decimal(totalWeight)
            var value = exact
            var rounded = Decimal()
            NSDecimalRound(&rounded, &value, 0, .down)
            let cents = NSDecimalNumber(decimal: rounded).int64Value
            shares[id] = cents
            allocated += cents
            remainders.append((id, exact - rounded))
        }
        remainders.sort { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 > $1.1 }
        for index in 0..<Int(charge - allocated) {
            shares[remainders[index].0, default: 0] += 1
        }
        return shares
    }
}

/// Boundary conversion for the existing Double storage schema. Money is USD and accepted at most $1 billion per charge.
enum Money {
    static let maximumAmount: Double = 1_000_000_000
    static let maximumCents: Int64 = 100_000_000_000
    static let maximumPercentage: Double = 10_000
    // Includes the largest accepted subtotal, 10,000% tax, and 10,000% tip on the taxed subtotal.
    static let maximumCalculatedCents: Int64 = 1_100_000_000_000_000

    static func decimal(_ value: Double) -> Decimal { Decimal(string: String(value), locale: Locale(identifier: "en_US_POSIX")) ?? .nan }
    static func cents(_ value: Double) -> Int64? {
        guard value.isFinite, value >= 0, value <= maximumAmount else { return nil }
        return roundedCents(decimal(value) * 100)
    }
    static func roundedCents(_ value: Decimal, maximum: Int64 = maximumCents) -> Int64? {
        guard !value.isNaN, value >= 0, value <= Decimal(maximum) else { return nil }
        var value = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        return NSDecimalNumber(decimal: rounded).int64Value
    }
    /// Splits valid item cents equally; sorted consumer IDs receive remainder cents first.
    /// Empty selection returns no shares; invalid cents return nil. No charges or model mutations are applied.
    static func itemShares(cents: Int64, consumerIDs: Set<String>) -> [String: Int64]? {
        guard cents >= 0, cents <= maximumCents else { return nil }
        guard !consumerIDs.isEmpty else { return [:] }
        let consumers = consumerIDs.sorted()
        let quotient = cents / Int64(consumers.count)
        let remainder = cents % Int64(consumers.count)
        return Dictionary(uniqueKeysWithValues: consumers.enumerated().map { index, id in
            (id, quotient + (Int64(index) < remainder ? 1 : 0))
        })
    }
    /// Computes a percentage charge from its integer-cent base, rounding half cents up once for editing and saved totals.
    /// Returns nil for invalid input or a charge beyond the app's safe calculation bound.
    static func percentageCents(_ percentage: Double, baseCents: Int64) -> Int64? {
        guard validPercentage(percentage), baseCents >= 0, baseCents <= maximumCalculatedCents else { return nil }
        return roundedCents(Decimal(baseCents) * decimal(percentage) / 100, maximum: maximumCalculatedCents)
    }
    static func validPercentage(_ value: Double) -> Bool { value.isFinite && value >= 0 && value <= maximumPercentage }
}
