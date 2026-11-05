import Foundation
import CryptoKit

struct GoogleRestaurantRequest {
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let restaurantID: String

    var matchKey: String {
        let identity = [restaurantID, name, address, String(latitude), String(longitude)].joined(separator: "\n")
        return "google.restaurant." + SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func widgetURL(base: URL, placeID: String?, embedded: Bool = false) -> URL? {
        guard latitude.isFinite, longitude.isFinite, (-90...90).contains(latitude), (-180...180).contains(longitude),
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              var parts = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return nil }
        // The fragment stays out of hosting request logs. No user position or session is sent.
        var fragment = URLComponents()
        fragment.queryItems = [
            .init(name: "name", value: String(name.prefix(200))),
            .init(name: "address", value: String(address.prefix(500))),
            .init(name: "lat", value: String(latitude)), .init(name: "lng", value: String(longitude))
        ]
        if let placeID, GoogleReviewsConfiguration.validPlaceID(placeID) {
            fragment.queryItems?.append(.init(name: "place", value: placeID))
        }
        if embedded { fragment.queryItems?.append(.init(name: "embedded", value: "1")) }
        parts.percentEncodedFragment = fragment.percentEncodedQuery
        return parts.url
    }
}

enum GoogleReviewsConfiguration {
    static var widgetURL: URL? { validatedURL(Bundle.main.object(forInfoDictionaryKey: "GoogleReviewsWidgetURL") as? String) }

    static func validatedURL(_ value: String?) -> URL? {
        guard let value, let parts = URLComponents(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              parts.scheme == "https", let host = parts.host, host.contains("."),
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              parts.port == nil || parts.port == 443 else { return nil }
        return parts.url
    }

    static func validPlaceID(_ value: String) -> Bool {
        (10...255).contains(value.utf8.count) && value.unicodeScalars.allSatisfy {
            CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-").contains($0)
        }
    }

    static func sameOrigin(_ candidate: URL, _ trusted: URL) -> Bool {
        candidate.scheme == "https" && candidate.host?.lowercased() == trusted.host?.lowercased()
            && (candidate.port ?? 443) == (trusted.port ?? 443) && candidate.user == nil && candidate.password == nil
    }

    static func embeddedHeight(_ reported: Double) -> Double? {
        guard reported.isFinite, reported > 0 else { return nil }
        return min(max(ceil(reported), 180), 12_000)
    }
}

struct GoogleRestaurantMatches {
    var defaults: UserDefaults = .standard
    private struct Match: Codable { let placeID: String; let confirmedAt: Date }
    func placeID(for request: GoogleRestaurantRequest, now: Date = .now) -> String? {
        guard let data = defaults.data(forKey: request.matchKey),
              let match = try? JSONDecoder().decode(Match.self, from: data),
              GoogleReviewsConfiguration.validPlaceID(match.placeID),
              (0...15_552_000).contains(now.timeIntervalSince(match.confirmedAt)) else { return nil }
        return match.placeID
    }
    func save(_ placeID: String, for request: GoogleRestaurantRequest, now: Date = .now) {
        guard GoogleReviewsConfiguration.validPlaceID(placeID),
              let data = try? JSONEncoder().encode(Match(placeID: placeID, confirmedAt: now)) else { return }
        // Only a user-selected Place ID is retained, never Google ratings, text or photos.
        defaults.set(data, forKey: request.matchKey)
    }
    func remove(for request: GoogleRestaurantRequest) { defaults.removeObject(forKey: request.matchKey) }
}
