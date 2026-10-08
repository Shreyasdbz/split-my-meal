import SwiftUI
import MapKit
import UIKit

/// Searches restaurants without location permission and resolves a selected completion before committing it.
struct LocationSearchModal: View {
    @Environment(\.dismiss) private var dismiss
    @State private var service = LocationService()
    @StateObject private var location = LocationManager()
    @State private var query = ""
    @State private var resolutionTask: Task<Void, Never>?
    @State private var resolvingID: String?
    @State private var errorMessage: String?
    let onSelect: (RestaurantDraft) -> Void

    var body: some View {
        let permissionBlocked = location.failure == .denied || location.failure == .restricted
        NavigationStack {
            List {
                Section {
                    Button { location.requestNearbyLocation() } label: {
                        Label(location.lastLocation == nil ? "Use my location" : "Using your location", systemImage: "location")
                    }
                    .disabled(location.isRequesting)
                    .accessibilityIdentifier("nearby-restaurants")
                    if location.isRequesting { ProgressView("Finding your location…") }
                    if let message = location.errorMessage { Text(message).foregroundStyle(Color.mealSecondaryText).accessibilityIdentifier("restaurant-location-error") }
                    if location.failure == .denied, let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        Link(destination: settingsURL) {
                            Text("Open Settings")
                                .frame(minHeight: 44)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                            .accessibilityIdentifier("restaurant-open-settings")
                    }
                    if permissionBlocked {
                        Text("Search by name, address or city.")
                            .foregroundStyle(Color.mealSecondaryText)
                    }
                    if let message = service.errorMessage {
                        Text(message).foregroundStyle(Color.mealSecondaryText).accessibilityIdentifier("restaurant-search-error")
                        Button("Retry", systemImage: "arrow.clockwise") {
                            resolutionTask?.cancel()
                            resolvingID = nil
                            service.cancel()
                            service.update(query: query, near: location.lastLocation?.coordinate)
                        }
                        .accessibilityIdentifier("retry-restaurant-search")
                    }
                }
                Section {
                    if service.isSearching { ProgressView("Searching restaurants…") }
                    ForEach(service.suggestions) { suggestion in
                        Button { resolve(suggestion) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(suggestion.completion.title).foregroundStyle(Color.primary)
                                    Text(suggestion.completion.subtitle).font(.caption).foregroundStyle(Color.mealSecondaryText)
                                }
                                Spacer()
                                if resolvingID == suggestion.id { ProgressView() }
                            }
                        }
                        .disabled(resolvingID != nil)
                        .accessibilityIdentifier("restaurant-result-\(suggestion.id)")
                    }
                    if !service.isSearching, service.suggestions.isEmpty, service.errorMessage == nil,
                       query.count >= 2 || !permissionBlocked {
                        Text(query.count >= 2 ? "No results. Try another name, address or city." : "Search by name, address or city.")
                            .foregroundStyle(Color.mealSecondaryText)
                    }
                }
            }
            .navigationTitle("Restaurant")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Restaurant, address, or city")
            .autocorrectionDisabled()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .task(id: query) {
                resolutionTask?.cancel()
                resolvingID = nil
                service.cancel()
                do {
                    try await Task.sleep(for: .milliseconds(300))
                    try Task.checkCancellation()
                    service.update(query: query, near: location.lastLocation?.coordinate)
                } catch { }
            }
            .onChange(of: location.lastLocation) { _, latest in service.update(query: query, near: latest?.coordinate) }
            .alert("Couldn’t select restaurant", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .onDisappear { resolutionTask?.cancel(); service.cancel(); location.cancel() }
        }
    }

    private func resolve(_ suggestion: LocationSuggestion) {
        resolutionTask?.cancel()
        resolvingID = suggestion.id
        resolutionTask = Task { @MainActor in
            do {
                let restaurant = try await service.resolve(suggestion)
                try Task.checkCancellation()
                onSelect(restaurant)
                dismiss()
            } catch {
                guard !Task.isCancelled else { return }
                resolvingID = nil
                errorMessage = error.localizedDescription
            }
        }
    }
}
