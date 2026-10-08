import SwiftUI
import SwiftData
import MapKit

/// Owns presentation of meal details and keeps edits inside draft editors.
struct MealScreen: View {
    let meal: Meal
    var onDeleted: () -> Void = {}
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var showEditor = false
    @State private var showNewPerson = false
    @State private var showNewItem = false
    @State private var selectedPerson: MealPerson?
    @State private var selectedItem: MealItem?
    @State private var charge: ChargeKind?
    @State private var showSplit = false
    @State private var showReceipt = false
    @State private var showMap = false

    private var people: [MealPerson] { (meal.people ?? []).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } }
    private var items: [MealItem] {
        (meal.items ?? []).sorted {
            $0.category == $1.category ? $0.name.localizedStandardCompare($1.name) == .orderedAscending : $0.category.rawValue < $1.category.rawValue
        }
    }

    var body: some View {
        let amounts = MealAmounts(meal: meal)
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Meal total").font(.subheadline).foregroundStyle(Color.mealSecondaryText).accessibilityHidden(true)
                    Text(mealCurrency(amounts.total)).font(.largeTitle.bold()).monospacedDigit()
                        .accessibilityIdentifier("meal-total")
                        .accessibilityLabel("Meal total").accessibilityValue(mealCurrency(amounts.total))
                    Text("\(people.count) \(people.count == 1 ? "person" : "people") · \(items.count) \(items.count == 1 ? "item" : "items")")
                        .font(.subheadline).foregroundStyle(Color.mealSecondaryText)
                }.padding(.vertical, 8)
                AmountRow(title: "Subtotal", amount: amounts.subtotal)
                Button { charge = .tax } label: { AmountRow(title: "Tax", amount: amounts.tax) }
                    .accessibilityIdentifier("edit-tax").foregroundStyle(Color.primary)
                Button { charge = .tip } label: { AmountRow(title: "Tip", amount: amounts.tip) }
                    .accessibilityIdentifier("edit-tip").foregroundStyle(Color.primary)
            } footer: {
                Text("Tax is proportional to each person’s items. Percentage tips include tax.")
                    .foregroundStyle(Color.mealSecondaryText)
            }

            if amounts.hasInvalidValues {
                Section {
                    Label {
                        Text("Some saved prices or charges are invalid. Edit them before settling this bill.")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle").foregroundStyle(.red)
                    }
                }
            }
            if amounts.unassignedCents > 0 {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(mealCurrency(amounts.unassigned)) unassigned").font(.headline)
                            Text(amounts.subtotalCents == 0
                                 ? "Add priced items and assign them, or clear the fixed charges."
                                 : "Assign every item to include the full bill in everyone’s split.").font(.subheadline)
                        }
                    } icon: { Image(systemName: "exclamationmark.circle").foregroundStyle(.orange) }
                    .accessibilityIdentifier("unassigned-warning")
                }
            }

            Section {
                if people.isEmpty {
                    Text("Add everyone who shared this meal.").foregroundStyle(Color.mealSecondaryText)
                }
                ForEach(people) { person in
                    let assignedNames = items.filter { $0.consumerIds.contains(person.id) }.map(\.name).joined(separator: ", ")
                    Button { selectedPerson = person } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            ViewThatFits(in: .horizontal) {
                                HStack { Text(person.name).font(.headline); Spacer(); Text(mealCurrency(amounts.amount(for: person))).monospacedDigit() }
                                VStack(alignment: .leading) { Text(person.name).font(.headline); Text(mealCurrency(amounts.amount(for: person))).monospacedDigit() }
                            }
                            Text(assignedNames.isEmpty ? "No items assigned" : assignedNames)
                                .font(.subheadline).foregroundStyle(Color.mealSecondaryText).lineLimit(2)
                        }.padding(.vertical, 4).contentShape(Rectangle()).foregroundStyle(Color.primary)
                    }.accessibilityIdentifier("person-\(person.name)")
                }
                Button("Add person", systemImage: "person.badge.plus") { showNewPerson = true }
                    .accessibilityIdentifier("add-person")
            } header: { Text("People") }

            Section {
                if items.isEmpty { Text("Add the items from your receipt.").foregroundStyle(Color.mealSecondaryText) }
                ForEach(items) { item in
                    Button { selectedItem = item } label: {
                        HStack(alignment: .top, spacing: 12) {
                            // The category remains in text; omit its decorative glyph when larger type needs the full row width.
                            if !textSize.isAccessibilitySize {
                                Image(systemName: item.category.symbol).frame(width: 24).foregroundStyle(Color.mealSecondaryText).accessibilityHidden(true)
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                ViewThatFits(in: .horizontal) {
                                    HStack { Text(item.name).font(.headline); Spacer(); Text(mealCurrency(item.price)).monospacedDigit() }
                                    VStack(alignment: .leading) { Text(item.name).font(.headline); Text(mealCurrency(item.price)).monospacedDigit() }
                                }
                                Text("\(item.category.displayName) · \(consumerNames(item))")
                                    .font(.subheadline).foregroundStyle(Color.mealSecondaryText).lineLimit(2)
                            }
                        }.padding(.vertical, 4).contentShape(Rectangle()).foregroundStyle(Color.primary)
                    }.accessibilityIdentifier("item-\(item.name)")
                }
                Button("Add item", systemImage: "plus.circle") { showNewItem = true }
                    .accessibilityIdentifier("add-item")
            } header: { Text("Items") }

            Section("Restaurant & receipt") {
                if let restaurant = meal.restaurantDetails {
                    Button { showMap = true } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(restaurant.title)
                                Text(restaurant.address).font(.subheadline).foregroundStyle(Color.mealSecondaryText)
                            }
                        } icon: { Image(systemName: "mappin.and.ellipse") }
                        .contentShape(Rectangle())
                    }.foregroundStyle(Color.primary)
                } else {
                    Button("Add restaurant", systemImage: "mappin.and.ellipse") { showEditor = true }
                }
                if meal.receiptPhoto != nil {
                    Button("View receipt", systemImage: "doc.text.image") { showReceipt = true }
                } else {
                    Button("Attach receipt", systemImage: "doc.badge.plus") { showEditor = true }
                }
            }
        }
        .navigationTitle("\(mealDisplayCharm(meal.charm)) \(meal.title)")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button { showSplit = true } label: {
                Label("View split", systemImage: "person.2").font(.headline).foregroundStyle(Color.mealPrimaryText).frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            .modifier(MealPrimaryButtonStyle())
            .accessibilityIdentifier("view-split")
            .padding(.horizontal).padding(.vertical, 8)
            .background(.bar)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit meal", systemImage: "pencil") { showEditor = true }
                    .accessibilityIdentifier("edit-meal")
            }
        }
        .mealFocusedPresentation(isPresented: $showEditor) { MealEditor(meal: meal, onSaved: { _ in }, onDeleted: onDeleted) }
        .sheet(isPresented: $showNewPerson) { PersonEditor(meal: meal) }
        .sheet(item: $selectedPerson) { PersonEditor(meal: meal, person: $0) }
        .sheet(isPresented: $showNewItem) { ItemEditor(meal: meal) }
        .sheet(item: $selectedItem) { ItemEditor(meal: meal, item: $0) }
        .sheet(item: $charge) { ChargeEditor(meal: meal, kind: $0) }
        .mealFocusedPresentation(isPresented: $showSplit) { SplitsModal(meal: meal) }
        .fullScreenCover(isPresented: $showReceipt) { if let data = meal.receiptPhoto { ReceiptViewer(data: data) } }
        .sheet(isPresented: $showMap) { if let restaurant = meal.restaurantDetails { RestaurantMap(restaurant: restaurant) } }
    }

    private func consumerNames(_ item: MealItem) -> String {
        let names = people.filter { item.consumerIds.contains($0.id) }.map(\.name)
        return names.isEmpty ? "Unassigned" : names.joined(separator: ", ")
    }
}

