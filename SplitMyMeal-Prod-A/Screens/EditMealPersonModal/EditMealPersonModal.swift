import SwiftUI
import SwiftData

/// Edits a person and their item selections without changing stored assignments on Cancel.
struct PersonEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    private let meal: Meal
    private let existingPerson: MealPerson?
    @State private var name: String
    @State private var itemIDs: Set<String>
    @State private var errorMessage: String?
    @State private var confirmDelete = false
    @FocusState private var nameFocused: Bool

    init(meal: Meal, person: MealPerson? = nil) {
        self.meal = meal
        existingPerson = person
        _name = State(initialValue: person?.name ?? "")
        // Item consumers are authoritative; older reverse indexes can omit saved shares.
        _itemIDs = State(initialValue: Set((meal.items ?? []).filter { item in
            person.map { item.consumerIds.contains($0.id) } ?? false
        }.map(\.id)))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Person") {
                    TextField("Person name", text: $name)
                        .textInputAutocapitalization(.words)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit { nameFocused = false }
                        .accessibilityIdentifier("person-name")
                }
                if let items = meal.items, !items.isEmpty {
                    ForEach(MealItemCategory.allCases, id: \.self) { category in
                        let categoryItems = items.filter { $0.category == category }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                        if !categoryItems.isEmpty {
                            Section(category.displayName) {
                                ForEach(categoryItems) { item in
                                    Toggle(isOn: Binding(get: { itemIDs.contains(item.id) }, set: { selected in
                                        if selected { itemIDs.insert(item.id) } else { itemIDs.remove(item.id) }
                                    })) {
                                        VStack(alignment: .leading) {
                                            Text(item.name)
                                            Text("Item price \(mealCurrency(item.price))").font(.caption).foregroundStyle(Color.mealSecondaryText)
                                        }
                                    }
                                    .accessibilityIdentifier("person-item-\(item.name)")
                                }
                            }
                        }
                    }
                } else {
                    Section("Items") {
                        Text("Add items to the meal, then select them here.").foregroundStyle(Color.mealSecondaryText)
                    }
                }
                if existingPerson != nil {
                    Section {
                        Button("Delete person", role: .destructive) { confirmDelete = true }
                            .accessibilityIdentifier("delete-person")
                    }
                }
            }
            .navigationTitle(existingPerson == nil ? "New person" : "Edit person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).accessibilityIdentifier("save-person")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { nameFocused = false }
                }
            }
            .confirmationDialog("Delete this person? Their item shares become unassigned unless others share them.", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete person", role: .destructive) { deletePerson() }
                    .accessibilityIdentifier("confirm-delete-person")
            }
            .alert("Couldn’t update person", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func save() {
        do {
            try MealStore.savePerson(existingPerson ?? MealPerson(relatedMeal: nil), meal: meal, name: name, itemIDs: Array(itemIDs), isNew: existingPerson == nil, in: context)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }

    private func deletePerson() {
        guard let existingPerson else { return }
        do { try MealStore.deletePerson(existingPerson, in: context); dismiss() }
        catch { errorMessage = error.localizedDescription }
    }
}
