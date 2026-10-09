import SwiftUI
import SwiftData
import MapKit
import UIKit

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
                        .mealAmountTransition(amounts.total)
                        .accessibilityIdentifier("meal-total")
                        .accessibilityLabel("Meal total").accessibilityValue(mealCurrency(amounts.total))
                    Text("\(people.count) \(people.count == 1 ? "person" : "people") · \(items.count) \(items.count == 1 ? "item" : "items")")
                        .font(.subheadline).foregroundStyle(Color.mealSecondaryText)
                    if amounts.isFullyAssigned {
                        MealAssignmentStatus().accessibilityIdentifier("meal-assignment-status")
                    }
                }.padding(.vertical, 8)
                AmountRow(title: "Subtotal", amount: amounts.subtotal)
                Button { charge = .tax } label: {
                    HStack(spacing: 12) { AmountRow(title: "Tax", amount: amounts.tax); MealRowAccessory() }
                        .contentShape(Rectangle())
                }
                    .accessibilityIdentifier("edit-tax").foregroundStyle(Color.primary)
                    .accessibilityHint("Edit tax")
                Button { charge = .tip } label: {
                    HStack(spacing: 12) { AmountRow(title: "Tip", amount: amounts.tip); MealRowAccessory() }
                        .contentShape(Rectangle())
                }
                    .accessibilityIdentifier("edit-tip").foregroundStyle(Color.primary)
                    .accessibilityHint("Edit tip")
            }

            if amounts.hasInvalidValues {
                Section {
                    Label {
                        Text("Some prices or charges are invalid. Edit them before settling.")
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
                                 ? "Add and assign priced items, or clear fixed charges."
                                 : "Assign the remaining items before settling.").font(.subheadline)
                        }
                    } icon: { Image(systemName: "exclamationmark.circle").foregroundStyle(.orange) }
                    .accessibilityIdentifier("unassigned-warning")
                }
            }

            Section {
                ForEach(people) { person in
                    let assignedNames = items.filter { $0.consumerIds.contains(person.id) }.map(\.name).joined(separator: ", ")
                    Button { selectedPerson = person } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                ViewThatFits(in: .horizontal) {
                                    HStack { Text(person.name).font(.headline); Spacer(); Text(mealCurrency(amounts.amount(for: person))).monospacedDigit() }
                                    VStack(alignment: .leading) { Text(person.name).font(.headline); Text(mealCurrency(amounts.amount(for: person))).monospacedDigit() }
                                }
                                Text(assignedNames.isEmpty ? "No items assigned" : assignedNames)
                                    .font(.subheadline).foregroundStyle(Color.mealSecondaryText).lineLimit(2)
                            }
                            MealRowAccessory()
                        }.padding(.vertical, 4).contentShape(Rectangle()).foregroundStyle(Color.primary)
                    }.accessibilityIdentifier("person-\(person.name)")
                        .accessibilityHint("Edit person and item shares")
                }
                Button("Add person", systemImage: "person.badge.plus") { showNewPerson = true }
                    .accessibilityIdentifier("add-person")
            } header: { Text("People") }

            Section {
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
                            MealRowAccessory()
                        }.padding(.vertical, 4).contentShape(Rectangle()).foregroundStyle(Color.primary)
                    }.accessibilityIdentifier("item-\(item.name)")
                        .accessibilityHint("Edit item and who shares it")
                }
                Button("Add item", systemImage: "plus.circle") { showNewItem = true }
                    .accessibilityIdentifier("add-item")
            } header: { Text("Items") }

            Section("Restaurant & receipt") {
                if let restaurant = meal.restaurantDetails {
                    Button { showMap = true } label: {
                        HStack(spacing: 12) {
                            Label {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(restaurant.title)
                                    Text(restaurant.address).font(.subheadline).foregroundStyle(Color.mealSecondaryText)
                                        // Keep secondary copy within the compact
                                        // viewport; its full value stays accessible.
                                        .lineLimit(textSize.isAccessibilitySize ? 2 : nil)
                                }
                            } icon: { Image(systemName: "mappin.and.ellipse") }
                            Spacer(minLength: 0)
                            MealRowAccessory()
                        }
                        .contentShape(Rectangle())
                    }.foregroundStyle(Color.primary)
                        .accessibilityLabel("\(restaurant.title), \(restaurant.address)")
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
        .mealBottomBar {
            Button { showSplit = true } label: {
                Label("View split", systemImage: "person.2").font(.headline).foregroundStyle(Color.mealPrimaryText).frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            .modifier(MealPrimaryButtonStyle())
            .accessibilityIdentifier("view-split")
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity)
            .padding(.horizontal).padding(.vertical, 8)
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
        .fullScreenCover(isPresented: $showMap) { if let restaurant = meal.restaurantDetails { RestaurantMap(restaurant: restaurant) } }
    }

    private func consumerNames(_ item: MealItem) -> String {
        let names = people.filter { item.consumerIds.contains($0.id) }.map(\.name)
        return names.isEmpty ? "Unassigned" : names.joined(separator: ", ")
    }
}

