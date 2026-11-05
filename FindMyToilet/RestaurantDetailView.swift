import SwiftUI
import MapKit
import PhotosUI

struct RestaurantDetailView: View {
    let originalPlace: CityPlace
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var feed = RestaurantFeed()
    @State private var section = Section.overview
    @State private var reviewSource = ReviewSource.all
    @State private var showRoute = false
    @State private var showReview = false
    @State private var showPhoto = false
    @State private var showEdit = false
    @State private var confirmDelete = false
    @State private var activating = false
    @State private var actionError: String?
    private enum Section: String, CaseIterable { case overview = "Общ преглед", reviews = "Ревюта", photos = "Снимки" }
    private enum ReviewSource: String, CaseIterable { case all = "Всички", community = "Приложението", google = "Google" }
    private var restaurantID: String? { store.sharedRestaurantID(for: originalPlace) }
    private var record: CommunityPlace? { store.sharedPlaces.first { $0.id.lowercased() == restaurantID?.lowercased() } }
    private var place: CityPlace { record?.place ?? originalPlace }
    private var loadKey: String { "\(store.restaurantScope)|\(restaurantID ?? originalPlace.id)" }
    private let category = EventCategory.restaurants
    private var website: URL? { SavedCityPlace.safeWebsite(place.item.url?.absoluteString).flatMap(URL.init(string:)) }
    private var googleRequest: GoogleRestaurantRequest {
        .init(name: place.name, address: place.address, latitude: place.coordinate.latitude,
              longitude: place.coordinate.longitude, restaurantID: restaurantID ?? place.id)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    heading
                    actions
                    Picker("Раздел", selection: $section) {
                        ForEach(Section.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented)
                    if let actionError { Text(actionError).font(.callout).foregroundStyle(.red) }
                    if restaurantID == nil { activateCard }
                    if let failure = feed.failure {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(failure.title, systemImage: failure.symbol).font(.headline)
                            Text(failure.message).font(.callout).foregroundStyle(.secondary)
                            Button(failure == .setupRequired ? "Провери отново" : "Опитай пак") { Task { await refresh() } }.disabled(feed.loading)
                        }.padding(16).appCard()
                    }
                    if feed.loading { ProgressView("Зареждане на общността…").frame(maxWidth: .infinity) }
                    switch section {
                    case .overview: overview
                    case .reviews: reviews
                    case .photos: photos
                    }
                }.padding(16).padding(.bottom, 20)
            }.background(Theme.background)
                .navigationTitle("Хапване").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Готово") { dismiss() } }
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("Обнови", systemImage: "arrow.clockwise") { Task { await refresh() } }
                            if store.isAdmin, record != nil {
                                Button("Редактирай мястото", systemImage: "pencil") { showEdit = true }
                                Button("Изтрий мястото", systemImage: "trash", role: .destructive) { confirmDelete = true }
                            }
                        } label: { Image(systemName: "ellipsis.circle") }
                    }
                }
                .navigationDestination(for: RestaurantReview.self) { review in
                    ScrollView { RestaurantReviewCard(review: review, expanded: true).padding(20) }
                        .background(Theme.background).navigationTitle("Ревю").navigationBarTitleDisplayMode(.inline)
                }
                .navigationDestination(for: RestaurantPhoto.self) { photo in
                    RestaurantPhotoPage(photo: photo) { Task { await refresh() } }
                }
                .refreshable { await refresh() }
                .task(id: loadKey) { feed.reset(); await refresh() }
                .onChange(of: scenePhase) { _, value in if value == .active { Task { await refresh() } } }
                .onChange(of: store.restaurantScope) { _, _ in showReview = false; showPhoto = false; actionError = nil }
                .sheet(isPresented: $showReview) {
                    if let id = restaurantID {
                        RestaurantReviewEditor(placeID: id, name: place.name, existing: feed.myReview,
                            scope: store.restaurantScope) { Task { await refresh() } }
                    }
                }
                .sheet(isPresented: $showPhoto) {
                    if let id = restaurantID {
                        RestaurantPhotoEditor(placeID: id, name: place.name, scope: store.restaurantScope) { Task { await refresh() } }
                    }
                }
                .sheet(isPresented: $showRoute) {
                    RouteView(destinations: [place.walkingDestination], nearest: false,
                              destinationSymbol: category.symbol, category: category).tint(category.ink)
                }
                .sheet(isPresented: $showEdit) { if let record { CityPlaceEditor(category: .restaurants, existing: record) } }
                .confirmationDialog("Изтриване на заведението и споделените му снимки и ревюта?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Изтрий", role: .destructive) {
                        if let record { Task { if await store.deleteCityPlace(record) { dismiss() } } }
                    }
                }
        }.tint(category.ink).storeError()
    }
    private var hero: some View {
        Button { section = .photos } label: {
            ZStack(alignment: .bottomLeading) {
                if let photo = feed.photos.first, let data = photo.thumbnail, let image = UIImage(data: data) {
                    GeometryReader { geometry in
                        Image(uiImage: image).resizable().scaledToFill().frame(width: geometry.size.width, height: 215).clipped()
                    }
                    LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .center, endPoint: .bottom)
                } else {
                    LinearGradient(colors: [category.color, EventTheme.accent], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "fork.knife.circle.fill").font(.system(size: 110)).foregroundStyle(.white.opacity(0.18))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Label(feed.photoCount > 0 ? "\(feed.photoCount) снимки от посетители" : "Място за вкусни спомени", systemImage: "photo.on.rectangle")
                        .font(.headline)
                    Text(feed.photoCount > 0 ? "Разгледай галерията" : "Сподели първата снимка").font(.subheadline)
                }.foregroundStyle(.white).padding(20)
            }.frame(height: 215).clipShape(RoundedRectangle(cornerRadius: 26))
        }.buttonStyle(.plain).accessibilityLabel("Отвори снимките на \(place.name)")
    }
    private var heading: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(place.name).font(.system(.largeTitle, design: .rounded, weight: .bold)).fixedSize(horizontal: false, vertical: true)
            Button { section = .reviews } label: {
                HStack(spacing: 8) {
                    if let average = feed.average {
                        Text(average.formatted(.number.precision(.fractionLength(1)))).font(.headline)
                        RestaurantStars(value: average)
                        Text("(\(feed.reviewCount)) · в приложението").font(.subheadline)
                    } else {
                        RestaurantStars(value: 0)
                        Text(feed.loaded ? "Още няма оценки тук" : "Оценки в приложението").font(.subheadline)
                    }
                }
            }.buttonStyle(.plain)
            HStack(spacing: 8) {
                Text("Заведение · Бургас").font(.subheadline).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            TimelineView(.periodic(from: .now, by: 30)) { context in AvailabilityBadge(availability: place.availability(at: context.date)) }
        }
    }
    private var actions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button { showRoute = true } label: { Label("Маршрут", systemImage: "arrow.triangle.turn.up.right.diamond.fill") }
                    .buttonStyle(CategoryButtonStyle(category: category))
                Button { Task { await store.toggleCityFavorite(place) } } label: {
                    Label(store.isCityFavorite(place) ? "Запазено" : "Запази", systemImage: store.isCityFavorite(place) ? "heart.fill" : "heart")
                }.buttonStyle(CategoryButtonStyle(category: category, prominent: false)).disabled(!store.canSaveCityFavorite)
                if let website { Link(destination: website) { Label("Уебсайт", systemImage: "globe") }.buttonStyle(CategoryButtonStyle(category: category, prominent: false)) }
            }
        }
    }
    private var overview: some View {
        VStack(alignment: .leading, spacing: 18) {
            googleReviewsCard
            VStack(alignment: .leading, spacing: 16) {
                Label(place.address.isEmpty ? "Виж мястото на картата" : place.address, systemImage: "mappin.and.ellipse")
                Divider()
                if place.hours != nil {
                    DisclosureGroup { Text(place.walkingDestination.hoursText).font(.subheadline).monospacedDigit().padding(.top, 8) }
                    label: { Label("Работно време", systemImage: "clock") }
                } else { Label("Работно време: няма информация", systemImage: "clock").foregroundStyle(.secondary) }
                if !place.notes.isEmpty { Divider(); Text(place.notes).font(.subheadline).foregroundStyle(.secondary) }
            }.padding(20).appCard(cornerRadius: 22)
            Map(initialPosition: .region(.init(center: place.coordinate, span: .init(latitudeDelta: 0.006, longitudeDelta: 0.006)))) {
                Marker(place.name, systemImage: "fork.knife", coordinate: place.coordinate).tint(category.color)
                ForEach(store.sharedPlaces.filter { $0.category == .restaurants && $0.id != restaurantID }) { nearby in
                    Marker(nearby.name, coordinate: nearby.place.coordinate).tint(category.color.opacity(0.55))
                }
            }.mapStyle(.standard(pointsOfInterest: .excludingAll)).mapControls { MapCompass(); MapScaleView() }
                .frame(height: 200).clipShape(RoundedRectangle(cornerRadius: 22))
            contributeButtons
            if let first = feed.reviews.first {
                HStack { Text("Последно ревю").font(.title3.bold()); Spacer(); Button("Всички") { section = .reviews } }
                RestaurantReviewCard(review: first)
            }
            Text("\(place.source.title) · Снимките и оценките са от посетители на това приложение.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private var contributeButtons: some View {
        VStack(alignment: .leading, spacing: 12) {
            if restaurantID != nil {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { reviewButton; photoButton }
                    VStack(spacing: 10) { reviewButton; photoButton }
                }
                if store.profile == nil { Text("Влез от „Профил“, за да напишеш ревю или да добавиш снимка.").font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
    private var reviewButton: some View {
        Button { showReview = true } label: { Label(feed.myReview == nil ? "Напиши ревю" : "Редактирай ревюто", systemImage: "star.bubble").frame(maxWidth: .infinity) }
            .buttonStyle(CategoryButtonStyle(category: category)).disabled(store.profile == nil || !feed.loaded || feed.loading)
    }
    private var photoButton: some View {
        Button { showPhoto = true } label: { Label("Добави снимка", systemImage: "camera").frame(maxWidth: .infinity) }
            .buttonStyle(CategoryButtonStyle(category: category, prominent: false)).disabled(store.profile == nil || !feed.loaded || feed.loading)
    }
    private var reviews: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Мнения за \(place.name)").font(.title2.bold())
                Text("От посетители на приложението и Google Maps, на едно място.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Picker("Източник на ревютата", selection: $reviewSource) {
                ForEach(ReviewSource.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            if reviewSource != .google, feed.loaded {
                HStack(spacing: 18) {
                    Text(feed.average.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    VStack(alignment: .leading, spacing: 6) {
                        RestaurantStars(value: feed.average ?? 0)
                        Text("\(feed.reviewCount) оценки в приложението").font(.subheadline).foregroundStyle(.secondary)
                    }
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading).appCard(cornerRadius: 22)
            }
            if reviewSource != .google { contributeButtons }
            if reviewSource != .community {
                GoogleRestaurantReviewsView(request: googleRequest, embedded: true)
                    .id(googleRequest.matchKey)
                    .padding(16).appCard(cornerRadius: 22)
            }
            if reviewSource != .google { communityReviewList }
        }
    }
    private var visibleCommunityReviews: [RestaurantReview] {
        let others = feed.reviews.filter { $0.id != feed.myReview?.id }
        return reviewSource == .all ? Array(others.prefix(3)) : others
    }
    private var communityReviewList: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("От приложението", systemImage: "person.2.fill").font(.title3.bold())
            if feed.loaded && feed.reviews.isEmpty { empty("Бъди първият тук", detail: "Напиши първото ревю в приложението. Google мненията са в секцията по-горе.", symbol: "star.bubble") }
            if let mine = feed.myReview {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Твоето ревю").font(.headline)
                    RestaurantReviewCard(review: mine)
                    RestaurantDeleteButton(id: mine.id, photo: false) { Task { await refresh() } }
                }
            }
            ForEach(visibleCommunityReviews) { review in
                VStack(alignment: .leading, spacing: 10) {
                    RestaurantReviewCard(review: review)
                    if store.isAdmin { RestaurantDeleteButton(id: review.id, photo: false) { Task { await refresh() } } }
                }
            }
            if reviewSource == .all, feed.moreReviews || feed.reviews.filter({ $0.id != feed.myReview?.id }).count > 3 {
                Button("Всички ревюта от приложението") { reviewSource = .community }
            } else if feed.moreReviews {
                Button("Още ревюта") { Task { await refresh(page: .reviews) } }.disabled(feed.loading)
            }
        }
    }
    private var googleReviewsCard: some View {
        Button { reviewSource = .all; section = .reviews } label: {
            HStack(spacing: 14) {
                Image(systemName: "star.bubble.fill").font(.title2).foregroundStyle(category.ink)
                    .frame(width: 48, height: 48).background(category.ink.opacity(0.10), in: RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 5) {
                    Text("Всички ревюта").font(.headline).foregroundStyle(.primary)
                    Text("Приложението и Google Maps")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.subheadline.bold()).foregroundStyle(.secondary)
            }.padding(18).appCard(cornerRadius: 22)
        }.buttonStyle(.plain).accessibilityLabel("Всички ревюта за \(place.name), от приложението и Google Maps")
    }
    private var photos: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Снимки от посетители").font(.title3.bold()); Spacer(); if feed.loaded { Text("\(feed.photoCount)").foregroundStyle(.secondary) } }
            contributeButtons
            if feed.loaded && feed.photos.isEmpty { empty("Покажи мястото", detail: "Добави храна, интериор или меню. Всички посетители ще виждат снимката и автора ѝ.", symbol: "camera") }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 16) {
                ForEach(feed.photos) { photo in
                    NavigationLink(value: photo) {
                        VStack(alignment: .leading, spacing: 8) {
                            RestaurantThumbnail(data: photo.thumbnail).frame(height: 145).clipped().clipShape(RoundedRectangle(cornerRadius: 16))
                            Text(photo.author_name ?? "Посетител").font(.subheadline.bold()).lineLimit(1)
                            if !photo.caption.isEmpty { Text(photo.caption).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                        }
                    }.buttonStyle(.plain)
                }
            }
            if feed.morePhotos { Button("Още снимки") { Task { await refresh(page: .photos) } }.disabled(feed.loading) }
        }
    }
    private var activateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Създай място за споделяне", systemImage: "person.2").font(.headline)
            Text("Добави това заведение към общността, за да има общи снимки и ревюта за всички.").font(.subheadline).foregroundStyle(.secondary)
            if store.profile != nil {
                Button(activating ? "Добавяне…" : "Добави към общността") {
                    let scope = store.restaurantScope
                    activating = true; actionError = nil
                    Task {
                        defer { activating = false }
                        do { _ = try await store.activateRestaurant(place, scope: scope) }
                        catch is CancellationError { }
                        catch { actionError = "Добавянето не успя. Провери връзката и настройката за ресторанти и опитай пак." }
                    }
                }.buttonStyle(CategoryButtonStyle(category: category)).disabled(activating)
            } else { Text("Влез от „Профил“, за да добавиш заведението.").font(.caption) }
        }.padding(18).appCard(cornerRadius: 22)
    }
    private func empty(_ title: String, detail: String, symbol: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.largeTitle).foregroundStyle(category.ink)
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding(28).frame(maxWidth: .infinity).appCard(cornerRadius: 22)
    }
    private func refresh(page: RestaurantFeed.Page? = nil) async {
        guard let id = restaurantID else { return }
        let scope = store.restaurantScope
        await feed.load(page: page) { r, p in try await store.loadRestaurant(id, reviewOffset: r, photoOffset: p, scope: scope) }
    }
}

