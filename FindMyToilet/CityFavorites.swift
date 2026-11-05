import Foundation
import MapKit
import CryptoKit

struct SavedCityPlace: Codable, Identifiable, Equatable {
    let id: String
    let category: EventCategory
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let website: String?
    let savedAt: Date
    var source: CityPlaceSource? = nil
    var sourceID: String? = nil
    var notes: String? = nil
    var isNonstop: Bool? = nil
    var hours: [OpeningInterval]? = nil
    var phoneNumber: String? = nil

    init(place: CityPlace, savedAt: Date = .now) {
        id = Self.identifier(for: place)
        category = place.category
        name = String(place.name.prefix(200))
        address = String(place.address.prefix(500))
        latitude = place.coordinate.latitude
        longitude = place.coordinate.longitude
        website = Self.safeWebsite(place.item.url?.absoluteString)
        self.savedAt = savedAt
        source = place.source
        sourceID = place.sourceID
        notes = String(place.notes.prefix(500))
        isNonstop = place.isNonstop
        hours = place.hours
        phoneNumber = place.phoneNumber ?? place.item.phoneNumber
    }
    static func identifier(for place: CityPlace) -> String {
        if let savedID = place.savedFavoriteID { return savedID }
        return identity(name: place.name, latitude: place.coordinate.latitude, longitude: place.coordinate.longitude, category: place.category)
    }
    private static func identity(name: String, latitude: Double, longitude: Double, category: EventCategory) -> String {
        let normalized = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let coordinates = String(format: "%.5f,%.5f", locale: Locale(identifier: "en_US_POSIX"), latitude, longitude)
        return digest("\(category.rawValue)|\(normalized)|\(coordinates)")
    }
    // Group legacy convenience records with shops without rewriting server IDs or queued edits.
    var groupID: String { Self.identity(name: name, latitude: latitude, longitude: longitude, category: category.section) }
    static func groupIdentifier(for place: CityPlace) -> String {
        identity(name: String(place.name.prefix(200)), latitude: place.coordinate.latitude, longitude: place.coordinate.longitude, category: place.category.section)
    }
    private var sourceIdentity: String? {
        guard let source, source != .appleMaps, let sourceID else { return nil }
        return "\(source.rawValue):\(source == .community ? sourceID.lowercased() : sourceID)"
    }
    func matches(_ place: CityPlace) -> Bool {
        if let sourceIdentity, sourceIdentity == SavedCityPlace(place: place).sourceIdentity { return true }
        return groupID == Self.groupIdentifier(for: place)
    }
    static func uniquePlaces(_ values: [SavedCityPlace]) -> [SavedCityPlace] {
        var seen = Set<String>(), sources = Set<String>()
        return values.sorted { $0.savedAt == $1.savedAt ? $0.id < $1.id : $0.savedAt > $1.savedAt }
            .filter { value in
                guard seen.insert(value.groupID).inserted else { return false }
                if let identity = value.sourceIdentity { return sources.insert(identity).inserted }
                return true
            }
    }
    static func safeWebsite(_ value: String?) -> String? {
        guard let value, value.count <= 2048, let url = URL(string: value), url.host != nil,
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        return value
    }
    var isValid: Bool {
        category != .toilets && id.count == 64 && id.allSatisfy { "0123456789abcdef".contains($0) }
            && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 200 && address.count <= 500
            && CLLocationCoordinate2DIsValid(.init(latitude: latitude, longitude: longitude))
            && (website == nil || Self.safeWebsite(website) != nil)
            && (hours.map(OpeningSchedule.isValid) ?? true)
    }
    var place: CityPlace {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: .init(latitude: latitude, longitude: longitude)))
        item.name = name
        item.url = website.flatMap(URL.init(string:))
        return CityPlace(item: item, category: category, savedAddress: address, savedFavoriteID: id,
                         source: source ?? .appleMaps, sourceID: sourceID, notes: notes ?? "", isNonstop: isNonstop, hours: hours, phoneNumber: phoneNumber)
    }
}

private func digest(_ value: String) -> String {
    SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
}

struct CityFavoriteScope: Codable, Equatable {
    let server: String
    let userID: String
    init(server: String, userID: String) {
        self.server = server.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        self.userID = userID.lowercased()
    }
    var filename: String { digest("\(server)|\(userID)") + ".json" }
}

struct CityFavoriteChange: Codable, Equatable {
    let id: String
    let place: SavedCityPlace? // nil is a pending removal, retained across restarts.
}

struct CityFavoriteState: Codable, Equatable {
    let scope: CityFavoriteScope
    var places: [SavedCityPlace] = []
    var pending: [CityFavoriteChange] = []

    mutating func save(_ place: SavedCityPlace) {
        places.removeAll { $0.id == place.id }; places.append(place)
        pending.removeAll { $0.id == place.id }; pending.append(.init(id: place.id, place: place))
    }
    mutating func remove(_ id: String) {
        places.removeAll { $0.id == id }
        pending.removeAll { $0.id == id }; pending.append(.init(id: id, place: nil))
    }
    mutating func removeGroup(_ groupID: String) {
        let ids = places.filter { $0.groupID == groupID }.map(\.id)
        for id in ids { remove(id) }
    }
    mutating func acceptRemote(_ remote: [SavedCityPlace]) {
        var merged: [String: SavedCityPlace] = [:]
        for place in remote where place.isValid { merged[place.id] = place }
        for change in pending { merged[change.id] = change.place }
        places = Array(merged.values)
    }
    var isValid: Bool {
        places.allSatisfy(\.isValid) && Set(places.map(\.id)).count == places.count
            && Set(pending.map(\.id)).count == pending.count
            && pending.allSatisfy { change in
                change.id.count == 64 && change.id.allSatisfy { "0123456789abcdef".contains($0) }
                    && (change.place == nil || (change.place?.isValid == true && change.place?.id == change.id))
            }
    }
}

enum CityFavoriteCache {
    static func url(for scope: CityFavoriteScope, directory: URL? = nil) throws -> URL {
        let folder: URL
        if let directory { folder = directory }
        else {
            folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                  appropriateFor: nil, create: true).appendingPathComponent("CityFavorites", isDirectory: true)
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent(scope.filename)
    }
    static func read(_ scope: CityFavoriteScope, directory: URL? = nil) throws -> CityFavoriteState {
        let file = try url(for: scope, directory: directory)
        guard FileManager.default.fileExists(atPath: file.path) else { return CityFavoriteState(scope: scope) }
        let state = try JSONDecoder().decode(CityFavoriteState.self, from: Data(contentsOf: file))
        guard state.scope == scope, state.isValid else { throw CocoaError(.fileReadCorruptFile) }
        return state
    }
    static func write(_ state: CityFavoriteState, directory: URL? = nil) throws {
        guard state.isValid else { throw CocoaError(.fileWriteInapplicableStringEncoding) }
        try JSONEncoder().encode(state).write(to: url(for: state.scope, directory: directory), options: .atomic)
    }
}

struct CityFavoriteRow: Codable {
    let user_id: String
    let place_id: String
    let category: String
    let payload: SavedCityPlace
}
