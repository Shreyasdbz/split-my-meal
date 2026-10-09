import SwiftUI
import SwiftData
import UIKit

/// Stages item fields and consumer assignments until an explicit successful save.
struct ItemEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    private let meal: Meal
    private let existingItem: MealItem?
    @State private var name: String
    @State private var price: String
    @State private var category: MealItemCategory
    @State private var consumerIDs: Set<String>
    @State private var bulkSelectionVersion = 0
    @State private var errorMessage: String?
    @State private var confirmDelete = false
    @FocusState private var focusedField: Field?
    private enum Field { case name, price }

    private var people: [MealPerson] {
        (meal.people ?? []).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Uses the saved bill's exact remainder rule; this preview excludes tax and tip.
    /// Invalid price drafts show no monetary preview and never mutate the meal.
    private var draftShares: [String: Int64]? {
        guard let parsed = try? DecimalInput.parse(price, allowZero: false),
              let cents = Money.cents(parsed) else { return nil }
        return Money.itemShares(cents: cents, consumerIDs: consumerIDs.intersection(Set(people.map(\.id))))
    }

    init(meal: Meal, item: MealItem? = nil, initialCategory: MealItemCategory = .Snack) {
        self.meal = meal
        existingItem = item
        _name = State(initialValue: item?.name ?? "")
        _price = State(initialValue: item.map { $0.price.formatted(.number.grouping(.never).precision(.fractionLength(0...2))) } ?? "")
        _category = State(initialValue: item?.category ?? initialCategory)
        // Hidden legacy consumers cannot be edited; Save repairs them while Cancel preserves storage.
        let availablePeople = Set((meal.people ?? []).map(\.id))
        _consumerIDs = State(initialValue: Set(item?.consumerIds ?? []).intersection(availablePeople))
    }

    var body: some View {
        let shares = draftShares
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Item name", text: $name)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .price }
                        .accessibilityIdentifier("item-name")
                    LabeledContent("Price (USD)") {
                        TextField("0.00", text: $price)
                            .multilineTextAlignment(.trailing)
                            // iPad sheets can be compact; device idiom keeps native submit support.
                            .keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad)
                            .focused($focusedField, equals: .price)
                            .submitLabel(.done)
                            .onSubmit { focusedField = nil }
                            .accessibilityLabel("Item price in US dollars")
                            .accessibilityIdentifier("item-price")
                    }
                    Picker("Category", selection: $category) {
                        ForEach(MealItemCategory.allCases, id: \.self) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    .accessibilityIdentifier("item-category")
                }
                Section {
                    if !people.isEmpty {
                        if people.count > 1 {
                            Button {
                                focusedField = nil
                                consumerIDs = Set(people.map(\.id))
                                bulkSelectionVersion += 1
                            } label: {
                                Label("Everyone", systemImage: "person.2")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .disabled(consumerIDs == Set(people.map(\.id)))
                            .accessibilityIdentifier("assign-everyone")
                            .accessibilityHint("Select every person for this item")
                            .sensoryFeedback(.selection, trigger: bulkSelectionVersion)
                        }
                        ForEach(people) { person in
                            Toggle(isOn: Binding(get: { consumerIDs.contains(person.id) }, set: { selected in
                                if selected { consumerIDs.insert(person.id) } else { consumerIDs.remove(person.id) }
                            })) {
                                if let cents = shares?[person.id] {
                                    AmountRow(title: person.name, amount: Double(cents) / 100)
                                        .accessibilityIdentifier("draft-item-share-\(person.name)")
                                } else {
                                    Text(person.name)
                                }
                            }
                            .accessibilityIdentifier("item-consumer-\(person.name)")
                            .accessibilityHint(shares?[person.id] == nil ? "Choose who shares this item" : "Item share excludes tax and tip")
                        }
                    } else {
                        Text("Add people to assign this item.").foregroundStyle(Color.mealSecondaryText)
                    }
                } header: { Text("Shared by") } footer: {
                    if !people.isEmpty {
                        Text(consumerIDs.isEmpty ? "Unassigned until someone is selected." : "Item shares exclude tax and tip.")
                            .foregroundStyle(Color.mealSecondaryText)
                    }
                }
                if existingItem != nil {
                    Section {
                        Button("Delete item", role: .destructive) { confirmDelete = true }
                            .accessibilityIdentifier("delete-item")
                    }
                }
            }
            .navigationTitle(existingItem == nil ? "New item" : "Edit item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).accessibilityIdentifier("save-item")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .confirmationDialog("Delete this item?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete item", role: .destructive) { deleteItem() }
                    .accessibilityIdentifier("confirm-delete-item")
            }
            .alert("Couldn’t update item", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func save() {
        do {
            let parsed = try DecimalInput.parse(price, allowZero: false)
            try MealStore.saveItem(existingItem ?? MealItem(relatedMeal: nil, category: category), meal: meal, name: name, price: parsed, category: category, consumerIDs: Array(consumerIDs), isNew: existingItem == nil, in: context)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }

    private func deleteItem() {
        guard let existingItem else { return }
        do { try MealStore.deleteItem(existingItem, in: context); dismiss() }
        catch { errorMessage = error.localizedDescription }
    }
}
