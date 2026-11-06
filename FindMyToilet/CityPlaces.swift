import MapKit
import Combine

struct CityPlace: Identifiable {
    let item: MKMapItem
    let category: EventCategory
    var savedAddress: String? = nil
    var savedFavoriteID: String? = nil
    var source: CityPlaceSource = .appleMaps
    var sourceID: String? = nil
    var notes: String = ""
    var isNonstop: Bool? = nil
    var hours: [OpeningInterval]? = nil
    var phoneNumber: String? = nil
    var phoneURL: URL? {
        guard let phone = phoneNumber ?? item.phoneNumber else { return nil }
        let digits = phone.filter { "0123456789+*#".contains($0) }
        guard digits.count >= 3 else { return nil }
        return URL(string: "tel:\(digits)")
    }
    var hasKnown24HourSchedule: Bool {
        if let hours { return OpeningSchedule.isValid(hours) && OpeningSchedule.isAllDay(hours) }
        return isNonstop == true
    }
    func availability(at date: Date = .now) -> PlaceAvailability {
        // Only an explicit community 24/7 answer is evidence; a shop's name is not.
        OpeningSchedule.availability(hours ?? (isNonstop == true ? OpeningSchedule.allDay : nil), at: date)
    }
    var coordinate: CLLocationCoordinate2D { item.placemark.coordinate }
    var name: String { item.name ?? category.title }
    var id: String { sourceID.map { "\(source.rawValue):\($0)" } ?? "\(name)|\(coordinate.latitude)|\(coordinate.longitude)" }
    var address: String {
        if let savedAddress { return savedAddress }
        return [item.placemark.thoroughfare, item.placemark.subThoroughfare, item.placemark.locality]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
    // A transient destination for the existing walking navigator; never saved as a toilet.
    var walkingDestination: Toilet {
        Toilet(id: "mapkit:\(id)", name: name, address: address, latitude: coordinate.latitude,
               longitude: coordinate.longitude, kind: category.title, price: nil, currency: "EUR",
               amenities: [], hours: hours ?? (isNonstop == true ? OpeningSchedule.allDay : nil), accessNote: "", isDemo: false, verifiedAt: nil)
    }
}

enum CitySearchArea {
    static let burgas = MKCoordinateRegion(center: .init(latitude: 42.505, longitude: 27.474),
                                           span: .init(latitudeDelta: 0.055, longitudeDelta: 0.065))
    // Includes the outer city districts, not only the central map viewport.
    static let restaurantBurgas = MKCoordinateRegion(center: .init(latitude: 42.497, longitude: 27.465),
        span: .init(latitudeDelta: 0.16, longitudeDelta: 0.18))
    static func restaurantRegions(in region: MKCoordinateRegion) -> [MKCoordinateRegion] {
        guard CityMapViewport.isValid(region) else { return [] }
        if region.span.latitudeDelta < 0.025 && region.span.longitudeDelta < 0.035 { return [region] }
        let lat = region.span.latitudeDelta / 3, lon = region.span.longitudeDelta / 3
        // Central tiles first; nine bounded sequential requests, not an unbounded crawl.
        let offsets = [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)]
        return offsets.compactMap { row, column -> MKCoordinateRegion? in
            let centerLatitude = region.center.latitude + Double(row) * lat
            let south = max(-90, centerLatitude - lat / 2), north = min(90, centerLatitude + lat / 2)
            guard north > south else { return nil }
            let longitude = (region.center.longitude + Double(column) * lon + 540)
                .truncatingRemainder(dividingBy: 360) - 180
            return MKCoordinateRegion(center: .init(latitude: (south + north) / 2, longitude: longitude),
                span: .init(latitudeDelta: north - south, longitudeDelta: lon))
        }
    }
    static func contains(_ coordinate: CLLocationCoordinate2D, in region: MKCoordinateRegion) -> Bool {
        guard CLLocationCoordinate2DIsValid(coordinate), CityMapViewport.isValid(region) else { return false }
        let longitudeDistance = abs((coordinate.longitude - region.center.longitude + 540)
            .truncatingRemainder(dividingBy: 360) - 180)
        return abs(coordinate.latitude - region.center.latitude) <= region.span.latitudeDelta / 2
            && longitudeDistance <= region.span.longitudeDelta / 2
    }
    static func places(from items: [MKMapItem], category: EventCategory, region: MKCoordinateRegion, shopFilter: ShopFilter = .all) -> [CityPlace] {
        var seen = Set<String>()
        return items.compactMap { item in
            guard contains(item.placemark.coordinate, in: region) else { return nil }
            if let actualCategory = item.pointOfInterestCategory, !category.mapCategories.contains(actualCategory) { return nil }
            let place = CityPlace(item: item, category: category.section)
            guard category.section != .shopping || shopFilter.matches(place) else { return nil }
            return seen.insert(place.id).inserted ? place : nil
        }
    }
}

