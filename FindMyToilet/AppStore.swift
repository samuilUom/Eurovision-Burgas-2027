import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var toilets: [Toilet] = []
    @Published private(set) var toiletOwners: [String: String] = [:]
    @Published private(set) var data = LocalData()
    @Published private(set) var profile: UserProfile?
    @Published private(set) var profiles: [UserProfile] = []
    @Published private(set) var configured = false
    @Published private(set) var busy = false
    @Published var errorMessage: String?
    @Published var authMessage: String?
    @Published private(set) var pendingConfirmationEmail: String?
    private var nextConfirmationRequest = Date.distantPast
    @Published private(set) var syncStatus: String?
    @Published private(set) var starting = true
    @Published private(set) var catalogueLoaded = false
    @Published private(set) var cityFavorites: [SavedCityPlace] = []
    @Published private(set) var cityFavoritesStatus: String?
    @Published private(set) var cityFavoritesBusy = false
    private var cityFavoriteState: CityFavoriteState?
    private var cityFavoriteTask: Task<Void, Never>?
    private var cityFavoriteGeneration = UUID()
    @Published private(set) var sharedPlaces: [CommunityPlace] = []
    @Published private(set) var sharedPlacesStatus: String?
    @Published private(set) var sharedPlacesLoading = false
    private var sharedPlacesTask: Task<Void, Never>?
    private var sharedPlacesGeneration = UUID()
    private var client: CloudClient?
    private var started = false

    // Constructing the app's root state must not touch disk, SQLite, Keychain or networking.
    init() {}
    var canSave: Bool { profile != nil && client != nil && !busy }
    var isAdmin: Bool { profile?.isAdmin == true }
    var email: String { client?.session?.user.email ?? "" }
    var userID: String? { client?.session?.user.id }
    func start() async {
        guard !started else { return }
        started = true
        starting = true
        defer { starting = false }
        do {
            let config = await Task.detached(priority: .userInitiated) { BackendConfiguration.load() }.value
            if let config {
                let connection = try CloudClient(configuration: config)
                client = connection
                configured = true
                busy = true
                defer { busy = false }
                // Fetch the public catalogue before restoring a potentially locked session.
                let places = try await connection.rows("toilets", query: [.init(name: "order", value: "id")], as: ToiletRow.self)
                toilets = places.map(\.payload)
                toiletOwners = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0.created_by) })
                catalogueLoaded = true
                do { try await connection.restoreSession() }
                catch { authMessage = "Запазеният вход не може да бъде възстановен. Влезте отново от „Профил“." }
                try await fetch(connection)
            } else {
                let local = try await Task.detached(priority: .userInitiated) {
                    let db = try Database(url: Database.defaultURL())
                    return (try db.toilets(), try db.load())
                }.value
                toilets = local.0
                data = local.1
                catalogueLoaded = true
            }
            syncStatus = nil
        } catch {
            started = false
            syncStatus = "Зареждането не успя. Натиснете „Опитай отново“."
            errorMessage = error.localizedDescription
        }
    }

    func connect(_ configuration: BackendConfiguration) async -> Bool {
        guard !busy else { return false }
        busy = true
        defer { busy = false }
        do {
            let candidate = try CloudClient(configuration: configuration)
            let _: [ToiletRow] = try await candidate.rest("toilets", query: [.init(name: "limit", value: "1")], as: [ToiletRow].self)
            try configuration.save()
            resetCityFavorites()
            sharedPlacesGeneration = UUID()
            sharedPlacesTask?.cancel(); sharedPlacesTask = nil
            sharedPlaces = []; sharedPlacesStatus = nil; sharedPlacesLoading = false
            client = candidate
            configured = true
            started = true
            catalogueLoaded = false
            profile = nil; profiles = []; toilets = []; toiletOwners = [:]; data = LocalData()
            try await candidate.restoreSession()
            try await fetch(candidate)
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }
    func authenticate(name: String, email: String, password: String, signup: Bool) async -> Bool {
        guard let client, !busy else { return false }
        busy = true; authMessage = nil; errorMessage = nil
        defer { busy = false }
        do {
            if signup {
                if try await !client.signup(name: name, email: email, password: password) {
                    pendingConfirmationEmail = email
                    nextConfirmationRequest = Date().addingTimeInterval(60)
                    authMessage = "Проверете пощата си и въведете кода от най-новия имейл. Ако вече имате потвърден профил, използвайте „Вход“."
                    return true
                }
            } else { try await client.login(email: email, password: password) }
            try await loadOwnProfile(client)
            pendingConfirmationEmail = nil
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }
    private func loadOwnProfile(_ client: CloudClient) async throws {
        guard let id = client.session?.user.id else { throw CloudError("Няма активна сесия. Влезте отново.") }
        let people = try await client.rows("profiles", query: [.init(name: "id", value: "eq.\(id)")], as: UserProfile.self)
        guard let account = people.first else { throw CloudError("Профилът липсва в базата. Свържете се с администратора.") }
        profile = account
        profiles.removeAll { $0.id == account.id }
        profiles.append(account)
        await activateCityFavorites(client)
    }
    func resendConfirmation(email: String) async {
        guard let client, !busy else { return }
        guard Date() >= nextConfirmationRequest else {
            authMessage = "Изчакайте една минута преди да поискате нов код."
            return
        }
        busy = true; errorMessage = nil
        defer { busy = false }
        do {
            try await client.resendConfirmation(email: email)
            pendingConfirmationEmail = email
            nextConfirmationRequest = Date().addingTimeInterval(60)
            authMessage = "Заявихме нов код. Проверете входящата поща и Спам. Използвайте само най-новия код."
        } catch { errorMessage = error.localizedDescription }
    }
    func confirmRegistration(code: String) async -> Bool {
        guard let client, let email = pendingConfirmationEmail, !busy else { return false }
        busy = true; errorMessage = nil
        defer { busy = false }
        do {
            try await client.confirmEmail(email: email, code: code.trimmingCharacters(in: .whitespacesAndNewlines))
            try await loadOwnProfile(client)
            pendingConfirmationEmail = nil; authMessage = nil
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }
    func cancelConfirmation() {
        guard !busy else { return }
        pendingConfirmationEmail = nil; authMessage = nil
    }
    func logout() async {
        guard let client, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            try await client.logout()
            resetCityFavorites()
            profile = nil; data.favoriteIDs = []; data.reports = []; authMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
    func refresh(quiet: Bool = false) async {
        if !started { await start(); return }
        guard let client, !busy else { return }
        busy = true
        defer { busy = false }
        do { try await fetch(client); syncStatus = nil }
        catch {
            syncStatus = "Данните не са обновени. Проверете връзката и натиснете обновяване."
            if !quiet { errorMessage = "Обновяването не успя: \(error.localizedDescription)" }
        }
    }
    private func fetch(_ client: CloudClient) async throws {
        let places = try await client.rows("toilets", query: [.init(name: "order", value: "id")], as: ToiletRow.self)
        // A failed ancillary request must not discard a successfully loaded map.
        toilets = places.map(\.payload)
                toiletOwners = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0.created_by) })
        catalogueLoaded = true
        beginSharedPlacesRefresh(client)
        let reviews = try await client.rows("reviews", query: [.init(name: "order", value: "id")], as: ReviewRow.self)
        let people = try await client.rows("profiles", query: [.init(name: "order", value: "id")], as: UserProfile.self)
        var favorites: [FavoriteRow] = []
        var reports: [ReportRow] = []
        if let id = client.session?.user.id {
            favorites = try await client.rows("favorites", query: [.init(name: "user_id", value: "eq.\(id)"), .init(name: "order", value: "toilet_id")], as: FavoriteRow.self)
            reports = try await client.rows("reports", query: [.init(name: "order", value: "id")], as: ReportRow.self)
        }
        profiles = people
        profile = people.first { $0.id == client.session?.user.id }
        data = LocalData(reviews: reviews.map { row in var review = row.payload; review.authorID = row.author_id; return review },
                         reports: reports.map(\.payload), favoriteIDs: Set(favorites.map(\.toilet_id)))
        await activateCityFavorites(client)
    }
    var transitScope: String { client?.configuration.url ?? "" }
    func loadTransitStops() async throws -> [BurgasBusStop] {
        guard let client else { throw CloudError("Няма връзка с базата.") }
        return try await client.rows("burgasbus_stops", query: [.init(name: "order", value: "id")], as: BurgasBusStop.self)
    }
    func loadTransitLive() async throws -> BurgasLiveSnapshot? {
        guard let client else { throw CloudError("Няма връзка с базата.") }
        let rows: [BurgasLiveRow] = try await client.rest("burgasbus_live", query: [.init(name: "id", value: "eq.1")], as: [BurgasLiveRow].self)
        return rows.first?.payload
    }
    var myCityPlaces: [CommunityPlace] {
        sharedPlaces.filter { $0.created_by.lowercased() == userID?.lowercased() }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    func refreshSharedPlaces() async {
        guard let client else { return }
        beginSharedPlacesRefresh(client)
        await sharedPlacesTask?.value
    }
    private func beginSharedPlacesRefresh(_ connection: CloudClient) {
        guard sharedPlacesTask == nil else { return }
        let generation = sharedPlacesGeneration
        sharedPlacesLoading = true
        sharedPlacesTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.sharedPlacesGeneration == generation {
                    self.sharedPlacesLoading = false; self.sharedPlacesTask = nil
                }
            }
            do {
                let rows = try await connection.rows("city_places", query: [.init(name: "order", value: "id")], as: CommunityPlace.self)
                guard self.client === connection, self.sharedPlacesGeneration == generation, !Task.isCancelled else { return }
                self.sharedPlaces = rows.filter { $0.validationMessage == nil }
                self.sharedPlacesStatus = nil
            } catch {
                guard self.client === connection, self.sharedPlacesGeneration == generation, !Task.isCancelled else { return }
                self.sharedPlacesStatus = "Местата от общността не се заредиха. Обнови или се свържи с администратора."
            }
        }
    }
    func saveCityPlace(_ place: CommunityPlace, editing: Bool) async -> String? {
        guard canSave, let client, let userID else { return "Влез от „Профил“, за да добавиш място." }
        guard !editing || isAdmin else { return "Само администратор може да редактира място." }
        guard editing || place.created_by.lowercased() == userID.lowercased() else { return "Авторът не съвпада с профила." }
        if let problem = place.validationMessage { return problem }
        busy = true
        defer { busy = false }
        // Finish an in-flight read before writing, so an old catalogue cannot overwrite this save.
        await sharedPlacesTask?.value
        do {
            var body = try JSONSerialization.jsonObject(with: JSONEncoder().encode(place)) as! [String: Any]
            // Codable omits nil; PATCH must explicitly clear optional values.
            body["website"] = place.website.map { $0 as Any } ?? NSNull()
            body["is_nonstop"] = place.is_nonstop.map { $0 as Any } ?? NSNull()
            // Old databases can still accept places without hours. Never silently drop a supplied schedule.
            if editing && place.hours == nil && sharedPlaces.first(where: { $0.id == place.id })?.hours != nil {
                body["hours"] = NSNull()
            }
            if editing { body.removeValue(forKey: "id"); body.removeValue(forKey: "created_by") }
            let saved: [CommunityPlace] = try await client.rest("city_places", method: editing ? "PATCH" : "POST",
                query: editing ? [.init(name: "id", value: "eq.\(place.id)")] : [],
                body: JSONSerialization.data(withJSONObject: body), prefer: "return=representation", as: [CommunityPlace].self)
            guard let receipt = saved.first, receipt.id.lowercased() == place.id.lowercased(), receipt.validationMessage == nil else {
                return "Сървърът не потвърди запазването. Обнови картата и опитай отново."
            }
            sharedPlaces.removeAll { $0.id == receipt.id }; sharedPlaces.append(receipt)
            sharedPlacesStatus = nil
            return nil
        } catch {
            return "Мястото не е запазено. Провери връзката и опитай отново. Ако проблемът остане, свържи се с администратора."
        }
    }
    func deleteCityPlace(_ place: CommunityPlace) async -> Bool {
        guard canSave, isAdmin, let client else { return false }
        busy = true
        defer { busy = false }
        await sharedPlacesTask?.value
        do {
            let removed: [CommunityPlace] = try await client.rest("city_places", method: "DELETE",
                query: [.init(name: "id", value: "eq.\(place.id)")], prefer: "return=representation", as: [CommunityPlace].self)
            guard removed.contains(where: { $0.id == place.id }) else { throw CloudError("Мястото не е изтрито.") }
            sharedPlaces.removeAll { $0.id == place.id }
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }
    func review(for id: String) -> Review? {
        guard let userID else { return nil }
        return data.reviews.first { $0.toiletID == id && $0.authorID == userID }
    }
    func reviews(for id: String) -> [Review] { data.reviews.filter { $0.toiletID == id }.sorted { $0.updatedAt > $1.updatedAt } }
    func rating(for id: String) -> Double? {
        let values = reviews(for: id).compactMap(\.average)
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
    func authorName(_ review: Review) -> String { profiles.first { $0.id == review.authorID }?.display_name ?? "Потребител" }
    func isFavorite(_ id: String) -> Bool { data.favoriteIDs.contains(id) }
    var favoriteToilets: [Toilet] { toilets.filter { isFavorite($0.id) }.sorted { $0.name.localizedCompare($1.name) == .orderedAscending } }
    var displayedCityFavorites: [SavedCityPlace] { SavedCityPlace.uniquePlaces(cityFavorites) }
    var totalFavoriteCount: Int { favoriteToilets.count + displayedCityFavorites.count }
    var canSaveCityFavorite: Bool { canSave && !cityFavoritesBusy && cityFavoriteState != nil }
    func isCityFavorite(_ place: CityPlace) -> Bool { cityFavorites.contains { $0.matches(place) } }
    func favoriteCount(in category: EventCategory) -> Int {
        category == .toilets ? favoriteToilets.count : displayedCityFavorites.filter { $0.category.section == category.section }.count
    }
    func toggleCityFavorite(_ place: CityPlace) async {
        guard let client, canSaveCityFavorite, var next = cityFavoriteState else { return }
        let saved = SavedCityPlace(place: place)
        guard saved.isValid else { errorMessage = "Мястото няма достатъчно данни, за да бъде запазено."; return }
        let matching = next.places.filter { $0.matches(place) }
        if matching.isEmpty { next.save(saved) }
        else { for match in matching { next.removeGroup(match.groupID) } }
        let generation = cityFavoriteGeneration
        cityFavoritesBusy = true
        do {
            let persisted = next
            try await Task.detached { try CityFavoriteCache.write(persisted) }.value
            guard generation == cityFavoriteGeneration else { return }
            publishCityFavorites(next)
            cityFavoritesBusy = false
            cityFavoritesStatus = "Запазено на този телефон. Изчаква синхронизация."
            beginCityFavoriteSync(client)
        } catch {
            guard generation == cityFavoriteGeneration else { return }
            cityFavoritesBusy = false
            errorMessage = "Промяната не е запазена. Проверете свободното място на телефона и опитайте отново."
        }
    }
    func refreshCityFavorites() async {
        guard let client, !busy, !cityFavoritesBusy else { return }
        await activateCityFavorites(client)
        await cityFavoriteTask?.value
    }
    private func resetCityFavorites() {
        cityFavoriteGeneration = UUID()
        cityFavoriteTask?.cancel(); cityFavoriteTask = nil
        cityFavoriteState = nil; cityFavorites = []; cityFavoritesStatus = nil; cityFavoritesBusy = false
    }
    private func publishCityFavorites(_ state: CityFavoriteState) {
        cityFavoriteState = state
        cityFavorites = state.places.sorted { $0.savedAt == $1.savedAt ? $0.id < $1.id : $0.savedAt > $1.savedAt }
    }
    private func activateCityFavorites(_ client: CloudClient) async {
        guard let userID = client.session?.user.id else { resetCityFavorites(); return }
        let scope = CityFavoriteScope(server: client.configuration.url, userID: userID)
        if cityFavoriteState?.scope == scope { beginCityFavoriteSync(client); return }
        resetCityFavorites()
        let generation = cityFavoriteGeneration
        cityFavoritesBusy = true
        do {
            let cached = try await Task.detached { try CityFavoriteCache.read(scope) }.value
            guard generation == cityFavoriteGeneration else { return }
            publishCityFavorites(cached)
            cityFavoritesBusy = false
            beginCityFavoriteSync(client)
        } catch {
            guard generation == cityFavoriteGeneration else { return }
            cityFavoritesBusy = false
            cityFavoritesStatus = "Запазените места не могат да бъдат прочетени. Опитайте отново."
        }
    }
    private func beginCityFavoriteSync(_ client: CloudClient) {
        guard !cityFavoritesBusy, cityFavoriteTask == nil, let state = cityFavoriteState,
              client.session?.user.id.lowercased() == state.scope.userID else { return }
        let generation = cityFavoriteGeneration
        cityFavoritesBusy = true
        cityFavoriteTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.cityFavoriteGeneration == generation {
                    self.cityFavoritesBusy = false; self.cityFavoriteTask = nil
                }
            }
            do {
                let rows = try await client.rows("city_place_favorites", query: [
                    .init(name: "user_id", value: "eq.\(state.scope.userID)"), .init(name: "order", value: "place_id")
                ], as: CityFavoriteRow.self)
                guard self.cityFavoriteGeneration == generation, !Task.isCancelled else { return }
                guard rows.allSatisfy({ $0.user_id.lowercased() == state.scope.userID && $0.place_id == $0.payload.id
                    && $0.category == $0.payload.category.rawValue && $0.payload.isValid }) else {
                    throw CloudError("Невалидни запазени места от сървъра.")
                }
                var remote = rows.map(\.payload)
                for change in state.pending {
                    try Task.checkCancellation()
                    if let place = change.place {
                        let row = CityFavoriteRow(user_id: state.scope.userID, place_id: place.id, category: place.category.rawValue, payload: place)
                        let saved: [CityFavoriteRow] = try await client.rest("city_place_favorites", method: "POST",
                            query: [.init(name: "on_conflict", value: "user_id,place_id")], body: JSONEncoder().encode(row),
                            prefer: "resolution=merge-duplicates,return=representation", as: [CityFavoriteRow].self)
                        guard saved.contains(where: { $0.user_id.lowercased() == state.scope.userID && $0.place_id == place.id }) else {
                            throw CloudError("Мястото не е синхронизирано.")
                        }
                    } else {
                        let _: [CityFavoriteRow] = try await client.rest("city_place_favorites", method: "DELETE", query: [
                            .init(name: "user_id", value: "eq.\(state.scope.userID)"), .init(name: "place_id", value: "eq.\(change.id)")
                        ], prefer: "return=representation", as: [CityFavoriteRow].self)
                    }
                    guard self.cityFavoriteGeneration == generation, !Task.isCancelled, var acknowledged = self.cityFavoriteState else { return }
                    acknowledged.pending.removeAll { $0.id == change.id }
                    let persisted = acknowledged
                    try await Task.detached { try CityFavoriteCache.write(persisted) }.value
                    guard self.cityFavoriteGeneration == generation, !Task.isCancelled else { return }
                    self.publishCityFavorites(acknowledged)
                    remote.removeAll { $0.id == change.id }
                    if let place = change.place { remote.append(place) }
                }
                guard var final = self.cityFavoriteState else { return }
                final.acceptRemote(remote)
                let persisted = final
                try await Task.detached { try CityFavoriteCache.write(persisted) }.value
                guard self.cityFavoriteGeneration == generation, !Task.isCancelled else { return }
                self.publishCityFavorites(final)
                self.cityFavoritesStatus = nil
            } catch {
                guard self.cityFavoriteGeneration == generation, !Task.isCancelled else { return }
                self.cityFavoritesStatus = error.localizedDescription.contains("city_place_favorites")
                    ? "Новите любими се пазят на този телефон. Споделянето им между телефони още не е активирано."
                    : "Показваме запазеното на този телефон. Обновете при възстановена връзка, за да синхронизирате."
            }
        }
    }
    func toggleFavorite(_ id: String) async {
        guard let client, let userID, canSave else { return }
        busy = true
        defer { busy = false }
        do {
            if isFavorite(id) {
                let _: [FavoriteRow] = try await client.rest("favorites", method: "DELETE", query: [.init(name: "user_id", value: "eq.\(userID)"), .init(name: "toilet_id", value: "eq.\(id)")], prefer: "return=representation", as: [FavoriteRow].self)
                data.favoriteIDs.remove(id)
            } else {
                let _: [FavoriteRow] = try await client.rest("favorites", method: "POST", body: JSONEncoder().encode(FavoriteRow(user_id: userID, toilet_id: id)), prefer: "resolution=ignore-duplicates,return=representation", as: [FavoriteRow].self)
                data.favoriteIDs.insert(id)
            }
        } catch { errorMessage = error.localizedDescription }
    }
    func saveReview(_ value: Review) async -> Bool {
        guard let client, let userID, canSave else { return false }
        guard value.average != nil, value.comment.count <= 1000, value.photos.count <= 3,
              value.scores.values.allSatisfy({ (1...5).contains($0) }),
              (value.observations ?? [:]).keys.allSatisfy({ ReviewFeature(rawValue: $0) != nil }), value.scores.keys.allSatisfy({ Criterion(rawValue: $0) != nil }) else {
            errorMessage = "Добавете поне една оценка от 1 до 5. Коментарът е до 1000 символа, снимките — до 3."
            return false
        }
        busy = true
        defer { busy = false }
        do {
            var review = value; review.authorID = userID
            let row = ReviewRow(id: review.id, toilet_id: review.toiletID, author_id: userID, payload: review)
            let saved: [ReviewRow] = try await client.rest("reviews", method: "POST", query: [.init(name: "on_conflict", value: "toilet_id,author_id")], body: JSONEncoder().encode(row), prefer: "resolution=merge-duplicates,return=representation", as: [ReviewRow].self)
            guard let row = saved.first else { throw CloudError("Ревюто не е запазено.") }
            data.reviews.removeAll { $0.toiletID == review.toiletID && $0.authorID == userID }
            var published = row.payload
            published.authorID = row.author_id
            data.reviews.append(published)
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }
    func deleteReview(_ id: String) async {
        guard let client, let review = review(for: id), let userID, canSave else { return }
        busy = true
        defer { busy = false }
        do {
            let removed: [ReviewRow] = try await client.rest("reviews", method: "DELETE", query: [.init(name: "id", value: "eq.\(review.id.uuidString)"), .init(name: "author_id", value: "eq.\(userID)")], prefer: "return=representation", as: [ReviewRow].self)
            guard !removed.isEmpty else { throw CloudError("Ревюто не е изтрито. Обновете и опитайте отново.") }
            data.reviews.removeAll { $0.id == review.id }
        } catch { errorMessage = error.localizedDescription }
    }
    func saveReport(_ report: IssueReport) async -> Bool {
        guard let client, let userID, canSave, (10...1000).contains(report.message.count) else { return false }
        busy = true
        defer { busy = false }
        do {
            let row = ReportRow(id: report.id, toilet_id: report.toiletID, author_id: userID, payload: report)
            let saved: [ReportRow] = try await client.rest("reports", method: "POST", body: JSONEncoder().encode(row), prefer: "return=representation", as: [ReportRow].self)
            guard !saved.isEmpty else { throw CloudError("Сигналът не е изпратен.") }
            data.reports.append(report)
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }
    func saveToilet(_ toilet: Toilet, editing: Bool) async -> Bool {
        guard let client, let userID, canSave else { return false }
        guard !editing || isAdmin else { errorMessage = "Само администратор може да редактира обекти."; return false }
        guard toilet.validationError == nil else { errorMessage = toilet.validationError; return false }
        busy = true
        defer { busy = false }
        do {
            let saved: [ToiletRow]
            if editing {
                struct Patch: Encodable { let payload: Toilet }
                saved = try await client.rest("toilets", method: "PATCH", query: [.init(name: "id", value: "eq.\(toilet.id)")], body: JSONEncoder().encode(Patch(payload: toilet)), prefer: "return=representation", as: [ToiletRow].self)
            } else {
                saved = try await client.rest("toilets", method: "POST", body: JSONEncoder().encode(ToiletRow(id: toilet.id, created_by: userID, payload: toilet)), prefer: "return=representation", as: [ToiletRow].self)
            }
            guard let value = saved.first?.payload else { throw CloudError("Записът не е променен. Проверете правата си и обновете списъка.") }
            toilets.removeAll { $0.id == value.id }; toilets.append(value)
            if let owner = saved.first?.created_by { toiletOwners[value.id] = owner }
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }
    func deleteToilet(_ id: String) async -> Bool {
        guard let client, canSave, isAdmin else { return false }
        busy = true
        defer { busy = false }
        do {
            let removed: [ToiletRow] = try await client.rest("toilets", method: "DELETE", query: [.init(name: "id", value: "eq.\(id)")], prefer: "return=representation", as: [ToiletRow].self)
            guard !removed.isEmpty else { throw CloudError("Обектът не е изтрит. Обновете и опитайте отново.") }
            toilets.removeAll { $0.id == id }; toiletOwners.removeValue(forKey: id); data.reviews.removeAll { $0.toiletID == id }
            data.reports.removeAll { $0.toiletID == id }; data.favoriteIDs.remove(id)
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }
    var myToilets: [Toilet] {
        guard let userID else { return [] }
        return toilets.filter { toiletOwners[$0.id] == userID }.sorted { $0.name < $1.name }
    }
    var myReviews: [Review] {
        guard let userID else { return [] }
        return data.reviews.filter { $0.authorID == userID }.sorted { $0.updatedAt > $1.updatedAt }
    }
    func saveAvatar(_ data: Data?) async -> Bool {
        guard let client, let userID, canSave else { return false }
        guard (data?.count ?? 0) <= 90000 else {
            errorMessage = "Снимката е твърде голяма. Изберете друга."; return false
        }
        busy = true; errorMessage = nil
        defer { busy = false }
        do {
            let body = try JSONSerialization.data(withJSONObject: ["avatar_base64": data.map { $0.base64EncodedString() as Any } ?? NSNull()])
            let rows: [UserProfile] = try await client.rest("profiles", method: "PATCH",
                query: [.init(name: "id", value: "eq.\(userID)")], body: body,
                prefer: "return=representation", as: [UserProfile].self)
            guard let saved = rows.first else { throw CloudError("Снимката не е запазена.") }
            profile = saved; profiles.removeAll { $0.id == saved.id }; profiles.append(saved)
            return true
        } catch {
            let detail = error.localizedDescription
            errorMessage = detail.contains("avatar_base64")
                ? "Профилните снимки още не са активирани на сървъра. Свържете се с администратора."
                : "Снимката не е запазена. \(detail)"
            return false
        }
    }
    func renameProfile(_ name: String) async {
        guard let client, let userID, canSave else { return }
        busy = true
        defer { busy = false }
        do {
            let rows: [UserProfile] = try await client.rest("profiles", method: "PATCH", query: [.init(name: "id", value: "eq.\(userID)")], body: JSONEncoder().encode(["display_name": name]), prefer: "return=representation", as: [UserProfile].self)
            guard let saved = rows.first else { throw CloudError("Името не е променено.") }
            profile = saved; profiles.removeAll { $0.id == saved.id }; profiles.append(saved)
        } catch { errorMessage = error.localizedDescription }
    }
}

// Restaurant contributions use separate shared records; toilet reviews stay intact.
extension AppStore {
    var restaurantScope: String {
        "\(client.map { String(describing: ObjectIdentifier($0)) } ?? "offline")|\(userID ?? "guest")"
    }
    func sharedRestaurantID(for place: CityPlace) -> String? {
        guard place.category == .restaurants else { return nil }
        if place.source == .community, let id = place.sourceID, UUID(uuidString: id) != nil { return id }
        func normalized(_ name: String) -> String { name.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ") }
        return sharedPlaces.first {
            $0.category == .restaurants && normalized($0.name) == normalized(place.name)
                && abs($0.latitude - place.coordinate.latitude) < 0.0005
                && abs($0.longitude - place.coordinate.longitude) < 0.0007
        }?.id
    }
    private func restaurantRequest<T: Decodable>(_ endpoint: String, method: String = "GET",
        query: [URLQueryItem] = [], body: Data? = nil, write: Bool = false,
        scope: String, as type: T.Type) async throws -> T {
        guard scope == restaurantScope, let connection = client else { throw CancellationError() }
        if write && profile == nil { throw CloudError("Влез от „Профил“, за да споделиш.") }
        let result = try await connection.rest(endpoint, method: method, query: query, body: body,
                                               prefer: write ? "return=representation" : nil, as: type)
        try Task.checkCancellation()
        guard scope == restaurantScope, connection === client else { throw CancellationError() }
        return result
    }
    func loadRestaurant(_ id: String, reviewOffset: Int, photoOffset: Int, scope: String) async throws -> RestaurantSnapshot {
        struct Request: Encodable { let p_place_id: String; let p_review_offset: Int; let p_photo_offset: Int }
        return try await restaurantRequest("rpc/restaurant_community", method: "POST",
            body: JSONEncoder().encode(Request(p_place_id: id, p_review_offset: reviewOffset, p_photo_offset: photoOffset)),
            scope: scope, as: RestaurantSnapshot.self)
    }
    func activateRestaurant(_ place: CityPlace, scope: String) async throws -> String {
        if let id = sharedRestaurantID(for: place) { return id }
        struct Request: Encodable {
            let p_name: String; let p_address: String; let p_latitude: Double; let p_longitude: Double; let p_website: String?
        }
        await sharedPlacesTask?.value
        let result: [CommunityPlace] = try await restaurantRequest("rpc/register_restaurant", method: "POST",
            body: JSONEncoder().encode(Request(p_name: String(place.name.prefix(200)), p_address: String(place.address.prefix(500)),
                p_latitude: place.coordinate.latitude, p_longitude: place.coordinate.longitude,
                p_website: SavedCityPlace.safeWebsite(place.item.url?.absoluteString))), write: true, scope: scope, as: [CommunityPlace].self)
        guard let record = result.first, record.category == .restaurants, record.validationMessage == nil else {
            throw CloudError("Мястото не е потвърдено. Обнови и опитай пак.")
        }
        sharedPlaces.removeAll { $0.id == record.id }; sharedPlaces.append(record)
        return record.id
    }
    func saveRestaurantReview(placeID: String, rating: Int, comment: String, scope: String) async throws {
        let text = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard RestaurantContribution.validReview(rating: rating, comment: text) else {
            throw CloudError("Избери от 1 до 5 звезди и напиши до 2000 знака.")
        }
        struct Request: Encodable { let p_place_id: String; let p_rating: Int; let p_comment: String }
        let rows: [RestaurantReview] = try await restaurantRequest("rpc/save_restaurant_review", method: "POST",
            body: JSONEncoder().encode(Request(p_place_id: placeID, p_rating: rating, p_comment: text)), write: true, scope: scope,
            as: [RestaurantReview].self)
        guard rows.first?.place_id.lowercased() == placeID.lowercased(),
              rows.first?.author_id.lowercased() == userID?.lowercased() else { throw CloudError("Ревюто не е потвърдено.") }
    }
    func uploadRestaurantPhoto(id: UUID, placeID: String, image: RestaurantImage, caption: String, scope: String) async throws {
        guard image.full.count <= RestaurantContribution.maxPhotoBytes,
              image.thumbnail.count <= RestaurantContribution.maxThumbnailBytes, caption.unicodeScalars.count <= 300 else {
            throw CloudError("Снимката е твърде голяма или описанието е над 300 знака.")
        }
        struct Request: Encodable {
            let p_id: UUID; let p_place_id: String; let p_caption: String; let p_image: String; let p_thumbnail: String
        }
        struct Receipt: Decodable { let id: UUID }
        let rows: [Receipt] = try await restaurantRequest("rpc/add_restaurant_photo", method: "POST",
            body: JSONEncoder().encode(Request(p_id: id, p_place_id: placeID,
                p_caption: caption.trimmingCharacters(in: .whitespacesAndNewlines),
                p_image: image.full.base64EncodedString(), p_thumbnail: image.thumbnail.base64EncodedString())),
            write: true, scope: scope, as: [Receipt].self)
        guard rows.first?.id == id else { throw CloudError("Снимката не е потвърдена. Опитай пак.") }
    }
    func loadRestaurantPhoto(_ id: UUID, scope: String) async throws -> Data {
        struct ImageRow: Decodable { let image_base64: String }
        let rows: [ImageRow] = try await restaurantRequest("restaurant_photos", query: [
            .init(name: "id", value: "eq.\(id.uuidString)"), .init(name: "select", value: "image_base64"), .init(name: "limit", value: "1")
        ], scope: scope, as: [ImageRow].self)
        guard let encoded = rows.first?.image_base64, let image = Data(base64Encoded: encoded) else {
            throw CloudError("Снимката вече не е налична.")
        }
        return image
    }
    func deleteRestaurantContribution(id: UUID, photo: Bool, scope: String) async throws {
        struct Receipt: Decodable { let id: UUID }
        let rows: [Receipt] = try await restaurantRequest(photo ? "restaurant_photos" : "restaurant_reviews", method: "DELETE",
            query: [.init(name: "id", value: "eq.\(id.uuidString)"), .init(name: "select", value: "id")],
            write: true, scope: scope, as: [Receipt].self)
        guard rows.contains(where: { $0.id == id }) else { throw CloudError("Не е изтрито. Провери правата си и обнови.") }
    }
}