private struct RestaurantMap: View {
    let restaurant: RestaurantDetails
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var textSize
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
                    if verticalSizeClass == .compact {
                        // A bottom pane can consume the whole landscape map at
                        // accessibility sizes. Separate scrolling details keep
                        // the map visible without reducing the selected font.
                        HStack(spacing: 0) {
                            map(at: coordinate)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            ScrollView {
                                details(at: coordinate).padding()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.bar)
                            .background { detailsViewportProbe }
                            // Contain scrolled controls below navigation chrome;
                            // layout bounds alone do not clip their rendering.
                            .clipped()
                        }
                    } else if textSize.isAccessibilitySize {
                        // Permission feedback adds rows; keep map context
                        // visible while full-size details scroll independently.
                        GeometryReader { geometry in
                            VStack(spacing: 0) {
                                map(at: coordinate)
                                    .frame(height: geometry.size.height * 0.4)
                                ScrollView {
                                    details(at: coordinate).padding()
                                }
                                .background(.bar)
                                .background { detailsViewportProbe }
                                .clipped()
                            }
                        }
                    } else {
                        map(at: coordinate)
                            .safeAreaInset(edge: .bottom) {
                                details(at: coordinate).padding().background(.bar)
                            }
                    }
                } else {
                    ContentUnavailableView("Restaurant location unavailable", systemImage: "mappin.slash", description: Text("This saved location is invalid. Edit the meal to replace or remove the restaurant."))
                        .accessibilityIdentifier("invalid-restaurant-location")
                }
            }
            .navigationTitle(restaurant.title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .onReceive(location.$lastLocation) { value in
            guard let value else { return }
            position = .region(MKCoordinateRegion(center: value.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
        }
        .onDisappear { location.cancel() }
    }

    private func map(at coordinate: CLLocationCoordinate2D) -> some View {
        Map(position: $position) {
            Marker(restaurant.title, coordinate: coordinate)
            if location.lastLocation != nil { UserAnnotation() }
        }
        .mapControls { MapCompass(); MapScaleView(); MapPitchToggle() }
    }

    /// Exposes the target pane's layout rectangle only during isolated UI tests.
    /// Native AX scroll frames can include safe-area strips that clipping hides.
    @ViewBuilder private var detailsViewportProbe: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            GeometryReader { geometry in
                Color.clear
                    // Keep the measurement's AX footprint in the padding,
                    // away from native content and its hit points.
                    .frame(width: 1, height: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Restaurant details viewport")
                    .accessibilityIdentifier("restaurant-details-viewport")
                    .accessibilityValue(NSCoder.string(for: geometry.frame(in: .global)))
            }
            .allowsHitTesting(false)
        }
        #endif
    }

    private func details(at coordinate: CLLocationCoordinate2D) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(restaurant.address)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("restaurant-address")
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
            .foregroundStyle(Color.mealPrimaryText)
            // Details scroll with content; glass belongs to floating controls.
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Button("My location", systemImage: "location") { location.requestNearbyLocation() }
                .accessibilityLabel("Show my location")
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(location.isRequesting)
            if location.isRequesting { ProgressView("Finding your location…") }
            if let error = location.errorMessage {
                Text(error).font(.caption).foregroundStyle(Color.mealSecondaryText)
            }
            if location.failure == .denied, let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                Link(destination: settingsURL) {
                    Text("Open Settings")
                        .frame(minHeight: 44)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                    .accessibilityIdentifier("map-open-settings")
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