@MainActor
final class CityPlacesSearch: ObservableObject {
    @Published private(set) var places: [CityPlace] = []
    @Published private(set) var loading = false
    @Published private(set) var message: String?
    private var active: MKLocalSearch?
    private var generation: UUID?
    private let timeout: Duration
    private let batchPause: Duration
    private struct CachedSearch {
        let places: [CityPlace]
        let savedAt: Date
        let complete: Bool
    }
    private var caches: [String: CachedSearch] = [:]
    private var visibleKey: String?
    private func key(category: EventCategory, query: String, region: MKCoordinateRegion, shopFilter: ShopFilter) -> String {
        "\(category.rawValue)|\(query.trimmingCharacters(in: .whitespacesAndNewlines))|\(shopFilter.rawValue)|\(region.center.latitude)|\(region.center.longitude)|\(region.span.latitudeDelta)|\(region.span.longitudeDelta)"
    }
    private func cache(_ places: [CityPlace], for key: String, complete: Bool) {
        caches[key] = CachedSearch(places: places, savedAt: .now, complete: complete)
        if caches.count > 16, let oldest = caches.min(by: { $0.value.savedAt < $1.value.savedAt })?.key { caches.removeValue(forKey: oldest) }
    }
    // Switch the visible snapshot synchronously. Never show the previous type's results while debouncing.
    func prepare(category: EventCategory, query: String, region: MKCoordinateRegion, shopFilter: ShopFilter = .all) {
        cancel()
        let next = key(category: category, query: query, region: region, shopFilter: shopFilter)
        if visibleKey != next {
            places = caches[next]?.places ?? []
            visibleKey = next
        }
        message = nil
    }
    private let perform: (MKLocalSearch) async throws -> [MKMapItem]

    init(timeout: Duration = .seconds(20), batchPause: Duration = .milliseconds(400), perform: @escaping (MKLocalSearch) async throws -> [MKMapItem] = {
        try await $0.start().mapItems
    }) {
        self.timeout = timeout
        self.batchPause = batchPause
        self.perform = perform
    }

    func cancel(clear: Bool = false) {
        generation = nil
        active?.cancel()
        active = nil
        loading = false
        if clear { places = []; message = nil; visibleKey = nil }
    }

    func search(category: EventCategory, query: String, region: MKCoordinateRegion, shopFilter: ShopFilter = .all, force: Bool = false) async {
        guard !Task.isCancelled else { return }
        prepare(category: category, query: query, region: region, shopFilter: shopFilter)
        guard category != .toilets else { cancel(clear: true); return }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let broadRestaurantSearch = category == .restaurants && trimmed.isEmpty
        let cacheKey = key(category: category, query: query, region: region, shopFilter: shopFilter)
        if !force, let cache = caches[cacheKey], cache.complete, Date().timeIntervalSince(cache.savedAt) < 600 {
            return
        }
        let retainedSnapshot = !places.isEmpty
        // Health/fuel types use one bounded city query, avoiding nine repeated lookups on every switch.
        let regions = broadRestaurantSearch ? CitySearchArea.restaurantRegions(in: region) : [region]
        guard !regions.isEmpty else { return }
        let id = UUID()
        generation = id
        loading = true
        var combined: [MKMapItem] = []
        await withTaskCancellationHandler {
            for (index, area) in regions.enumerated() {
                guard generation == id, !Task.isCancelled else { return }
                // Natural-language searches accept regional hints larger than the POI API's 2 km radius.
                let request = MKLocalSearch.Request()
                let nonstop = category.section == .shopping && shopFilter == .nonstop
                request.naturalLanguageQuery = nonstop ? (trimmed.isEmpty ? "nonstop 24 hour shop" : "\(trimmed) nonstop 24 hour shop")
                    : (trimmed.isEmpty ? category.searchQuery : trimmed)
                request.region = area
                request.resultTypes = .pointOfInterest
                request.pointOfInterestFilter = MKPointOfInterestFilter(including: category.mapCategories)
                let operation = MKLocalSearch(request: request)
                active = operation
                let deadline = Task { [weak self, timeout] in
                    do { try await Task.sleep(for: timeout) } catch { return }
                    guard let self, self.generation == id else { return }
                    self.cancel()
                    self.message = self.places.isEmpty ? "Търсенето се забави. Опитайте отново." : "Показваме част от местата. Обнови за останалите райони."
                }
                do {
                    let items = try await perform(operation)
                    deadline.cancel()
                    guard generation == id, !Task.isCancelled else { return }
                    combined.append(contentsOf: items)
                    let results = CitySearchArea.places(from: combined, category: category, region: region, shopFilter: shopFilter)
                    // Retain an already displayed snapshot during refresh; replace it only after the last area.
                    if !retainedSnapshot || index == regions.count - 1 {
                        places = results
                        cache(results, for: cacheKey, complete: index == regions.count - 1)
                    }
                    active = nil
                    if index < regions.count - 1 { try await Task.sleep(for: batchPause) }
                } catch {
                    deadline.cancel()
                    guard generation == id else { return }
                    cancel()
                    if !Task.isCancelled {
                        message = places.isEmpty ? (category.isHealthcare ? "Apple Maps не се зареди. Показваме наличните места от каталога и общността." : "Местата не се заредиха. Провери интернет и опитай отново.")
                            : "Показваме част от местата. Обнови за останалите райони."
                    }
                    return
                }
            }
            guard generation == id, !Task.isCancelled else { return }
            loading = false
            active = nil
            generation = nil
        } onCancel: {
            Task { @MainActor [weak self] in
                if self?.generation == id { self?.cancel() }
            }
        }
    }

}

