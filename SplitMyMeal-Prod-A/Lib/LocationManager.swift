import Foundation
import CoreLocation
import Combine

/// Requests one location only for an explicit nearby-search or map action; caches coordinates only while authorized.
@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    /// Permission failures retain whether Settings can offer a user-controlled recovery.
    enum Failure: Equatable {
        case denied, restricted, unavailable, notFound

        var message: String {
            switch self {
            case .denied: "Location access is off. Review it in Settings."
            case .restricted: "Location access is restricted on this device."
            case .unavailable: "Your current location is unavailable. Try again later."
            case .notFound: "Your location couldn’t be found. Try again when a location signal is available."
            }
        }
    }

    private let manager = CLLocationManager()
    // Distinguishes the initial permission prompt from a GPS request whose access was withdrawn in Settings.
    private var isAwaitingAuthorization = false
    @Published private(set) var lastLocation: CLLocation?
    @Published private(set) var failure: Failure?
    @Published private(set) var isRequesting = false
    var errorMessage: String? { failure?.message }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestNearbyLocation() {
        failure = nil
        isRequesting = true
        isAwaitingAuthorization = false
        switch manager.authorizationStatus {
        case .notDetermined:
            lastLocation = nil
            isAwaitingAuthorization = true
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied:
            isRequesting = false
            lastLocation = nil
            failure = .denied
        case .restricted:
            isRequesting = false
            lastLocation = nil
            failure = .restricted
        @unknown default:
            isRequesting = false
            lastLocation = nil
            failure = .unavailable
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch self.manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                isAwaitingAuthorization = false
                failure = nil
                // Returning from Settings updates recovery UI without starting a new request.
                if isRequesting { self.manager.requestLocation() }
            case .denied:
                guard isRequesting || lastLocation != nil || failure == .denied || failure == .restricted else { return }
                isAwaitingAuthorization = false
                isRequesting = false
                lastLocation = nil
                failure = .denied
            case .restricted:
                guard isRequesting || lastLocation != nil || failure == .denied || failure == .restricted else { return }
                isAwaitingAuthorization = false
                isRequesting = false
                lastLocation = nil
                failure = .restricted
            case .notDetermined:
                lastLocation = nil
                failure = nil
                // Ask Next Time withdraws existing access. Only an explicit initial prompt stays pending.
                if !isAwaitingAuthorization { isRequesting = false }
            @unknown default:
                lastLocation = nil
                isAwaitingAuthorization = false
                failure = isRequesting ? .unavailable : nil
                isRequesting = false
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor [weak self] in
            guard let self, isRequesting else { return }
            // A queued GPS callback can arrive after permission was withdrawn, before its authorization callback.
            guard self.manager.authorizationStatus == .authorizedAlways || self.manager.authorizationStatus == .authorizedWhenInUse else {
                lastLocation = nil
                return
            }
            lastLocation = locations.last
            isRequesting = false
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self, isRequesting else { return }
            isRequesting = false
            failure = .notFound
        }
    }

    func cancel() { manager.stopUpdatingLocation(); isAwaitingAuthorization = false; isRequesting = false }
}
