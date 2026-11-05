import Foundation
import MapKit

enum CityPlaceSource: String, Codable {
    case appleMaps, community, burgasbus, healthcareDirectory
    var title: String {
        switch self {
        case .healthcareDirectory: return "Каталог · официални сайтове"
        case .appleMaps: return "Apple Maps"
        case .community: return "Добавено от общността"
        case .burgasbus: return "Бургасбус · официални данни"
        }
    }
}

struct CommunityPlace: Codable, Identifiable, Equatable {
    var id: String
    var created_by: String
    var category: EventCategory
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var website: String?
    var notes: String
    var is_nonstop: Bool?
    var hours: [OpeningInterval]? = nil

    static let categories: [EventCategory] = [.restaurants, .atms, .shopping, .hospitals, .pharmacies, .fuel, .charging, .transport]
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    var validationMessage: String? {
        guard UUID(uuidString: id) != nil, UUID(uuidString: created_by) != nil else { return "Влез отново в профила си." }
        guard Self.categories.contains(category) else { return "Избери категория за мястото." }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 200 else { return "Въведи име до 200 знака." }
        guard address.count <= 500, notes.count <= 2000 else { return "Съкрати адреса или описанието." }
        guard CLLocationCoordinate2DIsValid(coordinate) else { return "Избери валидно място на картата." }
        if let website, SavedCityPlace.safeWebsite(website) == nil { return "Въведи пълен уеб адрес с https:// или http://." }
        if !category.supportsNonstop && is_nonstop != nil { return "Денонощният режим е за магазини, аптеки и места за зареждане." }
        if let hours, !OpeningSchedule.isValid(hours) { return "Провери работните часове. За цял ден избери 24 часа." }
        return nil
    }
    var place: CityPlace {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = name
        item.url = website.flatMap(URL.init(string:))
        return CityPlace(item: item, category: category, savedAddress: address,
                         source: .community, sourceID: id, notes: notes, isNonstop: is_nonstop, hours: hours)
    }
}

enum CityPlaceCatalogue {
    // Prefer community/provider records over matching search hits, without merging distinct branches.
    static func visible(_ places: [CityPlace], category: EventCategory, query: String,
                        region: MKCoordinateRegion, shopFilter: ShopFilter, pharmacyFilter: PharmacyFilter = .all, at date: Date = .now) -> [CityPlace] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var seen = Set<String>()
        var healthcare: [CityPlace] = []
        return places.filter { place in
            guard place.category.section == category.section
                && CitySearchArea.contains(place.coordinate, in: region)
                && (place.source == .appleMaps || term.isEmpty || "\(place.name) \(place.address)".localizedStandardContains(term))
                && seen.insert(SavedCityPlace.groupIdentifier(for: place)).inserted else { return false }
            if category.isHealthcare {
                guard !healthcare.contains(where: { HealthcareDirectory.isSamePlace($0, place) }) else { return false }
                healthcare.append(place)
            }
            return true
        // Deduplicate first so a closed community record cannot reappear as an unknown Apple Maps hit.
        }.filter { (category.section != .shopping || shopFilter.matches($0))
            && (category != .pharmacies || pharmacyFilter.matches($0))
            && (category.section == .transport || category.isHealthcare || $0.availability(at: date).appearsInDiscovery) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
