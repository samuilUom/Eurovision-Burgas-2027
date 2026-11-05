import Foundation
import Combine

struct RestaurantReview: Decodable, Identifiable, Hashable {
    let id: UUID
    let place_id: String
    let author_id: String
    let rating: Int
    let comment: String
    let updated_at: String
    var author_name: String?
}

struct RestaurantPhoto: Decodable, Identifiable, Hashable {
    let id: UUID
    let place_id: String
    let author_id: String
    let caption: String
    let thumbnail_base64: String
    let created_at: String
    var author_name: String?
    var thumbnail: Data? { Data(base64Encoded: thumbnail_base64) }
}

struct RestaurantSnapshot: Decodable {
    let review_count: Int
    let photo_count: Int
    let average_rating: Double?
    let reviews: [RestaurantReview]
    let photos: [RestaurantPhoto]
    let my_review: RestaurantReview?
}

enum RestaurantLoadFailure: Equatable {
    case setupRequired, offline, timedOut, authentication, permission, rateLimited, server, invalidResponse, unknown

    static func classify(_ error: Error) -> Self {
        if let cloud = error as? CloudError {
            if ["PGRST202", "PGRST205", "42P01", "42883", "42703"].contains(cloud.code ?? "") { return .setupRequired }
            if cloud.status == 401 { return .authentication }
            if cloud.status == 403 || cloud.code == "42501" { return .permission }
            if cloud.status == 429 { return .rateLimited }
            if let status = cloud.status, status >= 500 { return .server }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff: return .offline
            case .timedOut: return .timedOut
            default: return .server
            }
        }
        if error is DecodingError { return .invalidResponse }
        return .unknown
    }
    var title: String {
        switch self {
        case .setupRequired: return "Споделянето още не е активирано"
        case .offline: return "Няма връзка с интернет"
        case .timedOut: return "Заявката отне твърде дълго"
        case .authentication: return "Влез отново в профила си"
        case .permission: return "Достъпът е отказан"
        case .rateLimited: return "Изчакай малко"
        case .server: return "Сървърът не е достъпен"
        case .invalidResponse: return "Данните не могат да се прочетат"
        case .unknown: return "Общността не се зареди"
        }
    }
    var message: String {
        switch self {
        case .setupRequired:
            return "Ревютата и снимките за ресторанти трябва да бъдат активирани от администратора. Това не е проблем с твоя Wi-Fi."
        case .offline: return "Провери интернет връзката си и опитай отново."
        case .timedOut: return "Отговорът не пристигна навреме. Опитай отново след малко."
        case .authentication: return "Отвори „Профил“ и влез отново, след което обнови страницата."
        case .permission: return "Администраторът трябва да провери достъпа до споделените ревюта и снимки."
        case .rateLimited: return "Има твърде много заявки. Опитай отново след малко."
        case .server: return "Не успяхме да се свържем с услугата. Опитай по-късно."
        case .invalidResponse: return "Опитай отново. Ако проблемът остане, съобщи на администратора."
        case .unknown: return "Опитай отново. Ако проблемът остане, съобщи на администратора."
        }
    }
    var symbol: String {
        switch self {
        case .setupRequired: return "gearshape.badge.exclamationmark"
        case .offline: return "wifi.exclamationmark"
        case .authentication, .permission: return "lock.circle"
        case .timedOut, .rateLimited: return "clock"
        default: return "exclamationmark.circle"
        }
    }
}

enum RestaurantContribution {
    static let pageSize = 20
    static let maxPhotoBytes = 500_000
    static let maxThumbnailBytes = 65_000
    static func validReview(rating: Int, comment: String) -> Bool {
        (1...5).contains(rating) && comment.unicodeScalars.count <= 2000
    }
    static func mayDelete(author: String, user: String?, admin: Bool) -> Bool {
        guard let user else { return false }
        return admin || author.lowercased() == user.lowercased()
    }
    static func date(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

// Only the open restaurant's thumbnails and review page are loaded, never every
// full-size image at launch. A new account/place invalidates in-flight results.
@MainActor
final class RestaurantFeed: ObservableObject {
    enum Page { case reviews, photos }
    @Published private(set) var reviews: [RestaurantReview] = []
    @Published private(set) var photos: [RestaurantPhoto] = []
    @Published private(set) var myReview: RestaurantReview?
    @Published private(set) var reviewCount = 0
    @Published private(set) var photoCount = 0
    @Published private(set) var average: Double?
    @Published private(set) var loading = false
    @Published private(set) var loaded = false
    @Published private(set) var failure: RestaurantLoadFailure?
    var error: String? { failure?.message }
    private var generation = UUID()
    private var reviewOffset = 0
    private var photoOffset = 0
    var moreReviews: Bool { reviewOffset < reviewCount }
    var morePhotos: Bool { photoOffset < photoCount }

    func reset() {
        generation = UUID(); loading = false; loaded = false; failure = nil
        reviews = []; photos = []; myReview = nil; average = nil
        reviewCount = 0; photoCount = 0; reviewOffset = 0; photoOffset = 0
    }
    func load(page: Page? = nil, fetch: (Int, Int) async throws -> RestaurantSnapshot) async {
        guard !loading else { return }
        let request = generation
        loading = true; failure = nil
        defer { if generation == request { loading = false } }
        do {
            let value = try await fetch(page == .reviews ? reviewOffset : 0, page == .photos ? photoOffset : 0)
            try Task.checkCancellation()
            guard request == generation else { return }
            reviewCount = value.review_count; photoCount = value.photo_count
            average = value.average_rating; myReview = value.my_review
            if page != .photos {
                if page == nil { reviews = []; reviewOffset = 0 }
                reviewOffset += value.reviews.count
                for row in value.reviews where !reviews.contains(where: { $0.id == row.id }) { reviews.append(row) }
                if value.reviews.isEmpty { reviewOffset = reviewCount }
            }
            if page != .reviews {
                if page == nil { photos = []; photoOffset = 0 }
                photoOffset += value.photos.count
                for row in value.photos where !photos.contains(where: { $0.id == row.id }) { photos.append(row) }
                if value.photos.isEmpty { photoOffset = photoCount }
            }
            loaded = true
        } catch is CancellationError { }
        catch let error as URLError where error.code == .cancelled { }
        catch {
            if request == generation && !Task.isCancelled {
                failure = RestaurantLoadFailure.classify(error)
            }
        }
    }
}
