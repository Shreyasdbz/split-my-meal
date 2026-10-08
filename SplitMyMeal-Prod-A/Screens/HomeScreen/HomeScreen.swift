import SwiftUI
import SwiftData

/// Adaptive meal library; the same selection survives compact and split layouts.
struct HomeScreen: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Meal.modifiedAt, order: .reverse) private var meals: [Meal]
    @State private var selectedMealID: PersistentIdentifier?
    @State private var search = ""
    @State private var sort: MealSort = .recent
    @State private var showNewMeal = false
    @State private var pendingDeleteID: PersistentIdentifier?
    @State private var error: String?

    private enum MealSort: String, CaseIterable {
        case recent = "Recently edited"
        case newest = "Newest first"
        case title = "Title"
    }

    private var visibleMeals: [Meal] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return meals.filter {
            query.isEmpty || $0.title.localizedStandardContains(query)
                || ($0.restaurantDetails?.title.localizedStandardContains(query) ?? false)
                || ($0.people ?? []).contains { $0.name.localizedStandardContains(query) }
        }.sorted {
            switch sort {
            case .recent: $0.modifiedAt == $1.modifiedAt ? $0.id < $1.id : $0.modifiedAt > $1.modifiedAt
            case .newest: $0.createdAt == $1.createdAt ? $0.id < $1.id : $0.createdAt > $1.createdAt
            case .title: $0.title == $1.title ? $0.id < $1.id : $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedMealID) {
                ForEach(visibleMeals) { meal in
                    NavigationLink(value: meal.persistentModelID) {
                        MealLibraryRow(meal: meal)
                    }
                    .accessibilityIdentifier("meal-\(meal.title)")
                    .swipeActions {
                        Button("Delete", role: .destructive) { pendingDeleteID = meal.persistentModelID }
                    }
                    .contextMenu {
                        Button("Delete meal", systemImage: "trash", role: .destructive) { pendingDeleteID = meal.persistentModelID }
                    }
                }
            }
            .overlay {
                if meals.isEmpty {
                    ContentUnavailableView {
                        Label("No meals yet", systemImage: "fork.knife.circle")
                    } actions: {
                        Button { showNewMeal = true } label: {
                            Text("New meal").foregroundStyle(Color.mealPrimaryText)
                        }
                            .modifier(MealPrimaryButtonStyle())
                    }
                } else if visibleMeals.isEmpty {
                    ContentUnavailableView.search(text: search)
                }
            }
            .navigationTitle("Meals")
            .searchable(text: $search, prompt: "Search meals")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu("Sort meals", systemImage: "arrow.up.arrow.down") {
                        Picker("Sort meals", selection: $sort) {
                            ForEach(MealSort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New meal", systemImage: "plus") { showNewMeal = true }
                        .accessibilityIdentifier("new-meal")
                }
            }
        } detail: {
            if let meal = meals.first(where: { $0.persistentModelID == selectedMealID }) {
                MealScreen(meal: meal, onDeleted: { selectedMealID = nil })
                    .id(meal.id)
            } else {
                ContentUnavailableView("Select a meal", systemImage: "fork.knife")
            }
        }
        .onChange(of: meals.map(\.persistentModelID)) { _, identifiers in
            if let selectedMealID, !identifiers.contains(selectedMealID) { self.selectedMealID = nil }
            if let pendingDeleteID, !identifiers.contains(pendingDeleteID) { self.pendingDeleteID = nil }
        }
        .mealFocusedPresentation(isPresented: $showNewMeal) {
            MealEditor(meal: nil, onSaved: { selectedMealID = $0.persistentModelID })
        }
        .alert("Delete meal?", isPresented: Binding(get: { pendingDeleteID != nil }, set: { if !$0 { pendingDeleteID = nil } })) {
            Button("Delete", role: .destructive) {
                guard let meal = meals.first(where: { $0.persistentModelID == pendingDeleteID }) else { pendingDeleteID = nil; return }
                do {
                    try MealStore.deleteMeal(meal, in: context)
                    if selectedMealID == meal.persistentModelID { selectedMealID = nil }
                } catch { self.error = error.localizedDescription }
                pendingDeleteID = nil
            }
            Button("Cancel", role: .cancel) { pendingDeleteID = nil }
        } message: {
            Text("The meal, items, people and receipt will be deleted. This can’t be undone.")
        }
        .alert("Couldn’t save changes", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }
}

private struct MealLibraryRow: View {
    let meal: Meal
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Keep the full currency amount readable in a narrow iPad sidebar at accessibility sizes.
            if !textSize.isAccessibilitySize {
                Text(mealDisplayCharm(meal.charm)).font(.largeTitle)
                    .accessibilityHidden(true).accessibilityIdentifier("decorative-meal-charm")
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(meal.title).font(.headline)
                Text((meal.people ?? []).isEmpty ? "No people added" : (meal.people ?? []).map(\.name).sorted().joined(separator: ", "))
                    .font(.subheadline).foregroundStyle(Color.mealSecondaryText).lineLimit(2)
                ViewThatFits(in: .horizontal) {
                    HStack { total; Spacer(); date }
                    VStack(alignment: .leading, spacing: 4) { total; date }
                }
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private var total: some View { Text(mealCurrency(MealAmounts(meal: meal).total)).font(.subheadline.weight(.semibold)).monospacedDigit() }
    private var date: some View { Text(meal.modifiedAt, format: .dateTime.month(.abbreviated).day()).font(.caption).foregroundStyle(Color.mealSecondaryText) }
}
