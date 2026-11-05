import Foundation
import MapKit
import Combine

struct BurgasBusStop: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let stop_code: String?
    let latitude: Double
    let longitude: Double
    var isValid: Bool {
        !id.isEmpty && !name.isEmpty && CLLocationCoordinate2DIsValid(.init(latitude: latitude, longitude: longitude))
    }
    var place: CityPlace {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: .init(latitude: latitude, longitude: longitude)))
        item.name = name
        return CityPlace(item: item, category: .transport, savedAddress: stop_code.map { "Спирка \($0)" } ?? "",
                         source: .burgasbus, sourceID: id)
    }
}

struct BurgasLiveBus: Codable, Identifiable, Equatable {
    let id: String
    let route: String
    let label: String
    let latitude: Double
    let longitude: Double
    let bearing: Double?
    /// UNIX seconds of the actual GPS observation, never the download/import time.
    let observed_at: Double
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    func isFresh(at now: Date) -> Bool {
        let age = now.timeIntervalSince1970 - observed_at
        return !id.isEmpty && observed_at.isFinite && age >= -30 && age <= 120
            && CLLocationCoordinate2DIsValid(coordinate)
    }
    var title: String { route.isEmpty ? "Автобус" : "Линия \(route)" }
}

struct BurgasLiveSnapshot: Codable {
    let vehicles: [BurgasLiveBus]
    let fetched_at: Double
    func freshVehicles(at now: Date) -> [BurgasLiveBus] {
        var seen = Set<String>()
        return vehicles.filter { $0.isFresh(at: now) && seen.insert($0.id).inserted }
    }
}
struct BurgasLiveRow: Codable { let id: Int; let payload: BurgasLiveSnapshot }

@MainActor
final class BurgasTransitStore: ObservableObject {
    @Published private(set) var stops: [BurgasBusStop] = []
    @Published private(set) var vehicles: [BurgasLiveBus] = []
    @Published private(set) var status = "Официалните данни на Бургасбус още не са свързани."
    @Published private(set) var checkedAt = Date()
    @Published private(set) var loading = false
    private var generation = UUID()
    private var scope: String?

    func run(scope newScope: String, stops loadStops: () async throws -> [BurgasBusStop],
             live loadLive: () async throws -> BurgasLiveSnapshot?, interval: Duration = .seconds(20)) async {
        let current = UUID()
        generation = current
        if scope != newScope { stops = []; vehicles = []; scope = newScope }
        vehicles = []
        guard !newScope.isEmpty, !Task.isCancelled else { loading = false; return }
        loading = true
        let expiry = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                guard let self, self.generation == current else { return }
                let fresh = self.vehicles.filter { $0.isFresh(at: .now) }
                if fresh != self.vehicles {
                    self.vehicles = fresh
                    self.status = fresh.isEmpty ? "Няма пресни GPS позиции. Официалните спирки са достъпни."
                        : "\(fresh.count) автобуса · GPS до 2 минути · обновяване през 20 сек."
                }
            }
        }
        defer {
            expiry.cancel()
            if generation == current { loading = false; vehicles = [] }
        }
        do {
            let fetched = try await loadStops()
            guard generation == current, !Task.isCancelled else { return }
            var seen = Set<String>()
            stops = fetched.filter { $0.isValid && seen.insert($0.id).inserted }
        } catch {
            guard generation == current, !Task.isCancelled else { return }
            loading = false
            status = "Официалните данни не са достъпни. Използвай портала на Бургасбус."
            return
        }
        while !Task.isCancelled && generation == current {
            do {
                let snapshot = try await loadLive()
                guard generation == current, !Task.isCancelled else { return }
                checkedAt = .now
                vehicles = snapshot?.freshVehicles(at: checkedAt) ?? []
                if !vehicles.isEmpty { status = "\(vehicles.count) автобуса · GPS до 2 минути · обновяване през 20 сек." }
                else if stops.isEmpty { status = "Очаква свързване с официалните данни на Бургасбус." }
                else { status = "Няма пресни GPS позиции. Официалните спирки са достъпни." }
            } catch {
                guard generation == current, !Task.isCancelled else { return }
                vehicles = []
                checkedAt = .now
                status = "Живите позиции не се заредиха. Ще опитаме отново."
            }
            loading = false
            do { try await Task.sleep(for: interval) } catch { return }
        }
    }
}