struct RestaurantStars: View {
    let value: Double
    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: value >= Double(index) ? "star.fill" : (value >= Double(index) - 0.5 ? "star.leadinghalf.filled" : "star"))
            }
        }.foregroundStyle(EventCategory.restaurants.ink).accessibilityElement(children: .ignore)
            .accessibilityLabel("\(value.formatted(.number.precision(.fractionLength(1)))) от 5 звезди")
    }
}

private struct RestaurantAuthor: View {
    let id: String
    let name: String?
    @EnvironmentObject private var store: AppStore
    @State private var showProfile = false
    var body: some View {
        Button { showProfile = true } label: {
            HStack(spacing: 10) {
                ProfileAvatar(profile: store.profiles.first { $0.id.lowercased() == id.lowercased() }
                    ?? UserProfile(id: id, display_name: name ?? "Посетител", role: "user"), size: 38)
                Text(name ?? "Посетител").font(.subheadline.bold()).foregroundStyle(.primary)
            }
        }.buttonStyle(.plain).accessibilityLabel("Профил на \(name ?? "посетителя")")
            .sheet(isPresented: $showProfile) { PublicProfileView(userID: id) }
    }
}

private struct RestaurantReviewCard: View {
    let review: RestaurantReview
    var expanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RestaurantAuthor(id: review.author_id, name: review.author_name)
            Label("Приложението", systemImage: "person.2").font(.caption).foregroundStyle(.secondary)
            if expanded { content }
            else { NavigationLink(value: review) { content }.buttonStyle(.plain) }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).appCard(cornerRadius: 22)
    }
    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                RestaurantStars(value: Double(review.rating))
                Spacer()
                if let date = RestaurantContribution.date(review.updated_at) { Text(date, style: .date).font(.caption).foregroundStyle(.secondary) }
            }
            if !review.comment.isEmpty { Text(review.comment).font(.body).lineLimit(expanded ? nil : 3).frame(maxWidth: .infinity, alignment: .leading) }
            if !expanded { Label("Цялото ревю", systemImage: "chevron.right").font(.caption.bold()).foregroundStyle(EventCategory.restaurants.ink) }
        }.contentShape(Rectangle())
    }
}

