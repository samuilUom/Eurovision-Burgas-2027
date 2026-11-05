import SwiftUI
import MapKit

struct ToiletDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .largeTitle) private var ratingSize = 52.0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var focused: Toilet
    private var toilet: Toilet { store.toilets.first { $0.id == focused.id } ?? focused }
    @State private var mapSelection: String?
    @State private var selectedAuthor: UserProfile?
    @State private var selectedFeature: ReviewFeature?
    @State private var openedReviewID: UUID?
    @State private var mapPosition: MapCameraPosition
    @State private var expandedMap = false
    @State private var pendingReviewID: UUID?
    @State private var highlightedReviewID: UUID?
    init(toilet: Toilet, reviewID: UUID? = nil) {
        _openedReviewID = State(initialValue: reviewID)
        _selectedSection = State(initialValue: reviewID == nil ? 0 : 1)
        _pendingReviewID = State(initialValue: reviewID)
        _highlightedReviewID = State(initialValue: reviewID)
        _focused = State(initialValue: toilet)
        _mapSelection = State(initialValue: toilet.id)
        _mapPosition = State(initialValue: .region(Self.region(for: toilet)))
    }
    private static func region(for toilet: Toilet) -> MKCoordinateRegion {
        MKCoordinateRegion(center: toilet.coordinate, span: .init(latitudeDelta: 0.004, longitudeDelta: 0.004))
    }
    @State private var showReview = false
    @State private var showReport = false
    @State private var confirmDelete = false
    @State private var showRoute = false
    @State private var showEdit = false
    @State private var confirmDeleteToilet = false
    @State private var selectedSection = 0
    @State private var starFilter: Int?
    @State private var photosOnly = false
    @State private var reviewSort = "Най-нови"
    private var visibleReviews: [Review] {
        reviews.filter { review in
            (!photosOnly || !review.photos.isEmpty) &&
            (starFilter == nil || review.average.map { Int($0.rounded()) } == starFilter)
        }.sorted { a, b in
            if reviewSort == "Най-високи", a.average != b.average { return (a.average ?? -1) > (b.average ?? -1) }
            if reviewSort == "Най-ниски", a.average != b.average { return (a.average ?? 6) < (b.average ?? 6) }
            return a.updatedAt > b.updatedAt
        }
    }
    private var reviews: [Review] { store.reviews(for: toilet.id) }
    private var gallery: [(review: Review, index: Int)] { reviews.flatMap { review in review.photos.indices.map { (review, $0) } } }
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    placeMap
                        .frame(height: expandedMap ? geometry.size.height * 0.65 : min(280, max(100, geometry.size.height * 0.35)))
                    ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            placeSummary
                            placeActions
                            Picker("Раздел", selection: $selectedSection) {
                                Text("Общ преглед").tag(0)
                                Text("Ревюта").tag(1)
                                Text("Снимки").tag(2)
                            }.pickerStyle(.segmented).padding(.vertical, 2)
                            if selectedSection == 0 { overview }
                            else if selectedSection == 1 { reviewSection }
                            else { photoSection }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .id(focused.id)
                    .task(id: selectedSection) {
                        guard selectedSection == 1, let id = pendingReviewID else { return }
                        // Allow the review cards to lay out before navigating to the target.
                        await Task.yield()
                        guard !Task.isCancelled else { return }
                        if reviews.contains(where: { $0.id == id }) { proxy.scrollTo(id, anchor: .top) }
                        pendingReviewID = nil
                    }
                    .background(Theme.background)
                    .overlay(alignment: .top) {
                        Rectangle().fill(Theme.teal.opacity(0.12)).frame(height: 1).allowsHitTesting(false)
                    }
                    }
                }
            }
            .background(Theme.background)
            .onChange(of: toilet.latitude) { _, _ in recenterMap() }
            .onChange(of: toilet.longitude) { _, _ in recenterMap() }
            .navigationTitle("За мястото").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Готово") { dismiss() } }
            }
            .navigationDestination(isPresented: Binding(get: { openedReviewID != nil }, set: { if !$0 { openedReviewID = nil } })) {
                if let review = reviews.first(where: { $0.id == openedReviewID }) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            if let author = store.profiles.first(where: { $0.id == review.authorID }) {
                                Button { selectedAuthor = author } label: {
                                    HStack(spacing: 12) {
                                        ProfileAvatar(profile: author)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(author.display_name).font(.headline).foregroundStyle(.primary)
                                            Text("Виж профила").font(.caption).foregroundStyle(Theme.teal)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.teal)
                                    }.frame(minHeight: 44).padding(18).appCard()
                                }.buttonStyle(.plain)
                            } else { Text(store.authorName(review)).font(.headline) }
                            reviewContent(review)
                        }.padding(20)
                    }.background(Theme.background)
                        .navigationTitle("Ревю").navigationBarTitleDisplayMode(.inline)
                } else {
                    ContentUnavailableView("Ревюто не е налично", systemImage: "text.bubble")
                }
            }
            .sheet(item: $selectedFeature) { EssentialVotesView(toiletID: toilet.id, feature: $0) }
            .sheet(item: $selectedAuthor) { PublicProfileView(userID: $0.id) }
            .sheet(isPresented: $showReview) { ReviewEditor(toilet: toilet, existing: store.review(for: toilet.id)) }
            .sheet(isPresented: $showReport) { ReportEditor(toilet: toilet) }
            .confirmationDialog("Изтриване на Вашето ревю и снимките към него?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Изтрий ревюто", role: .destructive) { Task { await store.deleteReview(toilet.id) } }
            }
            .sheet(isPresented: $showRoute) { RouteView(destinations: [toilet], nearest: false) }
            .sheet(isPresented: $showEdit) { ToiletEditor(existing: toilet) }
            .confirmationDialog("Изтриване на обекта и всички свързани ревюта, любими и сигнали?", isPresented: $confirmDeleteToilet, titleVisibility: .visible) {
                Button("Изтрий за всички", role: .destructive) { Task { if await store.deleteToilet(toilet.id) { dismiss() } } }
            }
            .onChange(of: store.toilets.map(\.id)) { _, ids in if !ids.contains(focused.id) { dismiss() } }
            .storeError()
        }
    }
    private var placeSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Label("БУРГАС", systemImage: "mappin.circle.fill")
                    .font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(Theme.teal)
                Spacer(minLength: 8)
                Text(toilet.priceText).font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.teal).multilineTextAlignment(.trailing)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Theme.softTeal, in: Capsule())
            }
            Text(toilet.name).font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
            if let average = store.rating(for: toilet.id) {
                Button { selectedSection = 1 } label: {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            Text(String(format: "%.1f", average)).font(.headline).foregroundStyle(.primary)
                            RatingStars(value: average).font(.caption)
                            Text("· \(reviews.count) ревюта").font(.subheadline).foregroundStyle(Theme.teal)
                            Image(systemName: "chevron.right").font(.caption2.bold()).foregroundStyle(Theme.teal)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            RatingStars(value: average)
                            Text("\(reviews.count) ревюта").font(.subheadline).foregroundStyle(Theme.teal)
                        }
                    }.frame(minHeight: 44, alignment: .leading)
                }.buttonStyle(.plain).accessibilityLabel("Виж \(reviews.count) ревюта")
            } else {
                Label("Все още няма оценки", systemImage: "star").font(.subheadline).foregroundStyle(.secondary)
            }
            Label(toilet.address, systemImage: "mappin.and.ellipse")
                .font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    Label(toilet.kind, systemImage: "toilet").font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    StatusLabel(toilet: toilet)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Label(toilet.kind, systemImage: "toilet").font(.caption).foregroundStyle(.secondary)
                    StatusLabel(toilet: toilet)
                }
            }
            if toilet.isDemo { DemoNotice() }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).appCard()
    }
    private var placeActions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button { showRoute = true } label: {
                    Label("Маршрут", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                }.buttonStyle(AppPrimaryButtonStyle())
                Button { Task { await store.toggleFavorite(toilet.id) } } label: {
                    Label(store.isFavorite(toilet.id) ? "Запазено" : "Запази", systemImage: store.isFavorite(toilet.id) ? "bookmark.fill" : "bookmark")
                }.buttonStyle(AppSecondaryButtonStyle()).disabled(!store.canSave)
                Button { showReview = true } label: { Label("Оцени", systemImage: "star") }
                    .buttonStyle(AppSecondaryButtonStyle()).disabled(!store.canSave)
            }
        }
    }
    private var placeMap: some View {
        Map(position: $mapPosition, interactionModes: .all, selection: $mapSelection) {
            ForEach(store.toilets) { place in
                Marker(place.name, systemImage: place.id == toilet.id ? "toilet" : "mappin", coordinate: place.coordinate)
                    .tint(place.id == toilet.id ? Theme.teal : Color.blue)
                    .tag(place.id)
            }
        }
        .onChange(of: mapSelection) { _, id in
            guard let id, id != focused.id, let place = store.toilets.first(where: { $0.id == id }) else { return }
            focused = place
            pendingReviewID = nil
            highlightedReviewID = nil
            selectedSection = 0
            starFilter = nil; photosOnly = false; reviewSort = "Най-нови"
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls { MapCompass(); MapScaleView() }
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 8) {
                Button { withAnimation(.easeInOut(duration: 0.35)) { recenterMap() } } label: {
                    Image(systemName: "scope").frame(width: 46, height: 46)
                }
                .accessibilityLabel("Центрирай върху тоалетната")
                Button { withAnimation(.easeInOut(duration: 0.25)) { expandedMap.toggle() } } label: {
                    Image(systemName: expandedMap ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .frame(width: 46, height: 46)
                }
                .accessibilityLabel(expandedMap ? "Намали картата" : "Разгъни картата")
            }
            .font(.headline).foregroundStyle(Theme.teal).buttonStyle(.plain)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.5)))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
            .padding(.trailing, 12).padding(.bottom, 30)
        }
        .accessibilityLabel("Интерактивна карта около \(toilet.name)")
        .accessibilityHint("Преместете или увеличете картата. Докоснете друга тоалетна, за да отворите информацията ѝ. Бутонът за центриране връща избраното място.")
    }
    private func recenterMap() {
        mapPosition = .region(Self.region(for: toilet))
    }
    private var overview: some View {
        VStack(alignment: .leading, spacing: 18) {
            PlaceHoursCard(toilet: toilet)
            section("Цена") {
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: toilet.price == 0 ? "gift.fill" : "creditcard.fill")
                        .font(.title2).foregroundStyle(Theme.teal)
                        .frame(width: 54, height: 54)
                        .background(Theme.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(toilet.priceText).font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
                        Text(toilet.price == nil ? "Все още няма информация за цената." : (toilet.price == 0 ? "Без такса за достъп" : "Такса за достъп"))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            section("Удобства") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12)], spacing: 12) {
                    ForEach(Amenity.allCases) { amenity in
                        let available = toilet.amenities.contains(amenity)
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: amenity.symbol).font(.title2).foregroundStyle(available ? Theme.teal : .secondary)
                            Text(amenity == .wheelchair ? "Достъпност" : (amenity == .changingTable ? "Повиване" : "Вода")).font(.headline)
                            Label(available ? "Да" : "Непроверено", systemImage: available ? "checkmark.circle.fill" : "questionmark.circle")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(available ? Theme.teal : .secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).padding(14)
                        .background(Theme.teal.opacity(available ? 0.08 : 0.03), in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(amenity.title): \(available ? "Да" : "Непроверено")")
                    }
                }
            }
            section("Основни принадлежности") {
                Text("Според посетителите").font(.subheadline).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12)], spacing: 12) {
                    ForEach(ReviewFeature.allCases) { feature in
                        let answers = reviews.compactMap { $0.observations?[feature.rawValue] }
                        Button { selectedFeature = feature } label: {
                            EssentialReportTile(feature: feature,
                                yesCount: answers.filter { $0 }.count,
                                noCount: answers.filter { !$0 }.count)
                        }.buttonStyle(.plain)
                        .accessibilityHint("Вижте кой е отговорил Да и Не")
                    }
                }
                Text("Брой отговори от ревюта. Наличността може да се променя.").font(.caption).foregroundStyle(.secondary)
            }
            section("Полезно преди посещение") {
                Text(toilet.accessNote).font(.subheadline)
                if let date = toilet.verifiedAt {
                    Text("Проверено: \(date.formatted(date: .abbreviated, time: .omitted))").font(.caption)
                } else { Text("Няма потвърдена проверка на място.").font(.caption).foregroundStyle(.secondary) }
            }
            if !gallery.isEmpty { photoSection }
            Button { showReport = true } label: {
                Label("Предложи корекция / сигнал", systemImage: "flag").frame(maxWidth: .infinity)
            }.buttonStyle(AppSecondaryButtonStyle()).disabled(!store.canSave)
            if store.isAdmin {
                section("Администрация") {
                    Button { showEdit = true } label: {
                        Label("Редактирай обекта", systemImage: "square.and.pencil").frame(maxWidth: .infinity)
                    }.buttonStyle(AppSecondaryButtonStyle()).disabled(!store.canSave)
                    Button("Изтрий обекта", role: .destructive) { confirmDeleteToilet = true }
                        .frame(maxWidth: .infinity, minHeight: 44).disabled(!store.canSave)
                }
            }
            if store.profile == nil { Text("Влезте от „Профил“, за да запазвате места и публикувате ревюта.").font(.caption).foregroundStyle(.secondary) }
        }
    }
    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let id = highlightedReviewID, !reviews.contains(where: { $0.id == id }) {
                Label("Това ревю вече не е налично. Показваме останалите ревюта.", systemImage: "info.circle")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            reviewOverview
            if !reviews.isEmpty {
                reviewControls
                if visibleReviews.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "star.bubble").font(.largeTitle).foregroundStyle(Theme.teal)
                            .accessibilityHidden(true)
                        Text("Няма съвпадащи ревюта").font(.headline)
                        Text("Опитайте друга оценка или покажете всички мнения.")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button("Покажи всички") { starFilter = nil; photosOnly = false }
                            .buttonStyle(AppSecondaryButtonStyle())
                    }.frame(maxWidth: .infinity).padding(24).appCard()
                }
                ForEach(visibleReviews) { review in reviewPreview(review) }
            }
        }
    }

    private var reviewOverview: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let average = store.rating(for: toilet.id) {
                Text("ОЦЕНКА ОТ ПОСЕТИТЕЛИТЕ")
                    .font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(Theme.teal)
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                    : AnyLayout(HStackLayout(alignment: .center, spacing: 18))
                layout {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", average))
                            .font(.system(size: ratingSize, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text("/ 5").font(.subheadline).foregroundStyle(.secondary)
                    }.fixedSize(horizontal: true, vertical: false)
                    VStack(alignment: .leading, spacing: 8) {
                        RatingStars(value: average).font(.title3)
                        Text("\(reviews.count) ревюта")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Text("Докоснете звездите, за да филтрирате")
                    .font(.caption).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach((1...5).reversed(), id: \.self) { bucket in
                            ratingFilterTile(bucket)
                        }
                    }.padding(.vertical, 2)
                }
            } else {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "star.bubble.fill").font(.title)
                        .foregroundStyle(.orange).frame(width: 52, height: 52)
                        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(reviews.isEmpty ? "Първото мнение е важно" : "Очакваме Вашата оценка").font(.title3.bold())
                        Text("Споделете как е било посещението Ви и помогнете на следващия човек.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            Button { showReview = true } label: {
                Label(store.review(for: toilet.id) == nil ? "Напиши ревю" : "Редактирай моето ревю", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }.buttonStyle(AppPrimaryButtonStyle()).disabled(!store.canSave)
            if store.profile == nil {
                Label("Влезте от „Профил“, за да споделите мнение.", systemImage: "person.crop.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18).appCard()
    }

    private func ratingFilterTile(_ bucket: Int) -> some View {
        let count = reviews.filter { Int(($0.average ?? 0).rounded()) == bucket }.count
        let active = starFilter == bucket
        return Button { starFilter = active ? nil : bucket } label: {
            VStack(alignment: .leading, spacing: 10) {
                RatingStars(value: Double(bucket)).font(.caption).fixedSize(horizontal: true, vertical: false)
                HStack(spacing: 8) {
                    Text("\(count)").font(.headline).monospacedDigit().foregroundStyle(.primary)
                    Spacer(minLength: 0)
                    Image(systemName: active ? "checkmark.circle.fill" : "circle")
                        .font(.caption).foregroundStyle(active ? Theme.teal : Color.secondary.opacity(0.5))
                }
            }.padding(12)
                .background(active ? Theme.softTeal : Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(active ? Theme.teal : Theme.border, lineWidth: active ? 1.5 : 1).allowsHitTesting(false))
                .contentShape(RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(bucket) звезди, \(count) ревюта")
            .accessibilityHint("Филтрира мненията по тази оценка. Повторно докосване премахва филтъра.")
            .accessibilityAddTraits(active ? [.isSelected] : [])
    }

    private var reviewControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 10))
            layout {
                VStack(alignment: .leading, spacing: 4) {
                    Text("От посетителите").font(.title3.bold())
                    Text("\(visibleReviews.count) от \(reviews.count) ревюта")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                Menu {
                    Picker("Подреди", selection: $reviewSort) {
                        Text("Най-нови").tag("Най-нови")
                        Text("Най-високи").tag("Най-високи")
                        Text("Най-ниски").tag("Най-ниски")
                    }
                } label: {
                    Label(reviewSort, systemImage: "arrow.up.arrow.down")
                        .font(.caption.weight(.semibold)).foregroundStyle(Theme.teal)
                        .padding(.horizontal, 12).frame(minHeight: 44)
                        .background(Theme.softTeal, in: Capsule())
                }.accessibilityLabel("Подреди ревютата: \(reviewSort)")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    reviewFilter("Всички", symbol: "text.bubble", active: starFilter == nil && !photosOnly) {
                        starFilter = nil; photosOnly = false
                    }
                    reviewFilter("Със снимки", symbol: "photo", active: photosOnly) { photosOnly.toggle() }
                    if let starFilter {
                        reviewFilter("\(starFilter) звезди", symbol: "xmark.circle.fill", active: true) { self.starFilter = nil }
                    }
                }
            }
        }
    }

    private func reviewPreview(_ review: Review) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let author = store.profiles.first(where: { $0.id == review.authorID }) {
                Button { selectedAuthor = author } label: {
                    HStack(spacing: 12) {
                        ProfileAvatar(profile: author)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(author.display_name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                            Text(review.authorID == store.userID ? "Вашето ревю" : "\(store.data.reviews.filter { $0.authorID == author.id }.count) ревюта")
                                .font(.caption).foregroundStyle(review.authorID == store.userID ? Theme.teal : Color.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption.weight(.medium)).foregroundStyle(.tertiary)
                    }.frame(minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel("Отвори профила на \(author.display_name)")
            } else {
                Label(store.authorName(review), systemImage: "person.crop.circle.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            }
            Button { openedReviewID = review.id } label: {
                VStack(alignment: .leading, spacing: 14) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            previewStars(review)
                            Spacer(minLength: 0)
                            Text(review.updatedAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption).foregroundStyle(.secondary).fixedSize()
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            previewStars(review)
                            Text(review.updatedAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if !review.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(review.comment).font(.body).foregroundStyle(.primary).lineSpacing(4).lineLimit(3)
                            .multilineTextAlignment(.leading)
                    } else {
                        Text(review.average == nil ? "Няма добавен коментар." : "Посещението е оценено със звезди.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 10) {
                        Text("Виж ревюто").font(.subheadline.weight(.semibold))
                        Image(systemName: "arrow.up.right").font(.caption.weight(.semibold))
                        Spacer(minLength: 0)
                        if !review.photos.isEmpty {
                            Label("\(review.photos.count)", systemImage: "photo")
                                .font(.caption.weight(.medium)).padding(.horizontal, 9).padding(.vertical, 6)
                                .background(Theme.softTeal, in: Capsule())
                                .accessibilityLabel("\(review.photos.count) снимки в ревюто")
                        }
                    }.foregroundStyle(Theme.teal).frame(minHeight: 44)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).appCard()
            .id(review.id)
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(
                highlightedReviewID == review.id ? Theme.teal : .clear, lineWidth: 2).allowsHitTesting(false))
    }

    @ViewBuilder private func previewStars(_ review: Review) -> some View {
        if let average = review.average {
            RatingStars(value: average).font(.subheadline).fixedSize(horizontal: true, vertical: false)
        } else {
            Label("Без оценка", systemImage: "star").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func reviewFilter(_ title: String, symbol: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).frame(minHeight: 44)
                .foregroundStyle(active ? Color.white : Theme.teal)
                .background(active ? Theme.teal : Theme.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(active ? Color.clear : Theme.border).allowsHitTesting(false))
        }.buttonStyle(.plain).accessibilityAddTraits(active ? .isSelected : [])
    }
    private var photoSection: some View {
        section("Снимки от посетители") {
            if gallery.isEmpty {
                Label("Все още няма снимки. Добавете снимка към Вашето ревю.", systemImage: "photo.on.rectangle.angled")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(gallery.enumerated()), id: \.offset) { _, photo in
                            ReviewPhotoButton(review: photo.review, index: photo.index, width: 240, height: 170)
                        }
                    }
                }
            }
        }
    }
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2).fill(Theme.teal).frame(width: 4, height: 18)
                Text(title).font(.headline)
            }
            content()
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18).appCard()
    }
    @ViewBuilder private func reviewContent(_ review: Review) -> some View {
        section("Посещението") {
            if let average = review.average {
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                    : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
                layout {
                    Text(String(format: "%.1f", average))
                        .font(.largeTitle.weight(.semibold)).monospacedDigit()
                        .padding(12).background(Theme.softTeal, in: RoundedRectangle(cornerRadius: 16))
                    RatingStars(value: average).font(.title3)
                }
            } else {
                Label("Без оценка", systemImage: "star").foregroundStyle(.secondary)
            }
            Label(review.updatedAt.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                .font(.caption).foregroundStyle(.secondary)
            if !review.comment.isEmpty {
                Divider()
                Text(review.comment).font(.body).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            }
        }
        section("Оценки и удобства") {
            ForEach(Criterion.allCases) { criterion in
                if let value = review.scores[criterion.rawValue] {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 14) {
                            Text(criterion.title)
                            Spacer(minLength: 8)
                            RatingStars(value: Double(value)).font(.caption)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text(criterion.title)
                            RatingStars(value: Double(value)).font(.caption)
                        }
                    }.font(.subheadline).padding(.vertical, 4)
                }
            }
            ForEach(ReviewFeature.allCases) { feature in
                if let value = review.observations?[feature.rawValue] {
                    FeatureAnswerRow(feature: feature, answer: value ? "Да" : "Не", positive: value)
                }
            }
        }
        if !review.photos.isEmpty {
            section("Снимки към ревюто") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(review.photos.indices, id: \.self) { index in
                            ReviewPhotoButton(review: review, index: index, width: 220, height: 160)
                        }
                    }
                }
            }
        }
        if review.authorID == store.userID && store.userID != nil {
            VStack(spacing: 8) {
                Button { showReview = true } label: {
                    Label("Редактирай ревюто", systemImage: "square.and.pencil").frame(maxWidth: .infinity)
                }.buttonStyle(AppSecondaryButtonStyle())
                Button("Изтрий ревюто", role: .destructive) { confirmDelete = true }
                    .frame(maxWidth: .infinity, minHeight: 44)
            }.disabled(!store.canSave)
        }
    }

}


