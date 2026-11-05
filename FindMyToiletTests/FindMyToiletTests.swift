import XCTest
import MapKit
import Combine
import CoreLocation
import ImageIO
import UniformTypeIdentifiers
@testable import FindMyToilet

final class FindMyToiletTests: XCTestCase {
    func testProfilesWithoutPhotosStillDecode() throws {
        let data = Data(#"{"id":"user","display_name":"Samuil","role":"user"}"#.utf8)
        let profile = try JSONDecoder().decode(UserProfile.self, from: data)
        XCTAssertNil(profile.avatarData)
        XCTAssertFalse(profile.isAdmin)
    }
    func testProfilePhotoRoundTripAndRemoval() throws {
        let bytes = Data([1, 2, 3])
        var profile = UserProfile(id: "user", display_name: "Samuil", role: "user", avatar_base64: bytes.base64EncodedString())
        let decoded = try JSONDecoder().decode(UserProfile.self, from: JSONEncoder().encode(profile))
        XCTAssertEqual(decoded.avatarData, bytes)
        profile.avatar_base64 = nil
        XCTAssertNil(profile.avatarData)
        profile.avatar_base64 = "invalid!"
        XCTAssertNil(profile.avatarData)
    }
    func testAvatarImageRejectsNonImageData() {
        XCTAssertNil(AvatarImage.prepare(Data("not an image".utf8)))
    }
    func testAvatarImageDownsamplesAndRemovesGPSMetadata() throws {
        let context = try XCTUnwrap(CGContext(data: nil, width: 640, height: 480, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.2, green: 0.7, blue: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 640, height: 480))
        let image = try XCTUnwrap(context.makeImage())
        let raw = NSMutableData()
        let dest = try XCTUnwrap(CGImageDestinationCreateWithData(raw, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(dest, image, [kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 42.5, kCGImagePropertyGPSLatitudeRef: "N"]] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        let thumbnail = try XCTUnwrap(AvatarImage.prepare(raw as Data))
        XCTAssertLessThanOrEqual(thumbnail.count, 90000)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(thumbnail as CFData, nil))
        let result = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(result.width, result.height)
        XCTAssertLessThanOrEqual(result.width, 320)
        let props = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        XCTAssertNil(props[kCGImagePropertyGPSDictionary])
    }
    func testReviewObservationsRoundTripPreservesNoVersusUnknown() throws {
        var review = Review(toiletID: "test", scores: ["cleanliness": 4, "lighting": 2], comment: "", photos: [])
        review.observations = ["soap": false, "paper": true]
        let decoded = try JSONDecoder().decode(Review.self, from: JSONEncoder().encode(review))
        XCTAssertEqual(decoded.observations?["soap"], false)
        XCTAssertEqual(decoded.observations?["paper"], true)
        XCTAssertNil(decoded.observations?["water"])
        XCTAssertEqual(decoded.average, 3)
    }
    func testLegacyReviewDoesNotInventFeatureAnswers() throws {
        let old = Review(toiletID: "test", scores: ["soap": 1, "paper": 5], comment: "", photos: [])
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
        json.removeValue(forKey: "observations")
        let decoded = try JSONDecoder().decode(Review.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.observations)
        XCTAssertEqual(decoded.average, 3)
        XCTAssertFalse(Criterion.ratingCases.contains(.soap))
        XCTAssertFalse(Criterion.ratingCases.contains(.paper))
    }
    func testConfirmationCodeRejectsMalformedInputAndPreservesLeadingZero() {
        XCTAssertTrue(ConfirmationCode.isValid("012345"))
        XCTAssertTrue(ConfirmationCode.isValid("01234567"))
        for invalid in ["", "12345", "12345678901", "12a456", "１２３４５６", "123 456"] {
            XCTAssertFalse(ConfirmationCode.isValid(invalid), invalid)
        }
    }
    func testExpiredConfirmationOffersResend() {
        let error = CloudError.serverResponse(status: 403, data: Data(#"{"error_code":"otp_expired"}"#.utf8))
        XCTAssertTrue(error.message.contains("Поискайте нов"))
        XCTAssertFalse(error.message.contains("Нямате права"))
    }
    func testLoginErrorsDistinguishCredentialsAndConfirmation() {
        let invalid = CloudError.serverResponse(status: 400, data: Data(#"{"error_code":"invalid_credentials","msg":"Invalid login credentials"}"#.utf8))
        let confirmation = CloudError.serverResponse(status: 400, data: Data(#"{"error_code":"email_not_confirmed"}"#.utf8))
        XCTAssertTrue(invalid.message.contains("Невалиден имейл или парола"))
        XCTAssertTrue(confirmation.message.contains("Потвърдете имейла"))
        XCTAssertNotEqual(invalid.message, confirmation.message)
    }
    func testServerErrorsPreserveDetailsAndHandleNonJSON() {
        XCTAssertEqual(CloudError.serverResponse(status: 400, data: Data(#"{"message":"Database unavailable"}"#.utf8)).message, "Database unavailable")
        XCTAssertTrue(CloudError.serverResponse(status: 502, data: Data("Bad gateway".utf8)).message.contains("502"))
        XCTAssertTrue(CloudError.serverResponse(status: 403, data: Data()).message.contains("Нямате права"))
    }
    func testNearestUsesCoordinatesAndHandlesEmptyResults() {
        let origin = CLLocation(latitude: 42.4979, longitude: 27.4706)
        XCTAssertEqual(RouteSelection.nearest(in: DemoData.toilets, to: origin)?.id, "demo-center")
        XCTAssertNil(RouteSelection.nearest(in: [], to: origin))
    }
    func testToiletValidationRejectsInvalidLocationAndPrice() {
        let invalid = Toilet(id: "bad", name: "Test", address: "Test address", latitude: 0, longitude: 0,
                             kind: "Public", price: -2, currency: "EUR", amenities: [], hours: nil,
                             accessNote: "", isDemo: false, verifiedAt: nil)
        XCTAssertNotNil(invalid.validationError)
        XCTAssertNil(DemoData.toilets[0].validationError)
    }
    func testPublicConfigurationRejectsSecretsAndInsecureURLs() {
        XCTAssertNoThrow(try BackendConfiguration(url: "https://example.supabase.co", publicKey: "sb_publishable_test").validate())
        XCTAssertThrowsError(try BackendConfiguration(url: "https://example.supabase.co", publicKey: "sb_secret_test").validate())
        XCTAssertThrowsError(try BackendConfiguration(url: "http://example.supabase.co", publicKey: "sb_publishable_test").validate())
        XCTAssertThrowsError(try BackendConfiguration(url: "https://example.supabase.co/rest/v1", publicKey: "sb_publishable_test").validate())
    }
    func testLegacyReviewsWithoutAuthorStillDecode() throws {
        let original = Review(toiletID: "test", scores: ["soap": 4], comment: "Old review", photos: [])
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Review.self, from: encoded)
        XCTAssertNil(decoded.authorID)
        XCTAssertEqual(decoded.average, 4)
    }
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    private func toilet(hours: [OpeningInterval]?, price: Double? = 0) -> Toilet {
        Toilet(id: "test", name: "Тест Бургас", address: "Център", latitude: 42.5, longitude: 27.47,
               kind: "Test", price: price, currency: "EUR", amenities: [.wheelchair], hours: hours,
               accessNote: "Test", isDemo: true, verifiedAt: nil)
    }
    func testHoursUseSofiaTimeAndExclusiveClosingBoundary() {
        let place = toilet(hours: [.init(weekday: 2, opens: 8 * 60, closes: 22 * 60)])
        // Monday in September: UTC+3 in Burgas.
        XCTAssertEqual(place.isOpen(at: date("2026-09-21T04:59:00Z")), false)
        XCTAssertEqual(place.isOpen(at: date("2026-09-21T05:00:00Z")), true)
        XCTAssertEqual(place.isOpen(at: date("2026-09-21T18:59:00Z")), true)
        XCTAssertEqual(place.isOpen(at: date("2026-09-21T19:00:00Z")), false)
    }
    func testOvernightSundayToMonday() {
        let place = toilet(hours: [.init(weekday: 1, opens: 22 * 60, closes: 2 * 60)])
        XCTAssertEqual(place.isOpen(at: date("2026-09-20T19:00:00Z")), true)
        XCTAssertEqual(place.isOpen(at: date("2026-09-20T22:30:00Z")), true)
        XCTAssertEqual(place.isOpen(at: date("2026-09-20T23:00:00Z")), false)
    }
    func testWinterTimeAndSplitIntervals() {
        let place = toilet(hours: [.init(weekday: 2, opens: 8 * 60, closes: 12 * 60),
                                   .init(weekday: 2, opens: 14 * 60, closes: 18 * 60)])
        XCTAssertEqual(place.isOpen(at: date("2026-01-05T06:00:00Z")), true)
        XCTAssertEqual(place.isOpen(at: date("2026-01-05T11:00:00Z")), false)
        XCTAssertEqual(place.isOpen(at: date("2026-01-05T12:00:00Z")), true)
    }
    func testUnknownScheduleIsNotOpen() {
        let place = toilet(hours: nil)
        XCTAssertNil(place.isOpen())
        var filters = SearchFilters()
        filters.openNow = true
        XCTAssertFalse(filters.matches(place, query: ""))
    }
    func testFullDayAndClosedSchedule() {
        XCTAssertEqual(toilet(hours: DemoData.daily(0, 24)).isOpen(at: date("2026-09-21T20:59:00Z")), true)
        XCTAssertEqual(toilet(hours: []).isOpen(), false)
    }
    func testFiltersCombineAndUnknownPriceIsNotFree() {
        var filters = SearchFilters()
        filters.free = true
        filters.accessible = true
        XCTAssertTrue(filters.matches(toilet(hours: nil), query: "  БУРГАС  "))
        XCTAssertFalse(filters.matches(toilet(hours: nil, price: nil), query: ""))
        XCTAssertFalse(filters.matches(toilet(hours: nil), query: "Несъществуващ"))
        filters.changingTable = true
        XCTAssertFalse(filters.matches(toilet(hours: nil), query: ""))
    }
    func testAverageOmitsUnratedCriteria() {
        let review = Review(toiletID: "test", scores: ["cleanliness": 5, "soap": 1], comment: "", photos: [])
        XCTAssertEqual(review.average, 3)
        XCTAssertNil(Review(toiletID: "test", scores: [:], comment: "", photos: []).average)
    }
    func testDatabasePersistsAcrossConnectionsAndClearsPersonalData() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let placeID = DemoData.toilets[0].id
        let review = Review(toiletID: placeID, scores: ["cleanliness": 4], comment: "Запазен текст", photos: [Data([1, 2, 3])])
        let report = IssueReport(toiletID: placeID, category: .hours, message: "Променено работно време")
        do {
            let db = try Database(url: url)
            try db.save(LocalData(reviews: [review], reports: [report], favoriteIDs: [placeID]))
        }
        let reopened = try Database(url: url)
        let loaded = try reopened.load()
        XCTAssertEqual(loaded.reviews.first?.comment, "Запазен текст")
        XCTAssertEqual(loaded.reviews.first?.photos.first, Data([1, 2, 3]))
        XCTAssertEqual(loaded.reports.first?.id, report.id)
        XCTAssertEqual(loaded.favoriteIDs, [placeID])
        XCTAssertEqual(try reopened.toilets().count, DemoData.toilets.count)
        try reopened.save(LocalData())
        XCTAssertTrue(try reopened.load().reviews.isEmpty)
        XCTAssertTrue(try reopened.load().reports.isEmpty)
        XCTAssertTrue(try reopened.load().favoriteIDs.isEmpty)
        XCTAssertEqual(try reopened.toilets().count, DemoData.toilets.count)
    }
    func testFailedTransactionRetainsPreviouslySavedData() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let db = try Database(url: url)
        let id = DemoData.toilets[0].id
        try db.save(LocalData(favoriteIDs: [id]))
        // Missing foreign key must fail after deletes and trigger rollback.
        XCTAssertThrowsError(try db.save(LocalData(favoriteIDs: ["missing-toilet"])))
        XCTAssertEqual(try db.load().favoriteIDs, [id])
    }
    func testOnePersonalReviewPerToiletIsEnforcedByDatabase() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let db = try Database(url: url)
        let id = DemoData.toilets[0].id
        let a = Review(toiletID: id, scores: ["soap": 2], comment: "", photos: [])
        let b = Review(toiletID: id, scores: ["soap": 5], comment: "", photos: [])
        XCTAssertThrowsError(try db.save(LocalData(reviews: [a, b])))
        XCTAssertTrue(try db.load().reviews.isEmpty)
    }
}

final class RouteRegressionTests: XCTestCase {
    func testNearestPresentationCarriesSnapshotAndRejectsEmptyResults() throws {
        XCTAssertNil(NearestRouteRequest(destinations: []))
        var results = DemoData.toilets
        let request = try XCTUnwrap(NearestRouteRequest(destinations: results))
        results.removeAll()
        XCTAssertEqual(request.destinations.map(\.id), DemoData.toilets.map(\.id))
        XCTAssertNotEqual(request.id, NearestRouteRequest(destinations: DemoData.toilets)?.id)
    }

    func testNavigationRejectsStaleAndInvalidGPSFixes() {
        let now = Date()
        func fix(age: TimeInterval, accuracy: Double = 10, latitude: Double = 42.5) -> CLLocation {
            CLLocation(coordinate: .init(latitude: latitude, longitude: 27.47), altitude: 0,
                       horizontalAccuracy: accuracy, verticalAccuracy: 10, timestamp: now.addingTimeInterval(-age))
        }
        XCTAssertTrue(RouteSelection.isRecentLocation(fix(age: 2), now: now))
        XCTAssertFalse(RouteSelection.isRecentLocation(fix(age: 20), now: now))
        XCTAssertFalse(RouteSelection.isRecentLocation(fix(age: 0, accuracy: -1), now: now))
        XCTAssertFalse(RouteSelection.isRecentLocation(fix(age: 0, latitude: 100), now: now))
    }

    @MainActor func testEmptyDestinationsShowErrorWithoutRequestingRoute() async {
        var called = false
        let model = WalkingRoute { _ in called = true; return [] }
        await model.calculate(from: CLLocation(latitude: 42.5, longitude: 27.47), destinations: [])
        XCTAssertFalse(called)
        XCTAssertFalse(model.loading)
        XCTAssertNotNil(model.error)
    }

    @MainActor func testTimeoutIgnoresLateResultAndAllowsRetry() async {
        let started = expectation(description: "Route request started")
        let timedOut = expectation(description: "Visible timeout")
        var continuation: CheckedContinuation<[MKRoute], Error>?
        var calls = 0
        let successfulRoute = MKRoute()
        let model = WalkingRoute(timeoutNanoseconds: 20_000_000) { _ in
            calls += 1
            if calls > 1 { return [successfulRoute] }
            return try await withCheckedThrowingContinuation { pending in
                continuation = pending
                started.fulfill()
            }
        }
        let observer = model.$error.compactMap { $0 }.sink { _ in timedOut.fulfill() }
        let task = Task { await model.calculate(from: CLLocation(latitude: 42.5, longitude: 27.47), destinations: DemoData.toilets) }
        await fulfillment(of: [started, timedOut], timeout: 3)
        observer.cancel()
        let timeoutMessage = model.error
        XCTAssertFalse(model.loading)
        XCTAssertNotNil(timeoutMessage)
        continuation?.resume(returning: [MKRoute()])
        await task.value
        XCTAssertNil(model.route)
        XCTAssertEqual(model.error, timeoutMessage)
        await model.calculate(from: CLLocation(latitude: 42.5, longitude: 27.47), destinations: DemoData.toilets)
        XCTAssertTrue(model.route === successfulRoute)
        XCTAssertNil(model.error)
        XCTAssertFalse(model.loading)
    }

    @MainActor func testCancelledRequestCannotOverwriteNewRoute() async {
        let started = expectation(description: "First request started")
        var continuation: CheckedContinuation<[MKRoute], Error>?
        var calls = 0
        let successfulRoute = MKRoute()
        let model = WalkingRoute { _ in
            calls += 1
            if calls > 1 { return [successfulRoute] }
            return try await withCheckedThrowingContinuation { pending in
                continuation = pending
                started.fulfill()
            }
        }
        let task = Task { await model.calculate(from: CLLocation(latitude: 42.5, longitude: 27.47), destinations: DemoData.toilets) }
        await fulfillment(of: [started], timeout: 3)
        model.cancel()
        XCTAssertFalse(model.loading)
        await model.calculate(from: CLLocation(latitude: 42.5, longitude: 27.47), destinations: DemoData.toilets)
        continuation?.resume(throwing: URLError(.cancelled))
        await task.value
        XCTAssertTrue(model.route === successfulRoute)
        XCTAssertNil(model.error)
        XCTAssertFalse(model.loading)
    }
}

final class CityFavoritesRegressionTests: XCTestCase {
    private func saved(_ category: EventCategory = .shopping, name: String = "Shop", latitude: Double = 42.505) -> SavedCityPlace {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: .init(latitude: latitude, longitude: 27.474)))
        item.name = name
        return SavedCityPlace(place: CityPlace(item: item, category: category, savedAddress: "Бургас, ул. Тест 1"),
                              savedAt: Date(timeIntervalSince1970: 1234))
    }
    private var scope: CityFavoriteScope { .init(server: "https://one.supabase.co", userID: "User-A") }
    func testIdentityIsStableWithinCategoryAndSeparateAcrossCategories() {
        XCTAssertEqual(saved(name: "  SHOP ", latitude: 42.5050001).id, saved(name: "Shop", latitude: 42.5050002).id)
        XCTAssertNotEqual(saved(.shopping).id, saved(.convenience).id)
        var state = CityFavoriteState(scope: scope)
        state.save(saved()); state.save(saved()); state.save(saved(.convenience))
        XCTAssertEqual(state.places.count, 2)
        XCTAssertEqual(state.pending.count, 2)
    }
    func testLegacyNonstopsMergeWithShopsWithoutChangingStoredIDs() throws {
        let legacy = saved(.convenience, name: "Shop 24/7")
        let current = saved(.shopping, name: "Shop 24/7")
        XCTAssertNotEqual(legacy.id, current.id)
        XCTAssertEqual(legacy.groupID, current.groupID)
        XCTAssertEqual(SavedCityPlace.uniquePlaces([legacy, current]).count, 1)
        let decoded = try JSONDecoder().decode(SavedCityPlace.self, from: JSONEncoder().encode(legacy))
        XCTAssertEqual(decoded.category, .convenience)
        XCTAssertEqual(decoded.category.section, .shopping)
        XCTAssertEqual(decoded.id, legacy.id)
        XCTAssertEqual(SavedCityPlace.groupIdentifier(for: decoded.place), current.groupID)
        XCTAssertEqual(EventCategory.allCases, [.toilets, .restaurants, .atms, .shopping, .hospitals, .pharmacies, .fuel, .charging, .transport])
        let longName = MKMapItem(placemark: MKPlacemark(coordinate: .init(latitude: 42.505, longitude: 27.474)))
        longName.name = String(repeating: "Shop ", count: 50)
        let longPlace = CityPlace(item: longName, category: .shopping)
        XCTAssertEqual(SavedCityPlace(place: longPlace).groupID, SavedCityPlace.groupIdentifier(for: longPlace))
    }
    func testRemovingMergedShopQueuesEveryStoredAliasAndKeepsOtherPlaces() throws {
        let legacy = saved(.convenience), current = saved(.shopping), atm = saved(.atms)
        var state = CityFavoriteState(scope: scope)
        state.acceptRemote([legacy, current, atm])
        state.removeGroup(current.groupID)
        XCTAssertEqual(state.places.map(\.id), [atm.id])
        XCTAssertEqual(Set(state.pending.map(\.id)), Set([legacy.id, current.id]))
        XCTAssertTrue(state.pending.allSatisfy { $0.place == nil })
        let reloaded = try JSONDecoder().decode(CityFavoriteState.self, from: JSONEncoder().encode(state))
        var merged = reloaded
        merged.acceptRemote([legacy, current, atm])
        XCTAssertEqual(merged.places.map(\.id), [atm.id])
        XCTAssertTrue(merged.isValid)
    }
    func testSavedPlaceReopensWithItsOriginalIdentityAddressAndCoordinates() throws {
        let original = saved(.atms)
        let decoded = try JSONDecoder().decode(SavedCityPlace.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.place.address, original.address)
        XCTAssertEqual(SavedCityPlace.identifier(for: decoded.place), original.id)
        XCTAssertEqual(decoded.place.coordinate.latitude, original.latitude)
        XCTAssertEqual(decoded.place.category, .atms)
    }
    func testOfflineRemovalSurvivesRelaunchAndDoesNotReappearFromOldRemoteData() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let place = saved()
        var state = CityFavoriteState(scope: scope)
        state.save(place); state.remove(place.id)
        try CityFavoriteCache.write(state, directory: folder)
        var reloaded = try CityFavoriteCache.read(scope, directory: folder)
        reloaded.acceptRemote([place])
        XCTAssertTrue(reloaded.places.isEmpty)
        XCTAssertEqual(reloaded.pending.count, 1)
        XCTAssertNil(reloaded.pending.first?.place)
        reloaded.save(place)
        XCTAssertEqual(reloaded.pending.count, 1)
        XCTAssertNotNil(reloaded.pending.first?.place)
    }
    func testRemoteMergeKeepsUnsentAdditionsAndOtherPhonesFavorites() {
        let local = saved(.atms), remote = saved(.restaurants)
        var state = CityFavoriteState(scope: scope)
        state.save(local)
        state.acceptRemote([remote, remote])
        XCTAssertEqual(Set(state.places.map(\.id)), Set([local.id, remote.id]))
        XCTAssertEqual(state.pending.map(\.id), [local.id])
    }
    func testCacheSeparatesAccountsAndServersAndRejectsWrongOwner() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        var state = CityFavoriteState(scope: scope); state.save(saved())
        try CityFavoriteCache.write(state, directory: folder)
        let otherUser = CityFavoriteScope(server: scope.server, userID: "User-B")
        let otherServer = CityFavoriteScope(server: "https://two.supabase.co", userID: scope.userID)
        XCTAssertTrue(try CityFavoriteCache.read(otherUser, directory: folder).places.isEmpty)
        XCTAssertTrue(try CityFavoriteCache.read(otherServer, directory: folder).places.isEmpty)
        let wrongFile = try CityFavoriteCache.url(for: otherUser, directory: folder)
        try JSONEncoder().encode(state).write(to: wrongFile)
        XCTAssertThrowsError(try CityFavoriteCache.read(otherUser, directory: folder))
        XCTAssertEqual(try CityFavoriteCache.read(scope, directory: folder), state)
    }
    func testInvalidCoordinatesWrongCategoryAndUnsafeLinksAreRejected() {
        XCTAssertFalse(saved(.toilets).isValid)
        XCTAssertNil(SavedCityPlace.safeWebsite("javascript:alert(1)"))
        XCTAssertNil(SavedCityPlace.safeWebsite("file:///etc/passwd"))
        XCTAssertEqual(SavedCityPlace.safeWebsite("https://example.com"), "https://example.com")
        let place = saved()
        var object = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(place)) as! [String: Any]
        object["latitude"] = 100
        let invalid = try! JSONDecoder().decode(SavedCityPlace.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertFalse(invalid.isValid)
    }
}

final class CitySearchRegressionTests: XCTestCase {
    // Synthetic MKMapItems on macOS do not retain assigned POI categories.
    // Override that metadata so category filtering is exercised without live lookups.
    private final class TestMapItem: MKMapItem {
        private var testCategory: MKPointOfInterestCategory?
        override var pointOfInterestCategory: MKPointOfInterestCategory? {
            get { testCategory }
            set { testCategory = newValue }
        }
    }
    private func item(_ name: String, latitude: Double = 42.505, category: MKPointOfInterestCategory = .atm) -> MKMapItem {
        let value = TestMapItem(placemark: MKPlacemark(coordinate: .init(latitude: latitude, longitude: 27.474)))
        value.name = name
        value.pointOfInterestCategory = category
        return value
    }
    func testResultsExcludeOtherAreasCategoriesAndDuplicates() {
        let atm = item("ATM")
        let places = CitySearchArea.places(from: [atm, atm, item("Other city", latitude: 43), item("Cafe", category: .cafe)],
                                          category: .atms, region: CitySearchArea.burgas)
        XCTAssertEqual(places.map(\.name), ["ATM"])
        XCTAssertFalse(CitySearchArea.contains(.init(latitude: 500, longitude: 27), in: CitySearchArea.burgas))
    }
    func testNonstopFilterUsesLabelsAndKeepsOnlyShopsInTheSearchArea() {
        let shop = item("Супермаркет", category: .store)
        let nonstop = item("Магазин Нон-Стоп", category: .store)
        let named24 = item("Shop 24/7", category: .store)
        let atm = item("ATM 24/7")
        let distant = item("Nonstop", latitude: 43, category: .store)
        let source = [shop, nonstop, named24, atm, distant]
        let all = CitySearchArea.places(from: source, category: .shopping, region: CitySearchArea.burgas)
        let filtered = CitySearchArea.places(from: source, category: .shopping, region: CitySearchArea.burgas, shopFilter: .nonstop)
        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(filtered.map(\.name), ["Магазин Нон-Стоп", "Shop 24/7"])
        XCTAssertTrue(filtered.allSatisfy { $0.category == .shopping })
        for name in ["Non Stop", "Денонощен магазин", "24 HOURS", "Магазин 24 часа"] {
            XCTAssertTrue(ShopFilter.hasNonstopLabel(name), name)
        }
        for name in ["Shop 24", "Convenience store", "Store", "Nonstopper", "124/7"] {
            XCTAssertFalse(ShopFilter.hasNonstopLabel(name), name)
        }
        let other = CitySearchArea.places(from: [atm], category: .atms, region: CitySearchArea.burgas, shopFilter: .nonstop)
        XCTAssertEqual(other.count, 1)
        XCTAssertEqual(CitySearchArea.places(from: [shop], category: .convenience, region: CitySearchArea.burgas).first?.category, .shopping)
    }
    @MainActor func testFilterChangeCannotBeOverwrittenByLateAllShopsSearch() async {
        let started = expectation(description: "All shops started")
        var pending: CheckedContinuation<[MKMapItem], Error>?
        var calls = 0
        let ordinary = item("Supermarket", category: .store), nonstop = item("Nonstop Shop", category: .store)
        let model = CityPlacesSearch { _ in
            calls += 1
            if calls > 1 { return [ordinary, nonstop] }
            return try await withCheckedThrowingContinuation { pending = $0; started.fulfill() }
        }
        let old = Task { await model.search(category: .shopping, query: "", region: CitySearchArea.burgas) }
        await fulfillment(of: [started], timeout: 1)
        await model.search(category: .shopping, query: "", region: CitySearchArea.burgas, shopFilter: .nonstop)
        XCTAssertEqual(model.places.map(\.name), ["Nonstop Shop"])
        pending?.resume(returning: [ordinary]); await old.value
        XCTAssertEqual(model.places.map(\.name), ["Nonstop Shop"])
    }
    func testExternalPlaceCanNavigateWithoutInventingToiletFacts() {
        let place = CityPlace(item: item("Station", category: .publicTransport), category: .transport)
        let target = place.walkingDestination
        XCTAssertTrue(target.id.hasPrefix("mapkit:"))
        XCTAssertEqual(target.name, place.name)
        XCTAssertEqual(target.coordinate.latitude, place.coordinate.latitude)
        XCTAssertEqual(target.kind, EventCategory.transport.title)
        XCTAssertNil(target.price)
        XCTAssertNil(target.hours)
        XCTAssertTrue(target.amenities.isEmpty)
    }
    @MainActor func testCategoryChangeCannotBeOverwrittenByLateSearch() async {
        let started = expectation(description: "ATM request started")
        var pending: CheckedContinuation<[MKMapItem], Error>?
        var calls = 0
        let cafe = item("Cafe", category: .cafe)
        let model = CityPlacesSearch { _ in
            calls += 1
            if calls > 1 { return [cafe] }
            return try await withCheckedThrowingContinuation { pending = $0; started.fulfill() }
        }
        let old = Task { await model.search(category: .atms, query: "", region: CitySearchArea.burgas) }
        await fulfillment(of: [started], timeout: 3)
        await model.search(category: .restaurants, query: "", region: CitySearchArea.burgas)
        pending?.resume(returning: [item("Old ATM")])
        await old.value
        XCTAssertEqual(model.places.map(\.name), ["Cafe"])
        XCTAssertEqual(model.places.first?.category, .restaurants)
        XCTAssertFalse(model.loading)
        XCTAssertNil(model.message)
    }
    @MainActor func testTimeoutIgnoresLateCompletionAndCanRetry() async {
        let timedOut = expectation(description: "Visible search timeout")
        var pending: CheckedContinuation<[MKMapItem], Error>?
        var calls = 0
        let atm = item("ATM")
        let model = CityPlacesSearch(timeout: .milliseconds(20)) { _ in
            calls += 1
            if calls > 1 { return [atm] }
            return try await withCheckedThrowingContinuation { pending = $0 }
        }
        let observer = model.$message.compactMap { $0 }.sink { _ in timedOut.fulfill() }
        let old = Task { await model.search(category: .atms, query: "", region: CitySearchArea.burgas) }
        await fulfillment(of: [timedOut], timeout: 3)
        observer.cancel()
        XCTAssertFalse(model.loading)
        XCTAssertNotNil(model.message)
        pending?.resume(returning: [atm])
        await old.value
        XCTAssertTrue(model.places.isEmpty)
        await model.search(category: .atms, query: "", region: CitySearchArea.burgas)
        XCTAssertEqual(model.places.map(\.name), ["ATM"])
        XCTAssertNil(model.message)
    }
    @MainActor func testFailureClearsPreviousResultsAndToiletsSkipExternalSearch() async {
        var calls = 0
        let atm = item("ATM")
        let model = CityPlacesSearch { _ in
            calls += 1
            if calls == 1 { return [atm] }
            throw URLError(.notConnectedToInternet)
        }
        await model.search(category: .atms, query: "", region: CitySearchArea.burgas)
        XCTAssertEqual(model.places.count, 1)
        await model.search(category: .atms, query: "missing", region: CitySearchArea.burgas)
        XCTAssertTrue(model.places.isEmpty)
        XCTAssertNotNil(model.message)
        await model.search(category: .toilets, query: "", region: CitySearchArea.burgas)
        XCTAssertEqual(calls, 2)
        XCTAssertFalse(model.loading)
        XCTAssertNil(model.message)
    }
}


final class CityMapRegressionTests: XCTestCase {
    private func place(_ category: EventCategory, name: String = "Place") -> CityPlace {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: .init(latitude: 42.505, longitude: 27.474)))
        item.name = name
        return CityPlace(item: item, category: category)
    }
    func testPanningAndSearchingKeepTheCameraCommandStableUntilExplicitRecenter() {
        var viewport = CityMapViewport()
        let initial = viewport.camera.id
        let moved = MKCoordinateRegion(center: .init(latitude: 42.51, longitude: 27.48), span: .init(latitudeDelta: 0.007, longitudeDelta: 0.01))
        viewport.record(moved, userMoved: true)
        XCTAssertTrue(viewport.needsSearch)
        XCTAssertEqual(viewport.camera.id, initial)
        viewport.markSearched()
        XCTAssertFalse(viewport.needsSearch)
        XCTAssertEqual(viewport.region.center.latitude, moved.center.latitude)
        XCTAssertEqual(viewport.region.span.latitudeDelta, moved.span.latitudeDelta)
        XCTAssertEqual(viewport.camera.id, initial)
        viewport.recenter(CitySearchArea.burgas)
        XCTAssertNotEqual(viewport.camera.id, initial)
        XCTAssertEqual(viewport.camera.region.center.latitude, CitySearchArea.burgas.center.latitude)
        XCTAssertFalse(viewport.needsSearch)
    }
    func testLayoutCallbacksDoNotPretendTheUserPannedAndInvalidCamerasAreIgnored() {
        var viewport = CityMapViewport()
        viewport.record(CitySearchArea.burgas, userMoved: false)
        XCTAssertFalse(viewport.needsSearch)
        let initial = viewport.camera.id
        let invalid = MKCoordinateRegion(center: .init(latitude: 999, longitude: 27), span: .init(latitudeDelta: 0, longitudeDelta: 0))
        viewport.record(invalid, userMoved: true)
        viewport.recenter(invalid)
        XCTAssertEqual(viewport.camera.id, initial)
        XCTAssertEqual(viewport.region.center.latitude, CitySearchArea.burgas.center.latitude)
        XCTAssertFalse(viewport.needsSearch)
    }
    func testCategorySwitchChangesOnlyPinsAndCannotReuseAnotherCategorysIdentity() {
        let atm = CityMapPin(place: place(.atms)), restaurant = CityMapPin(place: place(.restaurants))
        XCTAssertNotEqual(atm.id, restaurant.id)
        let changes = CityMapPinChanges.between([atm.id: atm], and: [restaurant, restaurant])
        XCTAssertEqual(changes.removed, [atm.id])
        XCTAssertEqual(changes.upserted, [restaurant])
        let empty = CityMapPinChanges.between([restaurant.id: restaurant], and: [])
        XCTAssertEqual(empty.removed, [restaurant.id])
        XCTAssertTrue(empty.upserted.isEmpty)
    }
    func testUnchangedAndReorderedPinsDoNotRebuildAnnotations() {
        let a = CityMapPin(place: place(.atms, name: "ATM A")), b = CityMapPin(place: place(.atms, name: "ATM B"))
        let old = [a.id: a, b.id: b]
        let changes = CityMapPinChanges.between(old, and: [b, a, a])
        XCTAssertTrue(changes.removed.isEmpty)
        XCTAssertTrue(changes.upserted.isEmpty)
    }
}

final class CommunityPlacesRegressionTests: XCTestCase {
    private func record() -> CommunityPlace {
        CommunityPlace(id: "00000000-0000-4000-8000-000000000001", created_by: "00000000-0000-4000-8000-000000000002",
            category: .shopping, name: "Test shop", address: "Burgas", latitude: 42.505, longitude: 27.474,
            website: nil, notes: "", is_nonstop: nil)
    }
    func testValidationRejectsInvalidCategoryCoordinatesAndWebsites() {
        var row = record(); XCTAssertNil(row.validationMessage)
        row.category = .toilets; XCTAssertNotNil(row.validationMessage)
        row = record(); row.latitude = .nan; XCTAssertNotNil(row.validationMessage)
        row = record(); row.website = "javascript:alert(1)"; XCTAssertNotNil(row.validationMessage)
        row = record(); row.name = " \n "; XCTAssertNotNil(row.validationMessage)
        row = record(); row.category = .atms; row.is_nonstop = true; XCTAssertNotNil(row.validationMessage)
    }
    func testExplicitNonstopOverridesNameWithoutGuessingUnknown() {
        var row = record()
        XCTAssertFalse(ShopFilter.nonstop.matches(row.place))
        row.is_nonstop = true; XCTAssertTrue(ShopFilter.nonstop.matches(row.place))
        row.name = "24/7 Test"; row.is_nonstop = false; XCTAssertFalse(ShopFilter.nonstop.matches(row.place))
        row.is_nonstop = nil; XCTAssertTrue(ShopFilter.nonstop.matches(row.place))
    }
    func testSharedPlaceFilteringAndDeduplication() {
        let row = record()
        let apple = CityPlace(item: row.place.item, category: .shopping, savedAddress: row.address)
        var outside = row; outside.id = UUID().uuidString; outside.latitude = 43
        let values = CityPlaceCatalogue.visible([row.place, apple, outside.place], category: .shopping,
            query: "", region: CitySearchArea.burgas, shopFilter: .all)
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values.first?.source, .community)
        XCTAssertTrue(CityPlaceCatalogue.visible([row.place], category: .atms, query: "", region: CitySearchArea.burgas, shopFilter: .all).isEmpty)
        XCTAssertTrue(CityPlaceCatalogue.visible([row.place], category: .shopping, query: "no match", region: CitySearchArea.burgas, shopFilter: .all).isEmpty)
        // MKLocalSearch already performs semantic matching (e.g. coffee -> a named cafe).
        XCTAssertEqual(CityPlaceCatalogue.visible([apple], category: .shopping, query: "supermarket", region: CitySearchArea.burgas, shopFilter: .all).count, 1)
    }
    func testFavoritesPreserveProvenanceAndOldPayloadsRemainReadable() throws {
        var row = record(); row.is_nonstop = true; row.notes = "Open all night"
        let saved = SavedCityPlace(place: row.place)
        let data = try JSONEncoder().encode(saved)
        let decoded = try JSONDecoder().decode(SavedCityPlace.self, from: data)
        XCTAssertEqual(decoded.place.source, .community)
        XCTAssertEqual(decoded.place.sourceID, row.id)
        XCTAssertEqual(decoded.place.isNonstop, true)
        row.name = "Renamed by admin"; row.latitude = 42.506
        XCTAssertTrue(saved.matches(row.place))
        XCTAssertEqual(SavedCityPlace.uniquePlaces([saved, SavedCityPlace(place: row.place)]).count, 1)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in ["source", "sourceID", "notes", "isNonstop"] { legacy.removeValue(forKey: key) }
        let old = try JSONDecoder().decode(SavedCityPlace.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(old.place.source, .appleMaps)
        XCTAssertEqual(old.id, saved.id)
    }
}

final class BurgasTransitRegressionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func bus(age: Double, latitude: Double = 42.505) -> BurgasLiveBus {
        BurgasLiveBus(id: "test-vehicle", route: "Test", label: "Fixture only", latitude: latitude, longitude: 27.474,
                      bearing: nil, observed_at: now.timeIntervalSince1970 - age)
    }
    func testStaleFutureAndInvalidGPSNeverCountAsLive() {
        XCTAssertTrue(bus(age: 30).isFresh(at: now))
        XCTAssertTrue(bus(age: 120).isFresh(at: now))
        XCTAssertFalse(bus(age: 121).isFresh(at: now))
        XCTAssertFalse(bus(age: -31).isFresh(at: now))
        XCTAssertFalse(bus(age: 1, latitude: 999).isFresh(at: now))
        XCTAssertFalse(bus(age: .nan).isFresh(at: now))
    }
    func testDownloadTimeDoesNotRefreshAnOldGPSFix() {
        let snapshot = BurgasLiveSnapshot(vehicles: [bus(age: 121)], fetched_at: now.timeIntervalSince1970)
        XCTAssertTrue(snapshot.freshVehicles(at: now).isEmpty)
        XCTAssertEqual(BurgasLiveSnapshot(vehicles: [bus(age: 10), bus(age: 10)], fetched_at: 0).freshVehicles(at: now).count, 1)
    }
    func testLiveMarkerUpdateDoesNotChangeIdentityOrCamera() {
        let first = CityMapPin(bus: bus(age: 1))
        let moved = CityMapPin(bus: bus(age: 1, latitude: 42.506))
        XCTAssertEqual(first.id, moved.id)
        XCTAssertTrue(first.isVehicle)
        let changes = CityMapPinChanges.between([first.id: first], and: [moved])
        XCTAssertTrue(changes.removed.isEmpty)
        XCTAssertEqual(changes.upserted, [moved])
        let stop = BurgasBusStop(id: "test-vehicle", name: "Test stop", stop_code: nil, latitude: 42.505, longitude: 27.474)
        XCTAssertNotEqual(CityMapPin(place: stop.place).id, first.id)
        XCTAssertEqual(stop.place.source, .burgasbus)
    }
    @MainActor
    func testCancellingTransitStopsPollingAndClearsVehicles() async {
        let store = BurgasTransitStore()
        var requests = 0
        let task = Task {
            await store.run(scope: "fixture", stops: { [] }, live: {
                requests += 1
                return BurgasLiveSnapshot(vehicles: [], fetched_at: Date().timeIntervalSince1970)
            }, interval: .milliseconds(10))
        }
        for _ in 0..<100 where requests == 0 { await Task.yield() }
        XCTAssertGreaterThan(requests, 0)
        task.cancel(); await task.value
        let stoppedCount = requests
        try? await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(requests, stoppedCount)
        XCTAssertTrue(store.vehicles.isEmpty)
        XCTAssertFalse(store.loading)
    }
    @MainActor
    func testOldScopeResponseCannotReplaceNewScopeStops() async {
        let store = BurgasTransitStore()
        let oldStop = BurgasBusStop(id: "old", name: "Old", stop_code: nil, latitude: 42.505, longitude: 27.474)
        var resumeOld: CheckedContinuation<[BurgasBusStop], Never>?
        let old = Task {
            await store.run(scope: "old", stops: {
                await withCheckedContinuation { resumeOld = $0 }
            }, live: { nil })
        }
        while resumeOld == nil { await Task.yield() }
        let newer = Task { await store.run(scope: "new", stops: { [] }, live: { nil }) }
        for _ in 0..<10 { await Task.yield() }
        resumeOld?.resume(returning: [oldStop])
        await old.value
        XCTAssertTrue(store.stops.isEmpty)
        newer.cancel(); await newer.value
    }
}


