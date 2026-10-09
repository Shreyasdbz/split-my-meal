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
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Total").font(.subheadline).foregroundStyle(Color.mealSecondaryText).accessibilityHidden(true)
                        Text(mealCurrency(amounts.total)).font(.largeTitle.bold()).monospacedDigit()
                            .mealAmountTransition(amounts.total)
                            .accessibilityIdentifier("split-total")
                            .accessibilityLabel("Split total").accessibilityValue(mealCurrency(amounts.total))
                        if amounts.isFullyAssigned {
                            MealAssignmentStatus().accessibilityIdentifier("split-assignment-status")
                        }
                    }.padding(.vertical, 8)
                } header: { Text(meal.title) }
                if amounts.hasInvalidValues {
                    Section {
                        Label {
                            Text("Invalid saved values are excluded. Edit prices, tax or tip before sharing.")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle").foregroundStyle(.red)
                        }
                    }
                }
                if amounts.unassignedCents > 0 {
                    Section {
                        AmountRow(title: "Unassigned", amount: amounts.unassigned, emphasized: true)
                        Text(amounts.subtotalCents == 0
                             ? "Add and assign priced items, or clear fixed charges."
                             : "Included in the total, but not yet assigned. Assign the remaining items before settling.")
                            .foregroundStyle(Color.mealSecondaryText)
                    }
                }
                Section("Per person") {
                    if people.isEmpty {
                        Text("Add people and assign items to see their shares.").foregroundStyle(Color.mealSecondaryText)
                    }
                    ForEach(people) { person in
                        DisclosureGroup {
                            let items = (meal.items ?? []).filter { $0.consumerIds.contains(person.id) }.sorted { $0.name < $1.name }
                            if items.isEmpty { Text("No items assigned").foregroundStyle(Color.mealSecondaryText) }
                            ForEach(items) { item in
                                VStack(alignment: .leading, spacing: 4) {
                                    AmountRow(title: item.name, amount: amounts.amount(for: item, person: person))
                                    let consumerCount = Set(item.consumerIds).intersection(Set(people.map(\.id))).count
                                    Text(consumerCount > 1 ? "Item price \(mealCurrency(item.price)) · \(consumerCount) people" : "Item price \(mealCurrency(item.price))")
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
                Section {
                    DisclosureGroup("Bill details") {
                        AmountRow(title: "Subtotal", amount: amounts.subtotal)
                        AmountRow(title: "Tax", amount: amounts.tax)
                        AmountRow(title: "Tip", amount: amounts.tip)
                        Text("Shared items are divided equally. Tax and tip follow item shares. Percentage tips include tax. Rounding keeps totals exact.")
                            .font(.footnote).foregroundStyle(Color.mealSecondaryText)
                    }
                    .accessibilityIdentifier("bill-details")
                }
            }
            .mealFocusedContent()
            .mealBottomBar {
                ShareLink(item: shareText, subject: Text("\(meal.title) — meal split")) {
                    Label("Share split", systemImage: "square.and.arrow.up")
                        .labelStyle(.titleAndIcon)
                        .font(.headline)
                        .foregroundStyle(Color.mealPrimaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .modifier(MealPrimaryButtonStyle())
                .accessibilityIdentifier("share-split")
                .disabled(amounts.hasInvalidValues)
                .frame(maxWidth: 440)
                .frame(maxWidth: .infinity)
                .padding(.horizontal).padding(.vertical, 8)
            }
            .navigationTitle("Split summary").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
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