extension EventCategory {
    var searchQuery: String {
        switch self {
        case .toilets: return "toilets"
        case .restaurants: return "restaurants cafes"
        case .atms: return "ATM"
        case .convenience: return "24 hour convenience store"
        case .shopping: return "shops supermarket"
        case .hospitals: return "hospitals Burgas"
        case .pharmacies: return "pharmacies Burgas"
        case .fuel: return "petrol gas stations"
        case .charging: return "EV charging stations"
        case .transport: return "bus stop station"
        }
    }
    var mapCategories: [MKPointOfInterestCategory] {
        switch self {
        case .toilets: return []
        case .restaurants: return [.restaurant, .cafe, .bakery]
        case .atms: return [.atm]
        case .convenience, .shopping: return [.store]
        case .hospitals: return [.hospital]
        case .pharmacies: return [.pharmacy]
        case .fuel: return [.gasStation]
        case .charging: return [.evCharger]
        case .transport: return [.publicTransport]
        }
    }
}

// Only explicit recenter actions issue camera commands; pin updates never do.
struct CityMapCameraRequest {
    let id = UUID()
    let region: MKCoordinateRegion
}
struct CityMapViewport {
    private(set) var region = CitySearchArea.burgas
    private(set) var camera = CityMapCameraRequest(region: CitySearchArea.burgas)
    private(set) var restoredCamera: MKMapCamera?
    private(set) var needsSearch = false
    private(set) var hasChosenArea = false
    mutating func record(_ value: MKCoordinateRegion, userMoved: Bool, mapCamera: MKMapCamera? = nil) {
        guard Self.isValid(value) else { return }
        region = value
        if let mapCamera { restoredCamera = mapCamera.copy() as? MKMapCamera }
        if userMoved { needsSearch = true; hasChosenArea = true }
    }
    mutating func recenter(_ value: MKCoordinateRegion) {
        guard Self.isValid(value) else { return }
        region = value
        camera = CityMapCameraRequest(region: value)
        restoredCamera = nil
        needsSearch = false
        hasChosenArea = true
    }
    mutating func markSearched() { needsSearch = false }
    func discoveryRegion(for category: EventCategory) -> MKCoordinateRegion {
        // Start with the city catalogue, but respect a neighbourhood the visitor chose.
        if !hasChosenArea && (category == .restaurants || category.isHealthcare || category.isFuel) {
            return CitySearchArea.restaurantBurgas
        }
        return region
    }
    static func isValid(_ value: MKCoordinateRegion) -> Bool {
        CLLocationCoordinate2DIsValid(value.center)
            && value.span.latitudeDelta.isFinite && value.span.longitudeDelta.isFinite
            && value.span.latitudeDelta > 0 && value.span.latitudeDelta <= 180
            && value.span.longitudeDelta > 0 && value.span.longitudeDelta <= 360
    }
}

// A pinch/pan can trigger several region callbacks, including callbacks during deceleration.
// Latch user intent until the latest settled region is actually delivered to SwiftUI.
struct CityMapInteraction {
    private(set) var revision: UInt64 = 0
    private var userMoved = false
    @discardableResult mutating func changed(userGesture: Bool) -> Bool {
        let began = userGesture && !userMoved
        revision &+= 1
        userMoved = userMoved || userGesture
        return began
    }
    mutating func complete(revision expected: UInt64) -> Bool? {
        guard expected == revision else { return nil }
        let moved = userMoved
        userMoved = false
        return moved
    }
    mutating func reset() {
        revision &+= 1
        userMoved = false
    }
}