final class OpeningDiscoveryRegressionTests: XCTestCase {
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    // Monday in winter: local 10:00–18:00 (UTC+2).
    private let monday = [OpeningInterval(weekday: 2, opens: 600, closes: 1080)]
    func testOpeningSoonBoundaryAndExclusiveClosingTime() {
        XCTAssertEqual(OpeningSchedule.availability(monday, at: date("2026-01-05T06:59:59Z")), .closed)
        XCTAssertEqual(OpeningSchedule.availability(monday, at: date("2026-01-05T07:00:00Z")), .openingSoon(minutes: 60))
        XCTAssertEqual(OpeningSchedule.availability(monday, at: date("2026-01-05T07:59:30Z")), .openingSoon(minutes: 1))
        XCTAssertEqual(OpeningSchedule.availability(monday, at: date("2026-01-05T08:00:00Z")), .open)
        XCTAssertEqual(OpeningSchedule.availability(monday, at: date("2026-01-05T15:59:59Z")), .open)
        XCTAssertEqual(OpeningSchedule.availability(monday, at: date("2026-01-05T16:00:00Z")), .closed)
    }
    func testOvernightWeekRolloverAndSplitHours() {
        let overnight = [OpeningInterval(weekday: 1, opens: 22 * 60, closes: 2 * 60)]
        XCTAssertEqual(OpeningSchedule.availability(overnight, at: date("2026-01-04T21:00:00Z")), .open)
        XCTAssertEqual(OpeningSchedule.availability(overnight, at: date("2026-01-04T23:59:00Z")), .open)
        XCTAssertEqual(OpeningSchedule.availability(overnight, at: date("2026-01-05T00:00:00Z")), .closed)
        let midnight = [OpeningInterval(weekday: 2, opens: 0, closes: 120)]
        XCTAssertEqual(OpeningSchedule.availability(midnight, at: date("2026-01-04T21:30:00Z")), .openingSoon(minutes: 30))
        let split = [OpeningInterval(weekday: 2, opens: 480, closes: 720), OpeningInterval(weekday: 2, opens: 780, closes: 1080)]
        XCTAssertEqual(OpeningSchedule.availability(split, at: date("2026-01-05T10:30:00Z")), .openingSoon(minutes: 30))
    }
    func testSofiaTimezoneAndDaylightSaving() {
        XCTAssertEqual(OpeningSchedule.availability(monday, at: date("2026-07-06T06:00:00Z")), .openingSoon(minutes: 60))
        let sunday = [OpeningInterval(weekday: 1, opens: 4 * 60, closes: 8 * 60)]
        XCTAssertEqual(OpeningSchedule.availability(sunday, at: date("2026-03-29T00:30:00Z")), .openingSoon(minutes: 30))
        XCTAssertEqual(OpeningSchedule.availability(sunday, at: date("2026-10-25T01:30:00Z")), .openingSoon(minutes: 30))
    }
    func testUnknownInvalidClosedAndAllDayRemainDistinct() {
        let now = date("2026-01-05T08:00:00Z")
        XCTAssertEqual(OpeningSchedule.availability(nil, at: now), .unknown)
        XCTAssertEqual(OpeningSchedule.availability([], at: now), .closed)
        XCTAssertEqual(OpeningSchedule.availability([.init(weekday: 9, opens: 0, closes: 1440)], at: now), .unknown)
        XCTAssertFalse(OpeningSchedule.isValid([.init(weekday: 2, opens: 60, closes: 60)]))
        XCTAssertFalse(OpeningSchedule.isValid(Array(repeating: monday[0], count: 29)))
        XCTAssertTrue(OpeningSchedule.isValid(OpeningSchedule.allDay))
        XCTAssertEqual(OpeningSchedule.availability(OpeningSchedule.allDay, at: now), .open)
        XCTAssertTrue(PlaceAvailability.unknown.appearsInDiscovery)
        XCTAssertFalse(PlaceAvailability.closed.appearsInDiscovery)
    }
    private func record(_ hours: [OpeningInterval]?) -> CommunityPlace {
        .init(id: UUID().uuidString, created_by: UUID().uuidString, category: .shopping, name: "Shop 24/7",
              address: "Burgas", latitude: 42.505, longitude: 27.474, website: nil, notes: "", is_nonstop: nil, hours: hours)
    }
    func testClosedCommunityPlaceCannotReappearAsUnknownAppleDuplicate() {
        let row = record([]), apple = CityPlace(item: record(nil).place.item, category: .shopping)
        let result = CityPlaceCatalogue.visible([row.place, apple], category: .shopping, query: "", region: CitySearchArea.burgas, shopFilter: .all)
        XCTAssertTrue(result.isEmpty)
        XCTAssertTrue(CityPlaceCatalogue.visible([row.place, apple], category: .shopping, query: "", region: CitySearchArea.burgas, shopFilter: .nonstop).isEmpty)
        XCTAssertEqual(CityPlaceCatalogue.visible([record(nil).place], category: .shopping, query: "", region: CitySearchArea.burgas, shopFilter: .all).count, 1)
        var stop = row; stop.category = .transport
        XCTAssertEqual(CityPlaceCatalogue.visible([stop.place], category: .transport, query: "", region: CitySearchArea.burgas, shopFilter: .all).count, 1)
    }
    func testScheduleOverridesNonstopAndNameDoesNotProveOpen() {
        var row = record(nil)
        XCTAssertEqual(row.place.availability(), .unknown)
        row.is_nonstop = true
        XCTAssertEqual(row.place.availability(), .open)
        row.hours = []
        XCTAssertEqual(row.place.availability(), .closed)
        XCTAssertFalse(ShopFilter.nonstop.matches(row.place))
        row.hours = OpeningSchedule.allDay; row.is_nonstop = false
        XCTAssertTrue(ShopFilter.nonstop.matches(row.place))
        XCTAssertEqual(row.place.walkingDestination.hours, OpeningSchedule.allDay)
    }
    func testHoursSurviveFavoriteRoundtripAndLegacyPayloadsStillDecode() throws {
        let row = record(monday), favorite = SavedCityPlace(place: row.place)
        let data = try JSONEncoder().encode(favorite)
        XCTAssertEqual(try JSONDecoder().decode(SavedCityPlace.self, from: data).place.hours, monday)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        legacy.removeValue(forKey: "hours")
        XCTAssertNil(try JSONDecoder().decode(SavedCityPlace.self, from: JSONSerialization.data(withJSONObject: legacy)).hours)
        let legacyPlaceData = try JSONEncoder().encode(record(nil))
        XCTAssertNil(try JSONDecoder().decode(CommunityPlace.self, from: legacyPlaceData).hours)
    }
    func testToiletDiscoveryUsesHoursWithoutRemovingAmenitiesOrTextSearch() {
        let row = record(monday).place.walkingDestination
        XCTAssertTrue(row.matchesDiscovery(query: "shop", at: date("2026-01-05T07:30:00Z")))
        XCTAssertFalse(row.matchesDiscovery(query: "other", at: date("2026-01-05T07:30:00Z")))
        XCTAssertFalse(row.matchesDiscovery(query: "", at: date("2026-01-05T18:00:00Z")))
    }
}

