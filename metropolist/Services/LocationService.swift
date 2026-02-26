import CoreLocation

@MainActor
@Observable
final class LocationService: NSObject {
    private let manager = CLLocationManager()
    private static let cacheDuration: TimeInterval = 60

    var currentLocation: CLLocation?
    private var lastLocationTimestamp: Date?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestLocationAsync() async throws -> CLLocation {
        if let existing = currentLocation,
           let timestamp = lastLocationTimestamp,
           Date().timeIntervalSince(timestamp) < Self.cacheDuration {
            return existing
        }
        guard isAuthorized else {
            requestPermission()
            throw LocationError.notAuthorized
        }
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    enum LocationError: LocalizedError {
        case notAuthorized

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                String(localized: "Location access is not authorized.", comment: "Location service: permission denied error")
            }
        }
    }

    func invalidateCache() {
        currentLocation = nil
        lastLocationTimestamp = nil
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: @preconcurrency CLLocationManagerDelegate {
    func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
        lastLocationTimestamp = Date()
        if let loc = locations.last {
            locationContinuation?.resume(returning: loc)
            locationContinuation = nil
        }
    }

    func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
        #if DEBUG
            print("Location error: \(error.localizedDescription)")
        #endif
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if isAuthorized, locationContinuation != nil {
            manager.requestLocation()
        }
    }
}