private struct RestaurantThumbnail: View {
    let data: Data?
    var body: some View {
        GeometryReader { geometry in
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height).clipped()
            } else { Rectangle().fill(.quaternary).overlay { Image(systemName: "photo").foregroundStyle(.secondary) } }
        }
    }
}

private struct RestaurantPhotoPage: View {
    let photo: RestaurantPhoto
    let onDelete: () -> Void
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var image: Data?
    @State private var error: String?
    @State private var retry = 0
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let bytes = image ?? photo.thumbnail, let bitmap = UIImage(data: bytes) {
                    Image(uiImage: bitmap).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 22))
                }
                RestaurantAuthor(id: photo.author_id, name: photo.author_name)
                if let date = RestaurantContribution.date(photo.created_at) { Text(date, style: .date).font(.subheadline).foregroundStyle(.secondary) }
                if !photo.caption.isEmpty { Text(photo.caption) }
                if let error {
                    Text(error).foregroundStyle(.secondary)
                    Button("Опитай пак") { retry += 1 }
                } else if image == nil { ProgressView("Зареждане на снимката…") }
                if RestaurantContribution.mayDelete(author: photo.author_id, user: store.userID, admin: store.isAdmin) {
                    RestaurantDeleteButton(id: photo.id, photo: true) { onDelete(); dismiss() }
                }
            }.padding(20)
        }.background(Theme.background).navigationTitle("Снимка от посетител").navigationBarTitleDisplayMode(.inline)
            .task(id: "\(store.restaurantScope)|\(retry)") {
                image = nil; error = nil
                do { image = try await store.loadRestaurantPhoto(photo.id, scope: store.restaurantScope) }
                catch is CancellationError { }
                catch { self.error = "Снимката не се зареди или е премахната." }
            }
    }
}

