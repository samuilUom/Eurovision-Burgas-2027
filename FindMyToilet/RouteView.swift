import SwiftUI
import MapKit


@MainActor
final class WalkingRoute: ObservableObject {
    @Published var route: MKRoute?
    @Published var destination: Toilet?
    @Published var origin: CLLocationCoordinate2D?
    @Published var loading = false
    @Published var error: String?
    private var directions: MKDirections?
    private var requestID = UUID()
    private var timeoutTask: Task<Void, Never>?
    private let timeoutNanoseconds: UInt64
    private let calculateRoutes: (MKDirections) async throws -> [MKRoute]

    init(timeoutNanoseconds: UInt64 = 25_000_000_000,
         calculateRoutes: @escaping (MKDirections) async throws -> [MKRoute] = { try await $0.calculate().routes }) {
        self.timeoutNanoseconds = timeoutNanoseconds
        self.calculateRoutes = calculateRoutes
    }

    func cancel() {
        requestID = UUID()
        timeoutTask?.cancel()
        timeoutTask = nil
        directions?.cancel()
        directions = nil
        loading = false
    }
    func reset() {
        cancel()
        route = nil
        error = nil
        destination = nil
        origin = nil
    }
    func calculate(from location: CLLocation, destinations: [Toilet]) async {
        reset()
        guard let target = RouteSelection.nearest(in: destinations, to: location) else {
            error = "Няма налични места за този маршрут."
            return
        }
        destination = target
        origin = location.coordinate
        loading = true
        let id = requestID
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: target.coordinate))
        request.transportType = .walking
        request.requestsAlternateRoutes = false
        let service = MKDirections(request: request)
        directions = service
        timeoutTask = Task { [weak self, timeoutNanoseconds] in
            do { try await Task.sleep(nanoseconds: timeoutNanoseconds) } catch { return }
            guard let self, self.requestID == id, self.loading else { return }
            self.requestID = UUID()
            self.directions?.cancel()
            self.directions = nil
            self.loading = false
            self.error = "Изчисляването отнема твърде дълго. Натиснете „Опитай отново“."
        }
        do {
            let routes = try await calculateRoutes(service)
            guard id == requestID, !Task.isCancelled else { return }
            timeoutTask?.cancel()
            timeoutTask = nil
            directions = nil
            guard let route = routes.min(by: { $0.expectedTravelTime < $1.expectedTravelTime }) else {
                loading = false
                error = "За това място не е намерен пешеходен маршрут."
                return
            }
            self.route = route
            loading = false
            directions = nil
        } catch {
            guard id == requestID, !Task.isCancelled else { return }
            timeoutTask?.cancel()
            timeoutTask = nil
            loading = false
            directions = nil
            if let mapError = error as? MKError, mapError.code == .directionsNotFound {
                self.error = "За това място няма наличен пешеходен маршрут. Опитайте друго място от картата."
            } else {
                self.error = "Маршрутът не може да бъде зареден. Проверете интернет връзката и натиснете „Опитай отново“."
            }
        }
    }
}