private struct RestaurantMap: View {
    let restaurant: RestaurantDetails
    @Environment(\.dismiss) private var dismiss
    @StateObject private var location = LocationManager()
    @State private var position: MapCameraPosition
    private let coordinate: CLLocationCoordinate2D?

    init(restaurant: RestaurantDetails) {
        self.restaurant = restaurant
        let savedCoordinate = CLLocationCoordinate2D(latitude: restaurant.lattitude, longitude: restaurant.longitude)
        // Migrated records bypass editor validation. Never pass invalid historical degrees to MapKit.
        coordinate = restaurant.lattitude.isFinite && restaurant.longitude.isFinite && CLLocationCoordinate2DIsValid(savedCoordinate)
            ? savedCoordinate : nil
        _position = State(initialValue: coordinate.map {
            .region(MKCoordinateRegion(center: $0, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
        } ?? .automatic)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let coordinate {
                    Map(position: $position) {
                        Marker(restaurant.title, coordinate: coordinate)
                        if location.lastLocation != nil { UserAnnotation() }
                    }
                    .mapControls { MapCompass(); MapScaleView(); MapPitchToggle() }
                    .safeAreaInset(edge: .bottom) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(restaurant.address)
                            Button("Show my location", systemImage: "location") { location.requestNearbyLocation() }
                                .disabled(location.isRequesting)
                            if let error = location.errorMessage { Text(error).font(.caption).foregroundStyle(Color.mealSecondaryText) }
                            Button("Open in Maps", systemImage: "arrow.up.right.square") {
                                let item: MKMapItem
                                if #available(iOS 26.0, *) {
                                    item = MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), address: nil)
                                } else {
                                    item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                                }
                                item.name = restaurant.title
                                item.openInMaps()
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding().background(.bar)
                    }
                    .onReceive(location.$lastLocation) { value in
                        guard let value else { return }
                        position = .region(MKCoordinateRegion(center: value.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
                    }
                    .onDisappear { location.cancel() }
                } else {
                    ContentUnavailableView("Restaurant location unavailable", systemImage: "mappin.slash", description: Text("This saved location is invalid. Edit the meal to replace or remove the restaurant."))
                        .accessibilityIdentifier("invalid-restaurant-location")
                }
            }
            .navigationTitle(restaurant.title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
