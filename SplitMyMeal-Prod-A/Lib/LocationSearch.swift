import Foundation
import MapKit
import Observation

/// A stable, exact MapKit completion; resolution does not reconstruct an ambiguous text query.
struct LocationSuggestion: Identifiable {
    let completion: MKLocalSearchCompletion
    var id: String { completion.title + "\n" + completion.subtitle }
}

/// Owns autocomplete and cancellable selection resolution; clearing a query invalidates visible results.
@MainActor @Observable
final class LocationService: NSObject, MKLocalSearchCompleterDelegate {
    private var completer = MKLocalSearchCompleter()
    private var activeSearch: MKLocalSearch?
    private var activeSearchID: UUID?
    private var query = ""
    private static let searchUnavailableMessage = "Restaurant search is unavailable. Check your connection and retry."
    #if DEBUG
    private var didInjectSearchFailure = false
    #endif
    var suggestions: [LocationSuggestion] = []
    var isSearching = false
    var errorMessage: String?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .pointOfInterest
    }

    func update(query: String, near coordinate: CLLocationCoordinate2D? = nil) {
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        completer.delegate = nil
        completer.cancel()
        suggestions = []
        errorMessage = nil
        guard self.query.count >= 2 else { isSearching = false; return }
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--uitesting"), arguments.contains("--fail-first-restaurant-search"), !didInjectSearchFailure {
            // Exercise same-query Retry through the real UI before the next
            // attempt reaches MapKit. Production builds contain no fixture path.
            didInjectSearchFailure = true
            isSearching = false
            errorMessage = Self.searchUnavailableMessage
            return
        }
        #endif
        // A new completer gives each query an identity, so queued callbacks from older queries are discarded.
        completer = MKLocalSearchCompleter()
        completer.delegate = self
        completer.resultTypes = .pointOfInterest
        if let coordinate {
            completer.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 20_000, longitudinalMeters: 20_000)
        }
        isSearching = true
        completer.queryFragment = self.query
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let sourceID = ObjectIdentifier(completer)
        Task { @MainActor [weak self] in
            guard let self, !query.isEmpty, ObjectIdentifier(self.completer) == sourceID, self.completer.queryFragment == query else { return }
            var seen: Set<String> = []
            suggestions = self.completer.results.map { LocationSuggestion(completion: $0) }.filter { seen.insert($0.id).inserted }
            isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        let sourceID = ObjectIdentifier(completer)
        Task { @MainActor [weak self] in
            guard let self, query.count >= 2, ObjectIdentifier(self.completer) == sourceID, self.completer.queryFragment == query else { return }
            isSearching = false
            errorMessage = Self.searchUnavailableMessage
        }
    }

    func resolve(_ suggestion: LocationSuggestion) async throws -> RestaurantDraft {
        activeSearch?.cancel()
        let search = MKLocalSearch(request: MKLocalSearch.Request(completion: suggestion.completion))
        activeSearch = search
        let searchID = UUID()
        activeSearchID = searchID
        defer {
            if activeSearchID == searchID { activeSearch = nil; activeSearchID = nil }
        }
        let response = try await withTaskCancellationHandler {
            try await search.start()
        } onCancel: { [weak self] in
            Task { @MainActor in
                guard let self, self.activeSearchID == searchID else { return }
                self.activeSearch?.cancel()
            }
        }
        try Task.checkCancellation()
        guard let item = response.mapItems.first else { throw LocationError.noResult }
        let coordinate: CLLocationCoordinate2D
        if #available(iOS 26.0, *) { coordinate = item.location.coordinate }
        else { coordinate = item.placemark.coordinate }
        return RestaurantDraft(title: suggestion.completion.title, address: suggestion.completion.subtitle, latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    func cancel() {
        query = ""
        completer.delegate = nil
        completer.cancel()
        activeSearch?.cancel()
        activeSearch = nil
        activeSearchID = nil
        suggestions = []
        isSearching = false
    }

    private enum LocationError: LocalizedError {
        case noResult
        var errorDescription: String? { "This restaurant couldn’t be located. Try a different result." }
    }
}
