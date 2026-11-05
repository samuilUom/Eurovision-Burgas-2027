import Foundation
import CoreLocation

enum Amenity: String, Codable, CaseIterable, Identifiable {
    case wheelchair, changingTable, water
    var id: String { rawValue }
    var title: String {
        switch self {
        case .wheelchair: return "Достъп за количка"
        case .changingTable: return "Място за повиване"
        case .water: return "Течаща вода"
        }
    }
    var symbol: String {
        switch self {
        case .wheelchair: return "figure.roll"
        case .changingTable: return "figure.child"
        case .water: return "drop"
        }
    }
}

struct OpeningInterval: Codable, Equatable {
    // Calendar weekday: Sunday = 1. Minutes from midnight; closing 1440 = end of day.
    let weekday: Int
    let opens: Int
    let closes: Int
}

enum PlaceAvailability: Equatable {
    case open, openingSoon(minutes: Int), closed, unknown

    // Unknown hours stay visible, clearly labelled; never claim that they are open.
    var appearsInDiscovery: Bool { self != .closed }
    var title: String {
        switch self {
        case .open: return "Отворено сега"
        case .openingSoon(let minutes): return "Отваря след \(minutes) мин"
        case .closed: return "Затворено"
        case .unknown: return "Неизвестно работно време"
        }
    }
    var symbol: String {
        switch self {
        case .open: return "checkmark.circle.fill"
        case .openingSoon: return "clock.fill"
        case .closed: return "moon.fill"
        case .unknown: return "clock.badge.questionmark"
        }
    }
}

enum OpeningSchedule {
    static let soonWindow: TimeInterval = 60 * 60
    static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Europe/Sofia")!
        return value
    }
    static func isValid(_ hours: [OpeningInterval]) -> Bool {
        hours.count <= 28 && hours.allSatisfy {
            (1...7).contains($0.weekday) && (0...1439).contains($0.opens)
                && (0...1440).contains($0.closes) && $0.opens != $0.closes
        }
    }
    static func isOpen(_ hours: [OpeningInterval]?, at date: Date) -> Bool? {
        guard let hours, isValid(hours) else { return nil }
        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = parts.weekday, let hour = parts.hour, let minutePart = parts.minute else { return nil }
        let minute = hour * 60 + minutePart
        let previousDay = weekday == 1 ? 7 : weekday - 1
        return hours.contains { interval in
            if interval.opens < interval.closes {
                return interval.weekday == weekday && minute >= interval.opens && minute < interval.closes
            }
            return (interval.weekday == weekday && minute >= interval.opens)
                || (interval.weekday == previousDay && minute < interval.closes)
        }
    }
    static func availability(_ hours: [OpeningInterval]?, at date: Date = .now) -> PlaceAvailability {
        guard let open = isOpen(hours, at: date), let hours else { return .unknown }
        if open { return .open }
        let next = hours.compactMap { interval in
            calendar.nextDate(after: date, matching: DateComponents(hour: interval.opens / 60,
                minute: interval.opens % 60, second: 0, weekday: interval.weekday),
                matchingPolicy: .nextTime, repeatedTimePolicy: .first)
        }.min()
        if let next, next.timeIntervalSince(date) <= soonWindow {
            return .openingSoon(minutes: max(1, Int(ceil(next.timeIntervalSince(date) / 60))))
        }
        return .closed
    }
    static var allDay: [OpeningInterval] { (1...7).map { .init(weekday: $0, opens: 0, closes: 1440) } }
    static func isAllDay(_ hours: [OpeningInterval]) -> Bool {
        (1...7).allSatisfy { day in hours.contains { $0.weekday == day && $0.opens == 0 && $0.closes == 1440 } }
    }
}

struct Toilet: Identifiable, Codable {
    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let kind: String
    let price: Double?
    let currency: String
    let amenities: [Amenity]
    let hours: [OpeningInterval]?
    let accessNote: String
    let isDemo: Bool
    let verifiedAt: Date?

    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    var priceText: String {
        guard let price else { return "Неизвестна цена" }
        return price == 0 ? "Безплатно" : String(format: "%.2f %@", price, currency)
    }
    func isOpen(at date: Date = Date()) -> Bool? {
        OpeningSchedule.isOpen(hours, at: date)
    }
    func availability(at date: Date = .now) -> PlaceAvailability { OpeningSchedule.availability(hours, at: date) }
    func matchesDiscovery(query: String, at date: Date = .now) -> Bool {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return availability(at: date).appearsInDiscovery
            && (term.isEmpty || "\(name) \(address)".localizedCaseInsensitiveContains(term))
    }
    func distance(from location: CLLocation?) -> Double? {
        location.map { CLLocation(latitude: latitude, longitude: longitude).distance(from: $0) }
    }
    var hoursText: String {
        guard let hours else { return "Работното време не е известно" }
        let days = [(2, "Пон"), (3, "Вт"), (4, "Ср"), (5, "Чет"), (6, "Пет"), (7, "Съб"), (1, "Нед")]
        return days.map { day, label in
            let intervals = hours.filter { $0.weekday == day }.sorted { $0.opens < $1.opens }
            let value = intervals.isEmpty ? "Затворено" : intervals.map {
                "\(Self.clock($0.opens))–\(Self.clock($0.closes))" + ($0.closes < $0.opens ? " (+1 ден)" : "")
            }.joined(separator: ", ")
            return "\(label): \(value)"
        }.joined(separator: "\n")
    }
    private static func clock(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }
}

