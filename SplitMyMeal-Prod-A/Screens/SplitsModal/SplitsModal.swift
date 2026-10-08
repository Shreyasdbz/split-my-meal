import SwiftUI

/// A reconciled, itemized bill that remains honest about unassigned charges.
struct SplitsModal: View {
    let meal: Meal
    @Environment(\.dismiss) private var dismiss
    private var people: [MealPerson] { (meal.people ?? []).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } }

    var body: some View {
        let amounts = MealAmounts(meal: meal)
        NavigationStack {
            List {
                Section {
                    AmountRow(title: "Subtotal", amount: amounts.subtotal)
                    AmountRow(title: "Tax", amount: amounts.tax)
                    AmountRow(title: "Tip", amount: amounts.tip)
                    AmountRow(title: "Total", amount: amounts.total, emphasized: true)
                        .accessibilityIdentifier("split-total")
                } header: { Text(meal.title) } footer: {
                    Text("Tax and tip follow item shares. Rounding keeps the total exact.")
                        .foregroundStyle(Color.mealSecondaryText)
                }
                if amounts.hasInvalidValues {
                    Section {
                        Label {
                            Text("Some saved values are invalid and excluded. Correct the prices, tax, or tip before sharing or settling.")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle").foregroundStyle(.red)
                        }
                    }
                }
                Section("Per person") {
                    if people.isEmpty {
                        Text("Add people and assign their items to split this meal.").foregroundStyle(Color.mealSecondaryText)
                    }
                    ForEach(people) { person in
                        DisclosureGroup {
                            let items = (meal.items ?? []).filter { $0.consumerIds.contains(person.id) }.sorted { $0.name < $1.name }
                            if items.isEmpty { Text("No items assigned").foregroundStyle(Color.mealSecondaryText) }
                            ForEach(items) { item in
                                VStack(alignment: .leading, spacing: 4) {
                                    AmountRow(title: item.name, amount: amounts.amount(for: item, person: person))
                                    Text("Item price \(mealCurrency(item.price)) · shared by \(Set(item.consumerIds).intersection(Set(people.map(\.id))).count)")
                                        .font(.caption).foregroundStyle(Color.mealSecondaryText)
                                }
                            }
                            AmountRow(title: "Item subtotal", amount: amounts.subtotal(for: person))
                            AmountRow(title: "Tax share", amount: amounts.tax(for: person))
                            AmountRow(title: "Tip share", amount: amounts.tip(for: person))
                        } label: { AmountRow(title: person.name, amount: amounts.amount(for: person), emphasized: true) }
                        .accessibilityIdentifier("split-\(person.name)")
                    }
                }
                if amounts.unassignedCents > 0 {
                    Section {
                        AmountRow(title: "Unassigned", amount: amounts.unassigned, emphasized: true)
                        Text(amounts.subtotalCents == 0
                             ? "Fixed charges need priced items before they can be divided. Add and assign items, or clear the charges."
                             : "This amount is included in the total but isn’t owed by a person yet. Assign the remaining items before settling the bill.")
                            .foregroundStyle(Color.mealSecondaryText)
                    }
                }
            }
            .mealFocusedContent()
            .navigationTitle("Split summary").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .bottomBar) {
                    ShareLink(item: shareText, subject: Text("\(meal.title) — meal split")) {
                        Label("Share split", systemImage: "square.and.arrow.up")
                    }.accessibilityIdentifier("share-split").disabled(amounts.hasInvalidValues)
                }
            }
        }
    }

    private var shareText: String {
        let amounts = MealAmounts(meal: meal)
        var lines = [meal.title, "Subtotal: \(mealCurrency(amounts.subtotal))", "Tax: \(mealCurrency(amounts.tax))", "Tip: \(mealCurrency(amounts.tip))", "Total: \(mealCurrency(amounts.total))", ""]
        for person in people {
            lines += ["\(person.name): \(mealCurrency(amounts.amount(for: person)))"]
            let items = (meal.items ?? []).filter { $0.consumerIds.contains(person.id) }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            lines += items.map { "  \($0.name): \(mealCurrency(amounts.amount(for: $0, person: person)))" }
            lines += ["  Tax: \(mealCurrency(amounts.tax(for: person))) · Tip: \(mealCurrency(amounts.tip(for: person)))", ""]
        }
        if amounts.unassignedCents > 0 {
            lines += ["Unassigned: \(mealCurrency(amounts.unassigned))", amounts.subtotalCents == 0
                      ? "Add priced items or clear fixed charges before settling."
                      : "Assign remaining items before settling."]
        }
        return lines.joined(separator: "\n")
    }
}