final class RestaurantCoverageRegressionTests: XCTestCase {
    private func item(_ name: String) -> MKMapItem {
        let value = MKMapItem(placemark: MKPlacemark(coordinate: CitySearchArea.burgas.center))
        value.name = name
        return value
    }
    func testSearchCoversOuterDistrictsWithBoundedTilesAndKeepsSmallAreasLocal() {
        let region = CitySearchArea.restaurantBurgas
        let tiles = CitySearchArea.restaurantRegions(in: region)
        XCTAssertEqual(tiles.count, 9)
        for coordinate in [CLLocationCoordinate2D(latitude: 42.561, longitude: 27.518), // Sarafovo
                           CLLocationCoordinate2D(latitude: 42.456, longitude: 27.417), // Meden Rudnik
                           CitySearchArea.burgas.center] {
            XCTAssertTrue(tiles.contains { CitySearchArea.contains(coordinate, in: $0) })
        }
        XCTAssertTrue(tiles.allSatisfy { CitySearchArea.contains($0.center, in: region) })
        let small = MKCoordinateRegion(center: region.center, span: .init(latitudeDelta: 0.005, longitudeDelta: 0.005))
        XCTAssertEqual(CitySearchArea.restaurantRegions(in: small).count, 1)
    }
    @MainActor func testProgressiveDeduplicatedResultsCacheAndExplicitRefresh() async {
        var calls = 0
        let common = item("Common")
        let model = CityPlacesSearch(batchPause: .zero) { _ in
            calls += 1
            return [common, self.item("Place \(calls)")]
        }
        var observedCounts: [Int] = []
        let observer = model.$places.sink { observedCounts.append($0.count) }
        await model.search(category: .restaurants, query: "", region: CitySearchArea.restaurantBurgas)
        XCTAssertEqual(calls, 9)
        XCTAssertEqual(model.places.count, 10)
        XCTAssertTrue(observedCounts.contains(2))
        XCTAssertTrue(observedCounts.contains(10))
        XCTAssertFalse(model.loading)
        await model.search(category: .restaurants, query: "", region: CitySearchArea.restaurantBurgas)
        XCTAssertEqual(calls, 9)
        await model.search(category: .restaurants, query: "", region: CitySearchArea.restaurantBurgas, force: true)
        XCTAssertEqual(calls, 18)
        observer.cancel()
    }
    @MainActor func testFailedDistrictRetainsResultsWithoutCachingIncompleteSearch() async {
        var calls = 0
        let value = item("Restaurant")
        let model = CityPlacesSearch(batchPause: .zero) { _ in
            calls += 1
            if calls == 2 { throw URLError(.notConnectedToInternet) }
            return [value]
        }
        await model.search(category: .restaurants, query: "", region: CitySearchArea.restaurantBurgas)
        XCTAssertEqual(model.places.count, 1)
        XCTAssertNotNil(model.message)
        XCTAssertFalse(model.loading)
        await model.search(category: .restaurants, query: "", region: CitySearchArea.restaurantBurgas)
        XCTAssertEqual(calls, 11)
        XCTAssertNil(model.message)
    }
    @MainActor func testSwitchingCategoryDuringBatchIgnoresLateRestaurantResults() async {
        var calls = 0
        var pending: CheckedContinuation<[MKMapItem], Error>?
        let started = expectation(description: "Second district in flight")
        let restaurant = item("Restaurant"), atm = item("ATM")
        let model = CityPlacesSearch(batchPause: .zero) { _ in
            calls += 1
            if calls == 2 { return try await withCheckedThrowingContinuation { pending = $0; started.fulfill() } }
            return calls == 1 ? [restaurant] : [atm]
        }
        let batch = Task { await model.search(category: .restaurants, query: "", region: CitySearchArea.restaurantBurgas) }
        await fulfillment(of: [started], timeout: 3)
        XCTAssertEqual(model.places.map(\.name), ["Restaurant"])
        await model.search(category: .atms, query: "", region: CitySearchArea.burgas)
        pending?.resume(returning: [restaurant]); await batch.value
        XCTAssertEqual(model.places.map(\.name), ["ATM"])
        XCTAssertFalse(model.loading)
        XCTAssertNil(model.message)
    }
}