enum Criterion: String, Codable, CaseIterable, Identifiable {
    case cleanliness, maintenance, paper, soap, lighting, condition, accessibility
    static let ratingCases: [Criterion] = [.cleanliness, .maintenance, .lighting, .condition]
    var id: String { rawValue }
    var title: String {
        switch self {
        case .cleanliness: return "Чистота"
        case .maintenance: return "Поддръжка"
        case .paper: return "Тоалетна хартия"
        case .soap: return "Сапун"
        case .lighting: return "Осветление"
        case .condition: return "Санитарно състояние"
        case .accessibility: return "Достъпност"
        }
    }
}

enum ReviewFeature: String, Codable, CaseIterable, Identifiable {
    case soap, paper, water, wheelchair
    var id: String { rawValue }
    var title: String {
        switch self {
        case .soap: return "Сапун"
        case .paper: return "Хартия"
        case .water: return "Вода"
        case .wheelchair: return "Достъпност"
        }
    }
    var accessibilityTitle: String {
        switch self {
        case .soap: return "Наличие на сапун"
        case .paper: return "Наличие на тоалетна хартия"
        case .water: return "Наличие на течаща вода"
        case .wheelchair: return "Достъпност с инвалидна количка"
        }
    }
    var symbol: String {
        switch self {
        case .soap: return "bubbles.and.sparkles"
        case .paper: return "toilet"
        case .water: return "drop"
        case .wheelchair: return "figure.roll"
        }
    }
}

struct Review: Identifiable, Codable {
    var id = UUID()
    let toiletID: String
    var scores: [String: Int]
    var comment: String
    var photos: [Data]
    var updatedAt = Date()
    var authorID: String?
    // Missing keys mean not checked. Older reviews decode without observations.
    var observations: [String: Bool]?
    var average: Double? {
        let values = scores.values.filter { (1...5).contains($0) }
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }
}

enum ReportCategory: String, Codable, CaseIterable, Identifiable {
    case location, hours, price, closed, accessibility, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .location: return "Грешно местоположение"
        case .hours: return "Работно време"
        case .price: return "Цена"
        case .closed: return "Затворен обект"
        case .accessibility: return "Достъпност"
        case .other: return "Друго"
        }
    }
}

struct IssueReport: Identifiable, Codable {
    var id = UUID()
    let toiletID: String
    let category: ReportCategory
    let message: String
    var createdAt = Date()
}

struct LocalData: Codable {
    var reviews: [Review] = []
    var reports: [IssueReport] = []
    var favoriteIDs: Set<String> = []
}

struct SearchFilters {
    var openNow = false
    var free = false
    var accessible = false
    var changingTable = false
    func matches(_ toilet: Toilet, query: String, at date: Date = Date()) -> Bool {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return (term.isEmpty || "\(toilet.name) \(toilet.address)".localizedCaseInsensitiveContains(term)) &&
            (!openNow || toilet.isOpen(at: date) == true) &&
            (!free || toilet.price == 0) &&
            (!accessible || toilet.amenities.contains(.wheelchair)) &&
            (!changingTable || toilet.amenities.contains(.changingTable))
    }
}

extension Toilet {
    var validationError: String? {
        guard (2...100).contains(name.trimmingCharacters(in: .whitespacesAndNewlines).count),
              (3...250).contains(address.trimmingCharacters(in: .whitespacesAndNewlines).count),
              (1...60).contains(kind.count), accessNote.count <= 2000 else { return "Попълнете име (2–100), адрес (3–250), тип (1–60) и описание до 2000 символа." }
        guard latitude.isFinite, longitude.isFinite, (42.30...42.75).contains(latitude), (27.20...27.65).contains(longitude) else { return "Изберете точка в района на Бургас." }
        if let price, !price.isFinite || price < 0 || price > 1000 { return "Цената трябва да е между 0 и 1000." }
        guard currency.count == 3, currency.allSatisfy({ $0.isASCII && $0.isUppercase }) else { return "Валутата трябва да е три главни латински букви, например EUR." }
        if let hours {
            guard hours.count <= 28, hours.allSatisfy({ (1...7).contains($0.weekday) && (0...1439).contains($0.opens) && (0...1440).contains($0.closes) && $0.opens != $0.closes }) else { return "Проверете работните интервали. За 24 часа използвайте 00:00–24:00." }
        }
        return nil
    }
}

enum RouteSelection {
    static func nearest(in toilets: [Toilet], to location: CLLocation) -> Toilet? {
        toilets.min {
            let a = $0.distance(from: location) ?? .infinity
            let b = $1.distance(from: location) ?? .infinity
            return a == b ? $0.id < $1.id : a < b
        }
    }
}

// The sheet receives its data and presentation identity together, including on first tap.
struct NearestRouteRequest: Identifiable {
    let id = UUID()
    let destinations: [Toilet]
    init?(destinations: [Toilet]) {
        guard !destinations.isEmpty else { return nil }
        self.destinations = destinations
    }
}

extension RouteSelection {
    static func isRecentLocation(_ location: CLLocation, now: Date = Date()) -> Bool {
        CLLocationCoordinate2DIsValid(location.coordinate) && location.horizontalAccuracy >= 0 &&
        abs(location.timestamp.timeIntervalSince(now)) < 15
    }
}