private struct RestaurantDeleteButton: View {
    let id: UUID
    let photo: Bool
    let onDelete: () -> Void
    @EnvironmentObject private var store: AppStore
    @State private var confirm = false
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading) {
            Button(photo ? "Изтрий снимката" : "Изтрий ревюто", role: .destructive) { confirm = true }.disabled(busy)
            if busy { ProgressView() }
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
        }.confirmationDialog(photo ? "Да изтрия снимката?" : "Да изтрия ревюто?", isPresented: $confirm, titleVisibility: .visible) {
            Button("Изтрий", role: .destructive) {
                busy = true; error = nil
                let scope = store.restaurantScope
                Task {
                    defer { busy = false }
                    do { try await store.deleteRestaurantContribution(id: id, photo: photo, scope: scope); onDelete() }
                    catch is CancellationError { }
                    catch { self.error = "Изтриването не успя. Обнови и опитай пак." }
                }
            }
        }
    }
}

private struct RestaurantReviewEditor: View {
    let placeID: String
    let name: String
    let existing: RestaurantReview?
    let scope: String
    let onSave: () -> Void
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var rating: Int
    @State private var comment: String
    @State private var busy = false
    @State private var error: String?
    @State private var discard = false
    init(placeID: String, name: String, existing: RestaurantReview?, scope: String, onSave: @escaping () -> Void) {
        self.placeID = placeID; self.name = name; self.existing = existing; self.scope = scope; self.onSave = onSave
        _rating = State(initialValue: existing?.rating ?? 0); _comment = State(initialValue: existing?.comment ?? "")
    }
    private var changed: Bool { rating != (existing?.rating ?? 0) || comment != (existing?.comment ?? "") }
    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section {
                    Text(name).font(.title2.bold())
                    Text("Как беше посещението?").foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ForEach(1...5, id: \.self) { star in
                            Button { rating = star } label: {
                                Image(systemName: star <= rating ? "star.fill" : "star").font(.system(size: 30)).frame(width: 44, height: 50)
                            }.buttonStyle(.plain).foregroundStyle(EventCategory.restaurants.ink)
                                .accessibilityLabel("\(star) от 5 звезди").accessibilityAddTraits(star == rating ? .isSelected : [])
                        }
                    }
                    if rating > 0 { Text(["", "Лошо", "Не ми хареса", "Добре", "Много добре", "Страхотно"][rating]).font(.headline) }
                }
                SwiftUI.Section("Твоето впечатление") {
                    TextField("Храна, обслужване, атмосфера…", text: $comment, axis: .vertical).lineLimit(5...12)
                    Text("\(comment.unicodeScalars.count)/2000").font(.caption).foregroundStyle(comment.unicodeScalars.count > 2000 ? .red : .secondary)
                }
                SwiftUI.Section {
                    Label("Ревюто ще се вижда от всички с твоето име. Снимки можеш да добавиш отделно в галерията.", systemImage: "person.2").font(.footnote).foregroundStyle(.secondary)
                    if busy { ProgressView("Публикуване…") }
                    if let error { Text(error).foregroundStyle(.red) }
                }
            }.disabled(busy).navigationTitle(existing == nil ? "Напиши ревю" : "Твоето ревю").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Отказ") { if changed { discard = true } else { dismiss() } }.disabled(busy) }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Публикувай") {
                            busy = true; error = nil
                            Task {
                                defer { busy = false }
                                do { try await store.saveRestaurantReview(placeID: placeID, rating: rating, comment: comment, scope: scope); onSave(); dismiss() }
                                catch is CancellationError { }
                                catch { self.error = "Ревюто не е запазено. Провери връзката и опитай отново." }
                            }
                        }.disabled(busy || !changed || !RestaurantContribution.validReview(rating: rating, comment: comment))
                    }
                }.interactiveDismissDisabled(changed || busy)
                .confirmationDialog("Да отхвърля промените?", isPresented: $discard) { Button("Отхвърли", role: .destructive) { dismiss() } }
        }.tint(EventCategory.restaurants.ink)
    }
}

