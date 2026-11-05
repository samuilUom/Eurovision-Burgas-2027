import Foundation

enum DemoData {
    static let toilets: [Toilet] = [
        make("demo-garden", "Морска градина", "Примерна точка • район Морска градина", 42.5006, 27.4822,
             price: 0, amenities: [.wheelchair, .water], hours: daily(8, 22)),
        make("demo-pier", "До Моста", "Примерна точка • крайбрежна алея", 42.4967, 27.4850,
             price: 0.50, amenities: [.water], hours: daily(9, 20)),
        make("demo-center", "В центъра", "Примерна точка • район пл. Тройката", 42.4979, 27.4706,
             price: 0, amenities: [.wheelchair, .changingTable, .water], hours: daily(0, 24)),
        make("demo-station", "До гарата", "Примерна точка • район жп гара Бургас", 42.4904, 27.4713,
             price: 0.50, amenities: [.water], hours: daily(6, 23)),
        make("demo-lazur", "В Лазур", "Примерна точка • район Лазур", 42.5128, 27.4756,
             price: nil, amenities: [.changingTable, .water], hours: nil),
        make("demo-park", "Парк Изгрев", "Примерна точка • район Изгрев", 42.5241, 27.4617,
             price: 0, amenities: [.wheelchair, .water], hours: daily(7, 21))
    ]
    static func daily(_ opens: Int, _ closes: Int) -> [OpeningInterval] {
        (1...7).map { OpeningInterval(weekday: $0, opens: opens * 60, closes: closes * 60) }
    }
    private static func make(_ id: String, _ name: String, _ address: String, _ lat: Double, _ lon: Double,
                             price: Double?, amenities: [Amenity], hours: [OpeningInterval]?) -> Toilet {
        Toilet(id: id, name: name, address: address, latitude: lat, longitude: lon, kind: "Демо обект",
               price: price, currency: "EUR", amenities: amenities, hours: hours,
               accessNote: "Изцяло примерни данни за демонстрация. Наличието на тоалетна, цената, работното време и удобствата на това място НЕ са проверени.",
               isDemo: true, verifiedAt: nil)
    }
}