@MainActor
final class RestaurantCommunityRegressionTests: XCTestCase {
    private func review(_ index: Int, rating: Int = 4) -> RestaurantReview {
        RestaurantReview(id: UUID(uuidString: String(format: "10000000-0000-4000-8000-%012d", index))!,
            place_id: "place", author_id: "author", rating: rating, comment: "Nice food", updated_at: "2026-10-07T10:20:30+00:00", author_name: "Sam")
    }
    private func snapshot(reviews: [RestaurantReview], count: Int? = nil, average: Double? = 4,
                          mine: RestaurantReview? = nil, photos: [RestaurantPhoto] = []) -> RestaurantSnapshot {
        RestaurantSnapshot(review_count: count ?? reviews.count, photo_count: photos.count, average_rating: average,
            reviews: reviews, photos: photos, my_review: mine)
    }
    func testRatingAndUnicodeTextLimits() {
        XCTAssertFalse(RestaurantContribution.validReview(rating: 0, comment: ""))
        XCTAssertFalse(RestaurantContribution.validReview(rating: 6, comment: ""))
        XCTAssertTrue(RestaurantContribution.validReview(rating: 5, comment: ""))
        XCTAssertTrue(RestaurantContribution.validReview(rating: 1, comment: String(repeating: "я", count: 2000)))
        XCTAssertFalse(RestaurantContribution.validReview(rating: 4, comment: String(repeating: "я", count: 2001)))
        // PostgreSQL char_length counts combining scalars separately, matching the client limit.
        XCTAssertFalse(RestaurantContribution.validReview(rating: 3, comment: String(repeating: "e\u{301}", count: 1001)))
    }
    func testOwnershipRequiresSessionAndSupportsModeration() {
        XCTAssertFalse(RestaurantContribution.mayDelete(author: "ALICE", user: nil, admin: true))
        XCTAssertTrue(RestaurantContribution.mayDelete(author: "ALICE", user: "alice", admin: false))
        XCTAssertFalse(RestaurantContribution.mayDelete(author: "alice", user: "bob", admin: false))
        XCTAssertTrue(RestaurantContribution.mayDelete(author: "alice", user: "bob", admin: true))
    }
    func testServerDatesWithAndWithoutFractionalSeconds() {
        XCTAssertNotNil(RestaurantContribution.date("2026-10-07T10:20:30.123456+00:00"))
        XCTAssertNotNil(RestaurantContribution.date("2026-10-07T10:20:30+00:00"))
        XCTAssertNil(RestaurantContribution.date("yesterday"))
    }
    func testEmptyRestaurantHasNoInventedRating() async {
        let feed = RestaurantFeed()
        await feed.load { _, _ in self.snapshot(reviews: [], average: nil) }
        XCTAssertNil(feed.average)
        XCTAssertEqual(feed.reviewCount, 0)
        XCTAssertTrue(feed.loaded)
        XCTAssertFalse(feed.moreReviews)
        XCTAssertNil(feed.myReview)
    }
    func testServerAggregateNotRecomputedFromLoadedPage() async {
        let feed = RestaurantFeed()
        await feed.load { _, _ in self.snapshot(reviews: [self.review(1, rating: 5)], count: 100, average: 3.2) }
        XCTAssertEqual(feed.average, 3.2)
        XCTAssertEqual(feed.reviewCount, 100)
        XCTAssertTrue(feed.moreReviews)
    }
    func testPaginationDeduplicatesAndAdvancesByRawPageSize() async {
        let feed = RestaurantFeed()
        await feed.load { _, _ in self.snapshot(reviews: [self.review(1),self.review(2)], count: 5) }
        await feed.load(page: .reviews) { r, p in
            XCTAssertEqual(r, 2); XCTAssertEqual(p, 0)
            return self.snapshot(reviews: [self.review(2), self.review(3)], count: 5)
        }
        XCTAssertEqual(feed.reviews.count, 3)
        await feed.load(page: .reviews) { r, _ in
            XCTAssertEqual(r, 4)
            return self.snapshot(reviews: [self.review(4)], count: 5)
        }
        XCTAssertFalse(feed.moreReviews)
        XCTAssertEqual(feed.reviews.count, 4)
    }
    func testFailedRefreshKeepsLastSuccessfulDataAndRetryClearsError() async {
        struct Offline: Error {}
        let feed = RestaurantFeed()
        await feed.load { _, _ in self.snapshot(reviews: [self.review(1)]) }
        await feed.load { _, _ in throw Offline() }
        XCTAssertEqual(feed.reviews.count, 1)
        XCTAssertNotNil(feed.error)
        XCTAssertFalse(feed.loading)
        await feed.load { _, _ in self.snapshot(reviews: [self.review(2)]) }
        XCTAssertNil(feed.error)
        XCTAssertEqual(feed.reviews.first?.id, review(2).id)
    }
    func testAccountChangeDiscardsLateResponse() async {
        let feed = RestaurantFeed()
        var pending: CheckedContinuation<RestaurantSnapshot, Never>?
        let old = Task { await feed.load { _, _ in await withCheckedContinuation { pending = $0 } } }
        while pending == nil { await Task.yield() }
        feed.reset()
        await feed.load { _, _ in self.snapshot(reviews: [self.review(2)], mine: self.review(2)) }
        pending?.resume(returning: snapshot(reviews: [review(1)], mine: review(1)))
        await old.value
        XCTAssertEqual(feed.myReview?.id, review(2).id)
        XCTAssertEqual(feed.reviews.map(\.id), [review(2).id])
        XCTAssertFalse(feed.loading)
    }
    func testCancelledResponseDoesNotOverwriteState() async {
        let feed = RestaurantFeed()
        var pending: CheckedContinuation<RestaurantSnapshot, Never>?
        let task = Task { await feed.load { _, _ in await withCheckedContinuation { pending = $0 } } }
        while pending == nil { await Task.yield() }
        task.cancel()
        pending?.resume(returning: snapshot(reviews: [review(1)]))
        await task.value
        XCTAssertFalse(feed.loaded)
        XCTAssertTrue(feed.reviews.isEmpty)
        XCTAssertNil(feed.error)
        XCTAssertFalse(feed.loading)
    }
    func testOwnReviewLoadedEvenWhenNotOnFirstPage() async {
        let feed = RestaurantFeed()
        await feed.load { _, _ in self.snapshot(reviews: [self.review(1)], count: 100, mine: self.review(99)) }
        XCTAssertEqual(feed.myReview?.id, review(99).id)
        XCTAssertEqual(feed.reviews.map(\.id), [review(1).id])
    }
    func testPhotoPagesDoNotReplaceReviewList() async {
        let feed = RestaurantFeed()
        let first = RestaurantPhoto(id: UUID(), place_id: "place", author_id: "author", caption: "Food",
            thumbnail_base64: "YWJj", created_at: "2026-10-07T10:20:30+00:00", author_name: "Sam")
        await feed.load { _, _ in self.snapshot(reviews: [self.review(1)], photos: [first]) }
        await feed.load(page: .photos) { _, offset in
            XCTAssertEqual(offset, 1)
            return self.snapshot(reviews: [self.review(2)], photos: [])
        }
        XCTAssertEqual(feed.reviews.map(\.id), [review(1).id])
        XCTAssertEqual(feed.photos.first?.thumbnail, Data("abc".utf8))
    }
    func testPhotoPreparationRejectsInvalidBytes() {
        XCTAssertNil(RestaurantImage.prepare(Data("not an image".utf8)))
    }
    func testPhotoPreparationDownsizesAndStripsMetadata() throws {
        let width = 2400, height = 1600
        let bytes = Data(repeating: 180, count: width * height * 4)
        let provider = try XCTUnwrap(CGDataProvider(data: bytes as CFData))
        let source = try XCTUnwrap(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let input = NSMutableData()
        let target = try XCTUnwrap(CGImageDestinationCreateWithData(input, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(target, source, [kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 42.5, kCGImagePropertyGPSLongitude: 27.4]] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(target))
        let prepared = try XCTUnwrap(RestaurantImage.prepare(input as Data))
        XCTAssertLessThanOrEqual(prepared.full.count, RestaurantContribution.maxPhotoBytes)
        XCTAssertLessThanOrEqual(prepared.thumbnail.count, RestaurantContribution.maxThumbnailBytes)
        let result = try XCTUnwrap(CGImageSourceCreateWithData(prepared.full as CFData, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(result, 0, nil) as? [String: Any])
        XCTAssertLessThanOrEqual(properties[kCGImagePropertyPixelWidth as String] as? Int ?? 9999, 1280)
        XCTAssertNil(properties[kCGImagePropertyGPSDictionary as String])
    }
}

@MainActor
final class RestaurantFailureRegressionTests: XCTestCase {
    func testMissingRPCPreservesServerCodeAndShowsSetup() {
        let failure = CloudError.serverResponse(status: 404, data: Data(#"{"code":"PGRST202","message":"Could not find the function public.restaurant_community"}"#.utf8))
        XCTAssertEqual(failure.status, 404)
        XCTAssertEqual(failure.code, "PGRST202")
        XCTAssertEqual(RestaurantLoadFailure.classify(failure), .setupRequired)
        XCTAssertNotEqual(RestaurantLoadFailure.classify(failure).symbol, "wifi.exclamationmark")
    }
    func testMissingTablesAndPartialMigrationShowSetup() {
        for code in ["PGRST205", "42P01", "42883", "42703"] {
            XCTAssertEqual(RestaurantLoadFailure.classify(CloudError("Missing object", status: 400, code: code)), .setupRequired)
        }
    }
    func testOnlyConnectivityErrorsShowOfflineMessage() {
        XCTAssertEqual(RestaurantLoadFailure.classify(URLError(.notConnectedToInternet)), .offline)
        XCTAssertEqual(RestaurantLoadFailure.classify(URLError(.networkConnectionLost)), .offline)
        XCTAssertEqual(RestaurantLoadFailure.classify(URLError(.timedOut)), .timedOut)
        XCTAssertEqual(RestaurantLoadFailure.classify(URLError(.cannotConnectToHost)), .server)
        XCTAssertEqual(RestaurantLoadFailure.classify(URLError(.cannotFindHost)), .server)
    }
    func testAuthAndServiceFailuresStayDistinct() {
        XCTAssertEqual(RestaurantLoadFailure.classify(CloudError("Expired", status: 401)), .authentication)
        XCTAssertEqual(RestaurantLoadFailure.classify(CloudError("Denied", status: 403)), .permission)
        XCTAssertEqual(RestaurantLoadFailure.classify(CloudError("Denied", status: 400, code: "42501")), .permission)
        XCTAssertEqual(RestaurantLoadFailure.classify(CloudError("Slow down", status: 429)), .rateLimited)
        XCTAssertEqual(RestaurantLoadFailure.classify(CloudError("Unavailable", status: 503)), .server)
        XCTAssertEqual(RestaurantLoadFailure.classify(CloudError("Unexpected")), .unknown)
        let decoding = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Bad response"))
        XCTAssertEqual(RestaurantLoadFailure.classify(decoding), .invalidResponse)
    }
    func testLoginMessagesRemainSpecificAndKeepMetadata() {
        let error = CloudError.serverResponse(status: 400, data: Data(#"{"error_code":"invalid_credentials","msg":"Invalid login credentials"}"#.utf8))
        XCTAssertEqual(error.code, "invalid_credentials")
        XCTAssertTrue(error.message.contains("Невалиден имейл или парола"))
        let expired = CloudError.serverResponse(status: 403, data: Data(#"{"error_code":"otp_expired"}"#.utf8))
        XCTAssertTrue(expired.message.contains("Кодът е невалиден или изтекъл"))
        XCTAssertEqual(expired.code, "otp_expired")
    }
    func testFeedRecoversAfterDatabaseSetupWithoutAppRestart() async {
        let feed = RestaurantFeed()
        await feed.load { _, _ in throw CloudError("Missing function", status: 404, code: "PGRST202") }
        XCTAssertEqual(feed.failure, .setupRequired)
        XCTAssertFalse(feed.loaded)
        XCTAssertFalse(feed.loading)
        await feed.load { _, _ in RestaurantSnapshot(review_count: 0, photo_count: 0, average_rating: nil, reviews: [], photos: [], my_review: nil) }
        XCTAssertNil(feed.failure)
        XCTAssertTrue(feed.loaded)
        XCTAssertTrue(feed.reviews.isEmpty)
    }
    func testURLSessionCancellationIsNotReportedAsError() async {
        let feed = RestaurantFeed()
        await feed.load { _, _ in throw URLError(.cancelled) }
        XCTAssertNil(feed.failure)
        XCTAssertFalse(feed.loading)
        XCTAssertFalse(feed.loaded)
    }
}

final class GoogleReviewsRegressionTests: XCTestCase {
    private let request = GoogleRestaurantRequest(name: "Ореха & café #1", address: "Богориди 51", latitude: 42.49, longitude: 27.47, restaurantID: "restaurant-one")
    func testWidgetURLRequiresHTTPSAndNoEmbeddedCredentials() {
        for input in ["", "http://example.com/", "javascript:alert(1)", "https://key@example.com/", "https://example.com/?key=secret", "https://example.com/#hash"] {
            XCTAssertNil(GoogleReviewsConfiguration.validatedURL(input))
        }
        XCTAssertNotNil(GoogleReviewsConfiguration.validatedURL("https://reviews.example.com/"))
    }
    func testRestaurantContextRoundTripsInFragmentWithoutQueryOrSession() throws {
        let base = try XCTUnwrap(URL(string: "https://reviews.example.com/"))
        let url = try XCTUnwrap(request.widgetURL(base: base, placeID: "ChIJ-test-place-123456"))
        let parts = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertNil(parts.query)
        let fragment = try XCTUnwrap(URLComponents(string: "?" + (parts.percentEncodedFragment ?? "")))
        XCTAssertEqual(fragment.queryItems?.first(where: { $0.name == "name" })?.value, request.name)
        XCTAssertEqual(Set(fragment.queryItems?.map(\.name) ?? []), ["name", "address", "lat", "lng", "place"])
    }
    func testInvalidCoordinatesAndPlaceIDAreNotSent() throws {
        let base = try XCTUnwrap(URL(string: "https://reviews.example.com/"))
        let bad = GoogleRestaurantRequest(name: "Test", address: "", latitude: .nan, longitude: 27, restaurantID: "id")
        XCTAssertNil(bad.widgetURL(base: base, placeID: nil))
        let url = try XCTUnwrap(request.widgetURL(base: base, placeID: "https://wrong.example/"))
        XCTAssertFalse(url.absoluteString.contains("place="))
    }
    func testBridgeTrustIsRestrictedToExactHTTPSOrigin() throws {
        let base = try XCTUnwrap(URL(string: "https://reviews.example.com/"))
        XCTAssertTrue(GoogleReviewsConfiguration.sameOrigin(URL(string: "https://reviews.example.com/privacy.html")!, base))
        for input in ["https://reviews.example.com.evil.test/", "http://reviews.example.com/", "https://reviews.example.com:8443/", "https://user@reviews.example.com/"] {
            XCTAssertFalse(GoogleReviewsConfiguration.sameOrigin(URL(string: input)!, base))
        }
    }
    func testSelectedPlaceIsRememberedExpiresAndCanBeCleared() throws {
        let suite = "GoogleReviewsTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite)); defer { defaults.removePersistentDomain(forName: suite) }
        let matches = GoogleRestaurantMatches(defaults: defaults), now = Date()
        XCTAssertNil(matches.placeID(for: request))
        matches.save("ChIJ-test-place-123456", for: request, now: now)
        XCTAssertEqual(matches.placeID(for: request, now: now), "ChIJ-test-place-123456")
        XCTAssertNil(matches.placeID(for: request, now: now.addingTimeInterval(15_552_001)))
        matches.remove(for: request)
        XCTAssertNil(matches.placeID(for: request, now: now))
    }
    func testChangedAddressDoesNotReuseAnotherBranchsMatch() {
        let changed = GoogleRestaurantRequest(name: request.name, address: "Other street", latitude: request.latitude, longitude: request.longitude, restaurantID: request.restaurantID)
        XCTAssertNotEqual(changed.matchKey, request.matchKey)
        XCTAssertFalse(request.matchKey.contains(request.name))
    }
}


final class HealthcareRegressionTests: XCTestCase {
    private func pharmacy(name: String = "Аптека", hours: [OpeningInterval]? = nil, nonstop: Bool? = nil) -> CityPlace {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: CitySearchArea.burgas.center))
        item.name = name
        return CityPlace(item: item, category: .pharmacies, isNonstop: nonstop, hours: hours)
    }
    func testPharmacyNameNeverImpliesRoundTheClockHours() {
        XCTAssertEqual(PharmacyScheduleKind(place: pharmacy(name: "Фрамар 24")), .unknown)
        XCTAssertEqual(PharmacyScheduleKind(place: pharmacy(name: "Аптека 24/7")), .unknown)
        XCTAssertFalse(PharmacyFilter.nonstop.matches(pharmacy(name: "24/7")))
        XCTAssertFalse(PharmacyFilter.scheduled.matches(pharmacy()))
    }
    func testScheduleTakesPrecedenceOverNonstopFlagAndInvalidHoursStayUnknown() {
        XCTAssertEqual(PharmacyScheduleKind(place: pharmacy(hours: OpeningSchedule.allDay, nonstop: false)), .nonstop)
        XCTAssertEqual(PharmacyScheduleKind(place: pharmacy(hours: [.init(weekday: 2, opens: 540, closes: 1200)], nonstop: true)), .scheduled)
        XCTAssertEqual(PharmacyScheduleKind(place: pharmacy(hours: [.init(weekday: 9, opens: 0, closes: 1440)], nonstop: true)), .unknown)
        XCTAssertEqual(PharmacyScheduleKind(place: pharmacy(nonstop: true)), .nonstop)
    }
    func testClosedPharmacyRemainsDiscoverableButIsNotMarkedOpen() {
        let closed = pharmacy(name: "Closed", hours: []), nonstop = pharmacy(name: "Always", hours: OpeningSchedule.allDay), unknown = pharmacy(name: "Unknown")
        func list(_ filter: PharmacyFilter) -> [CityPlace] {
            CityPlaceCatalogue.visible([closed, nonstop, unknown], category: .pharmacies, query: "", region: CitySearchArea.burgas, shopFilter: .all, pharmacyFilter: filter)
        }
        XCTAssertEqual(list(.all).count, 3)
        XCTAssertEqual(list(.nonstop).map(\.name), ["Always"])
        XCTAssertEqual(list(.scheduled).map(\.name), ["Closed"])
        XCTAssertEqual(closed.availability(), .closed)
        XCTAssertEqual(unknown.availability(), .unknown)
        XCTAssertEqual(nonstop.availability(), .open)
    }
    func testHealthcareFavoritePreservesHoursPhoneAndSource() throws {
        let original = try XCTUnwrap(HealthcareDirectory.places.first { $0.category == .pharmacies })
        let decoded = try JSONDecoder().decode(SavedCityPlace.self, from: JSONEncoder().encode(SavedCityPlace(place: original))).place
        XCTAssertEqual(decoded.hours, original.hours)
        XCTAssertEqual(decoded.phoneURL, original.phoneURL)
        XCTAssertEqual(decoded.source, .healthcareDirectory)
        XCTAssertEqual(decoded.sourceID, original.sourceID)
        XCTAssertEqual(PharmacyScheduleKind(place: decoded), .nonstop)
    }
    func testHealthcareCommunityValidationAllowsPharmaciesButNotHospitalNonstopFlag() {
        var row = CommunityPlace(id: UUID().uuidString, created_by: UUID().uuidString, category: .pharmacies, name: "Test", address: "Burgas", latitude: 42.5, longitude: 27.47, website: nil, notes: "", is_nonstop: true, hours: OpeningSchedule.allDay)
        XCTAssertNil(row.validationMessage)
        row.category = .hospitals
        XCTAssertNotNil(row.validationMessage)
        row.is_nonstop = nil
        XCTAssertNil(row.validationMessage)
    }
    func testDirectoryIncludesBothPharmacySchedulesAndDoesNotAssumeHospitalHours() {
        XCTAssertEqual(HealthcareDirectory.places.filter { $0.category == .hospitals }.count, 3)
        XCTAssertTrue(HealthcareDirectory.places.filter { $0.category == .hospitals }.allSatisfy { $0.hours == nil && $0.isNonstop == nil })
        for filter in [PharmacyFilter.nonstop, .scheduled] {
            XCTAssertTrue(HealthcareDirectory.places.contains { $0.category == .pharmacies && filter.matches($0) })
        }
        XCTAssertTrue(HealthcareDirectory.places.allSatisfy { CitySearchArea.contains($0.coordinate, in: CitySearchArea.restaurantBurgas) })
    }
    func testDeduplicationRequiresMatchingCategoryAndNearbyBranch() throws {
        let known = try XCTUnwrap(HealthcareDirectory.places.first { $0.name.contains("Пулс") })
        let item = MKMapItem(placemark: MKPlacemark(coordinate: known.coordinate)); item.name = "Puls Pharmacy"
        let hit = CityPlace(item: item, category: .pharmacies)
        XCTAssertTrue(HealthcareDirectory.isSamePlace(known, hit))
        XCTAssertFalse(HealthcareDirectory.isSamePlace(known, CityPlace(item: item, category: .hospitals)))
        let distant = MKMapItem(placemark: MKPlacemark(coordinate: .init(latitude: known.coordinate.latitude + 0.01, longitude: known.coordinate.longitude))); distant.name = item.name
        XCTAssertFalse(HealthcareDirectory.isSamePlace(known, CityPlace(item: distant, category: .pharmacies)))
        let catalogue = CityPlaceCatalogue.visible([known, hit], category: .pharmacies, query: "", region: CitySearchArea.restaurantBurgas, shopFilter: .all)
        XCTAssertEqual(catalogue.count, 1)
        XCTAssertEqual(catalogue.first?.source, .healthcareDirectory)
    }
}

extension HealthcareRegressionTests {
    func testHealthcareUsesOneNavigationSlotWhileStoredCategoriesStaySeparate() {
        XCTAssertEqual(EventCategory.navigationCategories.filter(\.isHealthcare), [.hospitals])
        XCTAssertEqual(EventCategory.pharmacies.navigationGroup, .hospitals)
        XCTAssertEqual(EventCategory.hospitals.navigationGroupTitle, "Здраве")
        XCTAssertEqual(EventCategory.pharmacies.navigationGroupTitle, "Здраве")
        XCTAssertEqual(EventCategory.pharmacies.section, .pharmacies)
        XCTAssertTrue(CommunityPlace.categories.contains(.hospitals))
        XCTAssertTrue(CommunityPlace.categories.contains(.pharmacies))
    }
    func testHealthcareFiltersDoNotMixHospitalAndPharmacyResults() throws {
        let hospital = try XCTUnwrap(HealthcareDirectory.places.first { $0.category == .hospitals })
        let nonstop = try XCTUnwrap(HealthcareDirectory.places.first { $0.category == .pharmacies && PharmacyFilter.nonstop.matches($0) })
        let regular = try XCTUnwrap(HealthcareDirectory.places.first { $0.category == .pharmacies && PharmacyFilter.scheduled.matches($0) })
        XCTAssertTrue(HealthcareFilter.hospitals.matches(hospital))
        XCTAssertFalse(HealthcareFilter.pharmacies.matches(hospital))
        XCTAssertFalse(HealthcareFilter.hospitals.matches(nonstop))
        XCTAssertTrue(HealthcareFilter.pharmacies.matches(nonstop))
        XCTAssertTrue(HealthcareFilter.pharmacies.matches(regular))
    }
    func testHealthcareSelectionOnlyOffersPlaceTypes() {
        XCTAssertEqual(HealthcareFilter.allCases, [.hospitals, .pharmacies])
        for selection in HealthcareFilter.allCases {
            XCTAssertEqual(HealthcareFilter(category: selection.category), selection)
        }
    }
}


extension CitySearchRegressionTests {
    @MainActor func testHealthcareUsesOneQueryAndSeparateCachesWhenSwitchingTypes() async {
        var calls = 0
        let hospital = item("Hospital", category: .hospital), pharmacy = item("Pharmacy", category: .pharmacy)
        let model = CityPlacesSearch(batchPause: .zero) { _ in calls += 1; return calls == 1 ? [hospital] : [pharmacy] }
        await model.search(category: .hospitals, query: "", region: CitySearchArea.restaurantBurgas)
        XCTAssertEqual(calls, 1)
        await model.search(category: .pharmacies, query: "", region: CitySearchArea.restaurantBurgas)
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(model.places.map(\.category), [.pharmacies])
        var snapshots: [[String]] = []
        let observer = model.$places.sink { snapshots.append($0.map(\.name)) }
        model.prepare(category: .hospitals, query: "", region: CitySearchArea.restaurantBurgas)
        XCTAssertEqual(model.places.map(\.name), ["Hospital"])
        await model.search(category: .hospitals, query: "", region: CitySearchArea.restaurantBurgas)
        XCTAssertEqual(calls, 2)
        XCTAssertFalse(snapshots.contains([]))
        observer.cancel()
    }
    @MainActor func testRefreshRetainsPinsUntilReplacementThenRemovesObsoletePlaces() async {
        var calls = 0
        var pending: CheckedContinuation<[MKMapItem], Error>?
        let started = expectation(description: "Refresh started")
        let oldItem = item("Old pharmacy", category: .pharmacy), replacement = item("New pharmacy", category: .pharmacy)
        let model = CityPlacesSearch { _ in
            calls += 1
            if calls == 1 { return [oldItem] }
            return try await withCheckedThrowingContinuation { pending = $0; started.fulfill() }
        }
        await model.search(category: .pharmacies, query: "", region: CitySearchArea.burgas)
        let refresh = Task { await model.search(category: .pharmacies, query: "", region: CitySearchArea.burgas, force: true) }
        await fulfillment(of: [started], timeout: 3)
        XCTAssertEqual(model.places.map(\.name), ["Old pharmacy"])
        pending?.resume(returning: [replacement]); await refresh.value
        XCTAssertEqual(model.places.map(\.name), ["New pharmacy"])
    }
    @MainActor func testRapidHealthSwitchRejectsLateHospitalResponse() async {
        var calls = 0
        var pending: CheckedContinuation<[MKMapItem], Error>?
        let started = expectation(description: "Hospital request pending")
        let model = CityPlacesSearch { _ in
            calls += 1
            if calls == 1 { return try await withCheckedThrowingContinuation { pending = $0; started.fulfill() } }
            return [self.item("Pharmacy", category: .pharmacy)]
        }
        let first = Task { await model.search(category: .hospitals, query: "", region: CitySearchArea.burgas) }
        await fulfillment(of: [started], timeout: 3)
        model.prepare(category: .pharmacies, query: "", region: CitySearchArea.burgas)
        await model.search(category: .pharmacies, query: "", region: CitySearchArea.burgas)
        pending?.resume(returning: [item("Wrong hospital", category: .hospital)]); await first.value
        XCTAssertEqual(model.places.map(\.name), ["Pharmacy"])
        XCTAssertFalse(model.loading)
    }
    func testFuelSearchExcludesChargersAndChargingSearchExcludesPetrolStations() {
        let fuel = item("Petrol", category: .gasStation), charger = item("Charger", category: .evCharger)
        let hits = [fuel, charger, item("ATM"), item("Distant", latitude: 44, category: .gasStation)]
        XCTAssertEqual(CitySearchArea.places(from: hits, category: .fuel, region: CitySearchArea.burgas).map(\.name), ["Petrol"])
        XCTAssertEqual(CitySearchArea.places(from: hits, category: .charging, region: CitySearchArea.burgas).map(\.name), ["Charger"])
    }
}

final class FuelAndHoursRegressionTests: XCTestCase {
    private func place(_ category: EventCategory, hours: [OpeningInterval]? = nil, flag: Bool? = nil) -> CityPlace {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: CitySearchArea.burgas.center)); item.name = "Place 24/7"
        return CityPlace(item: item, category: category, isNonstop: flag, hours: hours)
    }
    func testMapBadgeRequiresKnownHoursAndUpdatesWithoutChangingPinIdentity() {
        let unknown = CityMapPin(place: place(.pharmacies)), known = CityMapPin(place: place(.pharmacies, hours: OpeningSchedule.allDay))
        XCTAssertFalse(unknown.isOpen24Hours)
        XCTAssertTrue(known.isOpen24Hours)
        XCTAssertEqual(unknown.id, known.id)
        let changes = CityMapPinChanges.between([unknown.id: unknown], and: [known])
        XCTAssertTrue(changes.removed.isEmpty)
        XCTAssertEqual(changes.upserted, [known])
        XCTAssertFalse(place(.fuel, hours: [], flag: true).hasKnown24HourSchedule)
        XCTAssertFalse(place(.charging, hours: [.init(weekday: 9, opens: 0, closes: 1440)], flag: true).hasKnown24HourSchedule)
        XCTAssertTrue(place(.fuel, flag: true).hasKnown24HourSchedule)
    }
    func testFuelSectionsAndFavoritesKeepIndependentTypesAndHours() throws {
        XCTAssertEqual(EventCategory.navigationCategories.filter(\.isFuel), [.fuel, .charging])
        XCTAssertEqual(EventCategory.charging.navigationGroup, .charging)
        let fuel = place(.fuel, hours: OpeningSchedule.allDay), charger = place(.charging)
        XCTAssertNotEqual(SavedCityPlace(place: fuel).id, SavedCityPlace(place: charger).id)
        let saved = try JSONDecoder().decode(SavedCityPlace.self, from: JSONEncoder().encode(SavedCityPlace(place: fuel)))
        XCTAssertEqual(saved.category, .fuel)
        XCTAssertTrue(CityMapPin(place: saved.place).isOpen24Hours)
        XCTAssertTrue(CommunityPlace.categories.contains(.fuel)); XCTAssertTrue(CommunityPlace.categories.contains(.charging))
        XCTAssertTrue(EventCategory.fuel.supportsNonstop); XCTAssertTrue(EventCategory.charging.supportsNonstop)
    }
}