private struct RestaurantPhotoEditor: View {
    let placeID: String
    let name: String
    let scope: String
    let onSave: () -> Void
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var selection: PhotosPickerItem?
    @State private var prepared: RestaurantImage?
    @State private var photoID = UUID()
    @State private var caption = ""
    @State private var busy = false
    @State private var preparing = false
    @State private var error: String?
    @State private var discard = false
    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section {
                    Text(name).font(.title2.bold())
                    if let data = prepared?.full, let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    PhotosPicker(selection: $selection, matching: .images) { Label("Избери снимка", systemImage: "photo.badge.plus") }.disabled(busy || preparing)
                    if preparing { ProgressView("Подготовка на снимката…") }
                    TextField("Описание (незадължително)", text: $caption, axis: .vertical).lineLimit(2...4)
                    Text("\(caption.unicodeScalars.count)/300").font(.caption).foregroundStyle(caption.unicodeScalars.count > 300 ? .red : .secondary)
                }
                SwiftUI.Section {
                    Text("Снимката ще се вижда от всички с твоето име. Споделяй само свои снимки. До 10 снимки от човек за заведение.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if busy { ProgressView("Качване…") }
                    if let error { Text(error).foregroundStyle(.red) }
                }
            }.disabled(busy).navigationTitle("Добави снимка").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отказ") { if prepared != nil || !caption.isEmpty { discard = true } else { dismiss() } }.disabled(busy || preparing)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Сподели") {
                            guard let prepared else { return }
                            busy = true; error = nil
                            Task {
                                defer { busy = false }
                                do { try await store.uploadRestaurantPhoto(id: photoID, placeID: placeID, image: prepared, caption: caption, scope: scope); onSave(); dismiss() }
                                catch is CancellationError { }
                                catch { self.error = "Качването не успя. Провери връзката. Ако вече имаш 10 снимки тук, първо изтрий една от тях." }
                            }
                        }.disabled(prepared == nil || busy || preparing || caption.unicodeScalars.count > 300)
                    }
                }.interactiveDismissDisabled(prepared != nil || !caption.isEmpty || preparing || busy)
                .confirmationDialog("Да отхвърля снимката?", isPresented: $discard) { Button("Отхвърли", role: .destructive) { dismiss() } }
                .task(id: selection) {
                    guard let selection else { return }
                    preparing = true; prepared = nil; error = nil
                    defer { preparing = false }
                    do {
                        guard let bytes = try await selection.loadTransferable(type: Data.self) else { throw CloudError("Невалидна снимка") }
                        let image = await Task.detached(priority: .userInitiated) { RestaurantImage.prepare(bytes) }.value
                        try Task.checkCancellation()
                        guard let image else { throw CloudError("Невалидна снимка") }
                        prepared = image; photoID = UUID()
                    } catch is CancellationError { }
                    catch { self.error = "Снимката не може да бъде прочетена. Опитай друга или провери iCloud връзката." }
                }
        }.tint(EventCategory.restaurants.ink)
    }
}