private struct PlaceHoursCard: View {
    let toilet: Toilet
    @State private var expanded = false
    private let days = [(2, "Понеделник"), (3, "Вторник"), (4, "Сряда"), (5, "Четвъртък"), (6, "Петък"), (7, "Събота"), (1, "Неделя")]

    private func weekday(at date: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Sofia")!
        return calendar.component(.weekday, from: date)
    }

    private func schedule(_ day: Int) -> String {
        guard let hours = toilet.hours else { return "Непроверено" }
        let intervals = hours.filter { $0.weekday == day }.sorted { $0.opens < $1.opens }
        if intervals.isEmpty { return "Затворено" }
        return intervals.map { interval in
            if interval.opens == 0 && interval.closes == 1440 { return "24 часа" }
            let start = String(format: "%02d:%02d", interval.opens / 60, interval.opens % 60)
            let end = String(format: "%02d:%02d", interval.closes / 60, interval.closes % 60)
            return "\(start) – \(end)" + (interval.closes < interval.opens ? " (+1 ден)" : "")
        }.joined(separator: "\n")
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let today = weekday(at: context.date)
            let availability = toilet.availability(at: context.date)
            let color = availability.color
            VStack(alignment: .leading, spacing: 16) {
                Label("Работно време", systemImage: "clock.fill").font(.headline)
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: availability.symbol)
                        .font(.title2).foregroundStyle(color)
                        .frame(width: 48, height: 48)
                        .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 15))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(availability.title)
                            .font(.title3.bold())
                        if toilet.hours != nil {
                            Text("Днес · \(schedule(today))").font(.subheadline).monospacedDigit()
                        } else {
                            Text("Все още няма добавено работно време.").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                if toilet.hours != nil {
                    Divider()
                    DisclosureGroup(isExpanded: $expanded) {
                        VStack(spacing: 6) {
                            ForEach(days, id: \.0) { day in
                                ViewThatFits(in: .horizontal) {
                                    HStack(alignment: .top) {
                                        Text(day.1).fontWeight(day.0 == today ? .bold : .regular)
                                        Spacer(minLength: 16)
                                        Text(schedule(day.0)).multilineTextAlignment(.trailing).monospacedDigit()
                                    }
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(day.1).bold()
                                        Text(schedule(day.0)).monospacedDigit()
                                    }
                                }
                                .font(.subheadline).padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(day.0 == today ? Theme.teal.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }.padding(.top, 12)
                    } label: {
                        Label("Цялата седмица", systemImage: "calendar").font(.subheadline.weight(.semibold))
                            .frame(minHeight: 44)
                    }.tint(Theme.teal)
                    Text("Местно време за Бургас · +1 ден означава след полунощ.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(18).frame(maxWidth: .infinity, alignment: .leading).appCard()
        }
    }
}


private struct EssentialReportTile: View {
    let feature: ReviewFeature
    let yesCount: Int
    let noCount: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    private var warning: Bool { noCount > yesCount }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: feature.symbol)
                    .font(.title2).foregroundStyle(warning ? Color.orange : Theme.teal)
                    .frame(width: 42, height: 42)
                    .background(warning ? Color.orange.opacity(0.1) : Theme.softTeal, in: RoundedRectangle(cornerRadius: 12))
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            Text(feature.title).font(.headline).fixedSize(horizontal: false, vertical: true)
            if yesCount + noCount == 0 {
                Text("Непроверено").font(.subheadline).foregroundStyle(.secondary)
            } else {
                Label("Да · \(yesCount)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.teal)
                Label("Не · \(noCount)", systemImage: "xmark.circle")
                    .foregroundStyle(warning ? Color.orange : .secondary)
            }
            if warning {
                Label("Повече „Не“", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.bold()).foregroundStyle(.primary)
            }
        }
        .font(.subheadline.weight(.semibold))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).padding(14)
        .background {
            if warning && !reduceMotion && scenePhase == .active {
                RoundedRectangle(cornerRadius: 16)
                    .phaseAnimator([false, true]) { shape, bright in
                        shape.foregroundStyle(Color.orange).opacity(bright ? 0.22 : 0.08)
                    } animation: { _ in .easeInOut(duration: 1.6) }
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(warning ? Color.orange.opacity(0.15) : Theme.teal.opacity(0.05))
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 16)
            .strokeBorder(warning ? Color.orange.opacity(0.7) : .clear, lineWidth: 1.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(feature.accessibilityTitle). \(yesCount + noCount == 0 ? "Непроверено" : "Да: \(yesCount). Не: \(noCount).")\(warning ? " Внимание: повече отрицателни отговори." : "")")
    }
}