struct RouteView: View {
    let destinations: [Toilet]
    let nearest: Bool
    var destinationSymbol = "toilet.fill"
    var category: EventCategory = .toilets
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var sharedLocation: LocationService
    @StateObject private var location = LocationService()
    @StateObject private var walking = WalkingRoute()
    @State private var position: MapCameraPosition = .userLocation(followsHeading: true, fallback: .region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 42.497, longitude: 27.473),
                           span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012))))
    @State private var lastRouteLocation: CLLocation?
    @State private var lastRouteDate = Date.distantPast
    @State private var selectedDestination: Toilet?
    @State private var calculation: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Map(position: $position, bounds: MapCameraBounds(minimumDistance: 100, maximumDistance: 3000)) {
                    UserAnnotation()
                    if let target = walking.destination { Marker(target.name, coordinate: target.coordinate).tint(category.color) }
                    if let route = walking.route { MapPolyline(route.polyline).stroke(category.color, lineWidth: 6) }
                }
                .mapControls { MapCompass(); MapScaleView(); MapUserLocationButton() }
                .frame(minHeight: 180)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.border, lineWidth: 1))
                .padding(.horizontal, 12).padding(.top, 8)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if location.isLocating { ProgressView("Определяне на местоположението…") }
                        if walking.loading { ProgressView("Изчисляване на пешеходен маршрут…") }
                        if let message = location.message {
                            Label(message, systemImage: "location.slash").font(.subheadline)
                            if location.denied {
                                Button("Разреши местоположение в Настройки") {
                                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                                }
                            }
                        }
                        if let error = walking.error {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline).foregroundStyle(.orange)
                                .padding(14).frame(maxWidth: .infinity, alignment: .leading).appCard(cornerRadius: 16)
                        }
                        if (walking.error != nil || location.message != nil) && !location.denied {
                            Button { refresh() } label: {
                                Label("Опитай отново", systemImage: "arrow.clockwise").frame(maxWidth: .infinity)
                            }.buttonStyle(AppSecondaryButtonStyle(color: category.color, ink: category.ink)).disabled(location.isLocating || walking.loading)
                        }
                        if let target = walking.destination {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: destinationSymbol).font(.title2).foregroundStyle(category.ink)
                                    .frame(width: 48, height: 48)
                                    .background(category.ink.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(target.name).font(.title3.bold())
                                    Text(target.address).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                            if target.isDemo { DemoNotice() }
                        }
                        if nearest {
                            Text("Избрано е най-близкото място по права линия сред резултатите от филтрите.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if let route = walking.route {
                            HStack(spacing: 12) {
                                routeMetric(String(format: "%.1f км", route.distance / 1000), subtitle: "разстояние", symbol: "figure.walk")
                                routeMetric("≈ \(max(1, Int(ceil(route.expectedTravelTime / 60)))) мин", subtitle: "пеша", symbol: "clock")
                            }
                            Text("Позицията Ви се обновява на живо. Маршрутът се обновява при придвижване. След местене на картата натиснете стрелката за местоположение, за да Ви следва отново. Няма гласови инструкции.")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("Стъпка по стъпка").font(.headline).padding(.top, 4)
                            ForEach(Array(route.steps.filter { !$0.instructions.isEmpty }.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)").font(.subheadline.bold())
                                        .foregroundStyle(category.ink).frame(width: 36, height: 36)
                                        .background(category.ink.opacity(0.09), in: Circle())
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(step.instructions).font(.subheadline.weight(.medium))
                                            .fixedSize(horizontal: false, vertical: true)
                                        if step.distance > 0 { Text("\(Int(step.distance)) м").font(.caption).foregroundStyle(.secondary) }
                                    }
                                    Spacer(minLength: 0)
                                }.padding(14).frame(maxWidth: .infinity, alignment: .leading).appCard(cornerRadius: 16)
                            }
                        }
                        Text("Маршрутът се показва тук чрез MapKit и изисква интернет. Достъпността за инвалидна количка не е потвърдена.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding()
                }.frame(maxHeight: 350)
            }
            .background(Theme.background)
            .navigationTitle(nearest ? (destinationSymbol == "toilet.fill" ? "До най-близката" : "До най-близкото място") : "Пешеходен маршрут")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Затвори") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("Обнови") { refresh() }.disabled(location.isLocating || walking.loading) }
            }
            .onAppear { startNavigation() }
            .onReceive(location.$location) { value in
                guard scenePhase != .background, let value else { return }
                updateRoute(from: value)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { startNavigation() }
                else if phase == .background {
                    location.stopTracking()
                    calculation?.cancel()
                    walking.cancel()
                    lastRouteLocation = nil
                }
            }
            .onDisappear {
                location.stopTracking()
                calculation?.cancel()
                walking.cancel()
            }
        }
    }
    private func routeMetric(_ value: String, subtitle: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(value, systemImage: symbol).font(.headline).foregroundStyle(category.ink)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(14).appCard(cornerRadius: 16)
    }
    private func startNavigation() {
        location.startTracking()
        // A fresh fix already obtained on the home map can start the route immediately.
        if !walking.loading, let current = [location.location, sharedLocation.location].compactMap({ $0 }).first(where: { RouteSelection.isRecentLocation($0) }) {
            updateRoute(from: current, force: walking.route == nil)
        }
    }
    private func updateRoute(from value: CLLocation, force: Bool = false) {
        guard RouteSelection.isRecentLocation(value), force || !walking.loading else { return }
        if !force, let previous = lastRouteLocation {
            guard Date().timeIntervalSince(lastRouteDate) >= 30,
                  value.distance(from: previous) >= 50 || walking.route == nil else { return }
        }
        // Keep the chosen toilet stable as the user walks; do not switch destinations on each GPS fix.
        if selectedDestination == nil {
            selectedDestination = RouteSelection.nearest(in: destinations, to: value)
        }
        let targets = selectedDestination.map { [$0] } ?? destinations
        lastRouteLocation = value
        lastRouteDate = Date()
        calculation?.cancel()
        calculation = Task {
            await walking.calculate(from: value, destinations: targets)
        }
    }
    private func refresh() {
        if let current = location.location, RouteSelection.isRecentLocation(current) {
            updateRoute(from: current, force: true)
        } else {
            lastRouteLocation = nil
            location.startTracking()
        }
    }
}
