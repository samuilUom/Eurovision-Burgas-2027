import CoreLocation
import Combine

final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    @Published var message: String?
    @Published var isLocating = false
    @Published var denied = false
    private var tracking = false
    private var locationTimeout: DispatchWorkItem?
    private lazy var manager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        return manager
    }()
    func startTracking() {
        tracking = true
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 5
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        request()
    }
    func stopTracking() {
        tracking = false
        locationTimeout?.cancel()
        locationTimeout = nil
        manager.stopUpdatingLocation()
        isLocating = false
    }
    private func obtainLocation() {
        locationTimeout?.cancel()
        isLocating = true
        let timeout = DispatchWorkItem { [weak self] in
            guard let self, self.isLocating else { return }
            self.isLocating = false
            self.message = "Няма актуална GPS позиция. Излезте на открито и натиснете „Опитай отново“."
        }
        locationTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: timeout)
        if tracking { manager.startUpdatingLocation() }
        else { manager.requestLocation() }
    }
    func request() {
        message = nil
        denied = false
        switch manager.authorizationStatus {
        case .notDetermined:
            isLocating = true
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            isLocating = true
            obtainLocation()
        case .denied, .restricted:
            showDenied()
        @unknown default:
            isLocating = false
            message = "Местоположението е недостъпно. Можете да търсите по име."
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            denied = false
            if isLocating || tracking { obtainLocation() }
        case .denied, .restricted:
            manager.stopUpdatingLocation()
            location = nil
            if isLocating || tracking { showDenied() }
        default: break
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let recent = locations.last, recent.horizontalAccuracy >= 0,
              CLLocationCoordinate2DIsValid(recent.coordinate),
              abs(recent.timestamp.timeIntervalSinceNow) < (tracking ? 15 : 120) else {
            // Cached fixes can arrive before GPS has a new position. Keep waiting until the timeout.
            if !isLocating { message = "Няма актуална позиция. Опитайте отново." }
            return
        }
        locationTimeout?.cancel()
        locationTimeout = nil
        isLocating = false
        location = recent
        message = nil
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let error = error as? CLError {
            if error.code == .denied { showDenied(); return }
            if error.code == .locationUnknown && isLocating { return }
        }
        locationTimeout?.cancel()
        locationTimeout = nil
        isLocating = false
        message = "Не успяхме да определим позицията. Опитайте отново или търсете по име."
    }
    private func showDenied() {
        locationTimeout?.cancel()
        locationTimeout = nil
        location = nil
        isLocating = false
        denied = true
        message = "Разрешете местоположението в Настройки или търсете по име."
    }
}