struct CityMapPin: Identifiable, Equatable {
    let id: String
    let title: String
    let latitude: Double
    let longitude: Double
    let category: EventCategory
    var isVehicle = false
    var isOpen24Hours = false
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    init(bus: BurgasLiveBus) {
        id = "bus:\(bus.id)"; title = bus.title; latitude = bus.latitude; longitude = bus.longitude
        category = .transport; isVehicle = true
    }
    init(toilet: Toilet) {
        id = "toilet:\(toilet.id)"; title = toilet.name
        latitude = toilet.latitude; longitude = toilet.longitude; category = .toilets
    }
    init(place: CityPlace) {
        id = "place:\(place.category.section.rawValue):\(place.id)"; title = place.name
        latitude = place.coordinate.latitude; longitude = place.coordinate.longitude; category = place.category.section
        isOpen24Hours = place.hasKnown24HourSchedule
    }
}

struct CityMapPinChanges {
    let removed: [String]
    let upserted: [CityMapPin]
    static func between(_ old: [String: CityMapPin], and pins: [CityMapPin]) -> CityMapPinChanges {
        var next: [String: CityMapPin] = [:]
        for pin in pins where CLLocationCoordinate2DIsValid(pin.coordinate) { next[pin.id] = pin }
        return CityMapPinChanges(removed: old.keys.filter { next[$0] == nil },
                                upserted: next.values.filter { old[$0.id] != $0 })
    }
}

// Small offline starting catalogue, supplemented by live Apple Maps searches.
// Sources and OSM record IDs are documented in Backend/HEALTHCARE.md.
// Coordinates identify buildings/places, not verified emergency entrances.
enum HealthcareDirectory {
    static let places: [CityPlace] = [
        place("umbal-burgas", "УМБАЛ Бургас", .hospitals, "бул. „Стефан Стамболов“ 73", 42.5135674, 27.4659001,
              "https://www.mbalburgas.com/", nil),
        place("burgasmed", "МБАЛ Бургасмед", .hospitals, "ж.к. „Меден рудник“, зона А", 42.4633517, 27.420723,
              "https://www.hospitalburgasmed.bg/contacts.block1.php", "+35956999980"),
        place("heart-brain-burgas", "Сърце и Мозък — Бургас", .hospitals, "ул. „Здраве“ 1", 42.5276865, 27.445044,
              "https://cardiacinstitute.bg/en/hospitals-and-centers/heart-and-brain-center-of-excellence-burgas/contacts/", "+35956703003"),
        place("puls-slaveykov", "Аптека Пулс 2", .pharmacies, "ж.к. „Славейков“, бл. 77", 42.5200065, 27.4513466,
              "https://www.pulsapteka.com/kontakti", "+35956700111", hours: OpeningSchedule.allDay),
        place("sopharmacy-pirgos", "SOpharmacy — Pirgos Park", .pharmacies, "бул. „Янко Комитов“ 4", 42.5120086, 27.4557593,
              "https://pirgospark.bg/obekti/sopharmacy/", "+35924059379",
              hours: (1...7).map { OpeningInterval(weekday: $0, opens: 9 * 60, closes: 20 * 60) })
    ]
    private static func place(_ id: String, _ name: String, _ category: EventCategory, _ address: String,
                              _ latitude: Double, _ longitude: Double, _ website: String, _ phone: String?,
                              hours: [OpeningInterval]? = nil) -> CityPlace {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: .init(latitude: latitude, longitude: longitude)))
        item.name = name; item.url = URL(string: website); item.phoneNumber = phone
        return CityPlace(item: item, category: category, savedAddress: address, source: .healthcareDirectory, sourceID: id,
            notes: category == .hospitals
                ? "Адрес и контакти: официалният сайт, справка 14.10.2026. Точката е за болницата, не за потвърден спешен вход. Провери отделението преди посещение."
                : "Работно време: публикуваният график на сайта, справка 14.10.2026. Възможни празнични промени. Обади се за потвърждение преди посещение.",
            isNonstop: hours.map { OpeningSchedule.isAllDay($0) }, hours: hours, phoneNumber: phone)
    }

    // Match an Apple result to a known branch only when BOTH its name and location agree.
    // This avoids two pins for one pharmacy and prevents transferring hours to a different branch.
    static func isSamePlace(_ a: CityPlace, _ b: CityPlace) -> Bool {
        guard a.category == b.category, a.category.isHealthcare else { return false }
        let distance = CLLocation(latitude: a.coordinate.latitude, longitude: a.coordinate.longitude)
            .distance(from: CLLocation(latitude: b.coordinate.latitude, longitude: b.coordinate.longitude))
        guard distance < 100 else { return false }
        func key(_ name: String) -> String {
            let normalized = name.applyingTransform(.toLatin, reverse: false) ?? name
            return normalized.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
                .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
        }
        let lhs = key(a.name), rhs = key(b.name)
        let brands = ["sopharmacy", "puls", "burgasmed", "umbal burgas", "sarce i mozak", "serdce i mozak"]
        return lhs == rhs || brands.contains { lhs.contains($0) && rhs.contains($0) }
    }
}
