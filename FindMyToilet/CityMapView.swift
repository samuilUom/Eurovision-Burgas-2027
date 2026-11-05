import SwiftUI
import MapKit

/// Keeps a single native map alive while category results change.
struct CityMapView: UIViewRepresentable {
    let pins: [CityMapPin]
    let viewport: CityMapViewport
    let showUserLocation: Bool
    let onRegionChange: (MKCoordinateRegion, Bool) -> Void
    let onSelect: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.pointOfInterestFilter = .excludingAll
        map.showsCompass = true
        map.showsScale = true
        map.isPitchEnabled = false
        map.register(PlaceMarkerView.self, forAnnotationViewWithReuseIdentifier: "city-place")
        // Restore the last visible camera if coming back from list mode.
        context.coordinator.cameraID = viewport.camera.id
        map.setRegion(viewport.region, animated: false)
        map.delegate = context.coordinator
        context.coordinator.update(pins: pins, in: map)
        map.showsUserLocation = showUserLocation
        return map
    }
    func updateUIView(_ map: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.owner = self
        if coordinator.cameraID != viewport.camera.id {
            coordinator.cameraID = viewport.camera.id
            coordinator.userMoved = false
            map.setRegion(viewport.camera.region, animated: false)
        }
        if map.showsUserLocation != showUserLocation { map.showsUserLocation = showUserLocation }
        coordinator.update(pins: pins, in: map)
    }
    static func dismantleUIView(_ map: MKMapView, coordinator: Coordinator) {
        coordinator.active = false
        map.delegate = nil
        map.showsUserLocation = false
    }

    final class PlaceMarkerView: MKMarkerAnnotationView {
        private let hoursBadge = UILabel()
        override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
            super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
            hoursBadge.text = "24/7"
            hoursBadge.font = .systemFont(ofSize: 10, weight: .heavy)
            hoursBadge.textAlignment = .center
            hoursBadge.backgroundColor = .systemBackground
            hoursBadge.layer.cornerRadius = 6
            hoursBadge.layer.masksToBounds = true
            hoursBadge.layer.borderWidth = 1
            hoursBadge.isUserInteractionEnabled = false
            hoursBadge.isAccessibilityElement = false
            addSubview(hoursBadge)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        func showHours(_ show: Bool, color: UIColor) {
            hoursBadge.isHidden = !show
            hoursBadge.textColor = color
            hoursBadge.layer.borderColor = color.cgColor
            setNeedsLayout()
        }
        override func layoutSubviews() {
            super.layoutSubviews()
            hoursBadge.frame = CGRect(x: bounds.midX + 5, y: bounds.minY - 10, width: 34, height: 18)
            bringSubviewToFront(hoursBadge)
        }
        override func prepareForReuse() {
            super.prepareForReuse()
            hoursBadge.isHidden = true
        }
    }

    final class PinAnnotation: NSObject, MKAnnotation {
        private(set) var pin: CityMapPin
        @objc dynamic var title: String?
        @objc dynamic var coordinate: CLLocationCoordinate2D
        init(_ pin: CityMapPin) { self.pin = pin; title = pin.title; coordinate = pin.coordinate }
        func update(_ value: CityMapPin) {
            if title != value.title { title = value.title }
            if coordinate.latitude != value.latitude || coordinate.longitude != value.longitude { coordinate = value.coordinate }
            pin = value
        }
    }
    final class Coordinator: NSObject, MKMapViewDelegate {
        var owner: CityMapView
        var cameraID: UUID?
        var userMoved = false
        var active = true
        private var annotations: [String: PinAnnotation] = [:]
        init(_ owner: CityMapView) { self.owner = owner }
        func update(pins: [CityMapPin], in map: MKMapView) {
            let previous = annotations.mapValues(\.pin)
            let changes = CityMapPinChanges.between(previous, and: pins)
            guard !changes.removed.isEmpty || !changes.upserted.isEmpty else { return }
            // Update markers only. Never fit the camera to a new or empty result set.
            UIView.performWithoutAnimation {
                let removed = changes.removed.compactMap { annotations.removeValue(forKey: $0) }
                map.removeAnnotations(removed)
                for pin in changes.upserted {
                    if let annotation = annotations[pin.id] {
                        annotation.update(pin)
                        if let view = map.view(for: annotation) as? MKMarkerAnnotationView { style(view, pin: pin) }
                    } else {
                        let annotation = PinAnnotation(pin)
                        annotations[pin.id] = annotation
                        map.addAnnotation(annotation)
                    }
                }
            }
        }
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let annotation = annotation as? PinAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: "city-place", for: annotation) as! MKMarkerAnnotationView
            view.annotation = annotation
            style(view, pin: annotation.pin)
            view.glyphTintColor = .white
            view.animatesWhenAdded = false
            view.canShowCallout = false
            view.displayPriority = .defaultHigh
            return view
        }
        private func style(_ view: MKMarkerAnnotationView, pin: CityMapPin) {
            view.markerTintColor = UIColor(pin.isVehicle ? EventTheme.accent : pin.category.color)
            view.glyphImage = UIImage(systemName: pin.isVehicle ? "bus.fill" : pin.category.symbol)
            (view as? PlaceMarkerView)?.showHours(pin.isOpen24Hours, color: UIColor(pin.category.ink))
            view.accessibilityLabel = pin.title + (pin.isOpen24Hours ? ", денонощно, 24 часа" : "")
            view.accessibilityHint = pin.isVehicle ? "Виж последната GPS позиция" : "Отвори подробности за мястото"
        }
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let annotation = view.annotation as? PinAnnotation else { return }
            mapView.deselectAnnotation(annotation, animated: false)
            let id = annotation.pin.id
            // Deliver outside MapKit's update cycle and ignore a removed/replaced marker.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.active, self.annotations[id] === annotation else { return }
                self.owner.onSelect(id)
            }
        }
        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            userMoved = Self.hasActiveGesture(mapView)
        }
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let region = mapView.region, moved = userMoved, request = cameraID
            userMoved = false
            DispatchQueue.main.async { [weak self] in
                guard let self, self.active, self.cameraID == request else { return }
                self.owner.onRegionChange(region, moved)
            }
        }
        private static func hasActiveGesture(_ view: UIView) -> Bool {
            (view.gestureRecognizers ?? []).contains { $0.state == .began || $0.state == .changed }
                || view.subviews.contains(where: hasActiveGesture)
        }
    }
}