private struct EssentialVotesView: View {
    let toiletID: String
    let feature: ReviewFeature
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var author: UserProfile?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: feature.symbol).font(.title2).foregroundStyle(Theme.teal)
                            .frame(width: 48, height: 48).background(Theme.softTeal, in: RoundedRectangle(cornerRadius: 15))
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Отговори от посетителите").font(.headline)
                            Text("Докоснете име, за да видите профила и останалите ревюта.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 6)
                }
                ForEach([true, false], id: \.self) { answer in
                    let votes = store.reviews(for: toiletID).filter { $0.observations?[feature.rawValue] == answer }
                    Section("\(answer ? "Да" : "Не") · \(votes.count)") {
                        if votes.isEmpty { Text("Все още няма отговори.").foregroundStyle(.secondary) }
                        ForEach(votes) { review in
                            if let profile = store.profiles.first(where: { $0.id == review.authorID }) {
                                Button { author = profile } label: {
                                    HStack(spacing: 12) {
                                        ProfileAvatar(profile: profile)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(profile.display_name).font(.headline).foregroundStyle(.primary)
                                            Text(review.updatedAt.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.teal)
                                    }.frame(minHeight: 44).padding(.vertical, 4)
                                }.buttonStyle(.plain)
                            } else {
                                Label("Потребител · профилът не е наличен", systemImage: "person.crop.circle").foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden).background(Theme.background)
            .listStyle(.insetGrouped)
            .navigationTitle(feature.title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
            .sheet(item: $author) { PublicProfileView(userID: $0.id) }
        }.tint(Theme.teal)
    }
}

struct ReviewPhotoButton: View {
    let review: Review
    let index: Int
    let width: CGFloat
    let height: CGFloat
    @State private var showing = false
    var body: some View {
        if review.photos.indices.contains(index), let image = UIImage(data: review.photos[index]) {
            Button { showing = true } label: {
                Image(uiImage: image).resizable().scaledToFill().frame(width: width, height: height)
                    .clipped().clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.border))
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.caption.bold()).padding(8).background(.ultraThinMaterial, in: Circle()).padding(8)
                    }
            }.buttonStyle(.plain).accessibilityLabel("Отвори снимка \(index + 1)")
                .navigationDestination(isPresented: $showing) { ReviewPhotoViewer(review: review, initialIndex: index) }
        }
    }
}

