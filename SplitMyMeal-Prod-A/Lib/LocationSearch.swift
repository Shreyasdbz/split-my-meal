//
//  LocationSearch.swift
//  SplitMyMeal-Prod-A
//
//  Created by Shreyas Sane on 4/28/24.
//

import Foundation
import MapKit

@Observable
class LocationService: NSObject, MKLocalSearchCompleterDelegate {
    private let completer: MKLocalSearchCompleter

    var completions = [SearchCompletions]()

    init(_ completer: MKLocalSearchCompleter) {
        self.completer = completer
        super.init()
        self.completer.delegate = self
    }

    func update(queryFragment: String) {
        completer.resultTypes = .pointOfInterest
        completer.queryFragment = queryFragment
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        completions = completer.results.map { completion in
            return .init(
                title: completion.title,
                subTitle: completion.subtitle
            )
        }
    }
    
    func search(with query: String, coordinate: CLLocationCoordinate2D? = nil) async throws -> [SearchResult] {
        let mapKitRequest = MKLocalSearch.Request()
        mapKitRequest.naturalLanguageQuery = query
        mapKitRequest.resultTypes = .pointOfInterest
        if let coordinate {
            mapKitRequest.region = .init(.init(origin: .init(coordinate), size: .init(width: 1, height: 1)))
        }
        let search = MKLocalSearch(request: mapKitRequest)
        let response = try await search.start()
        return response.mapItems.compactMap { mapItem in
            guard let location = mapItem.placemark.location?.coordinate else { return nil }
            return .init(location: location)
        }
    }
}

func convertSearchToLocation(locationService: LocationService, title: String, address: String) async -> SearchResult? {
    if let singleLocation = try? await locationService.search(with: "\(title) \(address)").first {
        return singleLocation
    }
    return nil
}