private struct ReviewPhotoViewer: View {
    let review: Review
    let initialIndex: Int
    @State private var author: UserProfile?
    @EnvironmentObject private var store: AppStore
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("ОТ ПОСЕТИТЕЛИТЕ", systemImage: "photo.on.rectangle.angled")
                            .font(.caption.weight(.bold)).tracking(1.1).foregroundStyle(Theme.teal)
                        Text("Мястото през техните очи").font(.title2.bold())
                        Text("\(review.photos.count) снимки към това ревю").font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.vertical, 4)
                    ForEach(Array(review.photos.enumerated()), id: \.offset) { index, data in
                        if let image = UIImage(data: data) {
                            VStack(alignment: .leading, spacing: 14) {
                                Image(uiImage: image).resizable().scaledToFit()
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(alignment: .topTrailing) {
                                        Text("\(index + 1) / \(review.photos.count)").font(.caption.weight(.semibold))
                                            .padding(.horizontal, 10).padding(.vertical, 7)
                                            .background(.regularMaterial, in: Capsule()).padding(10)
                                    }
                                    .accessibilityLabel("Снимка \(index + 1)")
                                if let profile = store.profiles.first(where: { $0.id == review.authorID }) {
                                    Button { author = profile } label: {
                                        HStack(spacing: 12) {
                                            ProfileAvatar(profile: profile)
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(profile.display_name).font(.headline).foregroundStyle(.primary)
                                                Text("Качено от · Виж профила").font(.caption).foregroundStyle(Theme.teal)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right").foregroundStyle(Theme.teal)
                                        }
                                    }.buttonStyle(.plain)
                                } else {
                                    Label("Потребител · профилът не е наличен", systemImage: "person.crop.circle").foregroundStyle(.secondary)
                                }
                                Text("Ревю от \(review.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(14)
                            .appCard()
                            .id(index)
                        }
                    }
                }.padding(20)
            }
            .background(Theme.background)
            .task { await Task.yield(); proxy.scrollTo(initialIndex, anchor: .top) }
        }
        .navigationTitle("Снимки").navigationBarTitleDisplayMode(.inline)
        .sheet(item: $author) { PublicProfileView(userID: $0.id) }
        .tint(Theme.teal)
    }
}
