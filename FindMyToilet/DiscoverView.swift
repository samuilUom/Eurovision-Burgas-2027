import SwiftUI
import MapKit

struct DiscoverView: View {
    var onClose: (() -> Void)? = nil
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var location: LocationService
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var query = ""
    @State private var mapMode = true
    @State private var selected: Toilet?
    @State private var showAdd = false
    @State private var nearestRequest: NearestRouteRequest?
    @State private var position: MapCameraPosition = .region(Self.burgas)
    private static let burgas = MKCoordinateRegion(center: .init(latitude: 42.505, longitude: 27.474),
                                                   span: .init(latitudeDelta: 0.055, longitudeDelta: 0.045))
    private func results(at date: Date) -> [Toilet] {
        store.toilets.filter { $0.matchesDiscovery(query: query, at: date) }.sorted {
            if let a = $0.distance(from: location.location), let b = $1.distance(from: location.location), a != b { return a < b }
            return $0.name.localizedCompare($1.name) == .orderedAscending
        }
    }
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if geometry.size.height < 600 || dynamicTypeSize.isAccessibilitySize {
                    ScrollView {
                        discoveryContent(resultHeight: max(240, geometry.size.height * 0.55))
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .refreshable { await store.refresh() }
                } else {
                    discoveryContent(resultHeight: nil)
                }
            }
            .background(Theme.background)
            .navigationTitle("Тоалетни")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 12) {
                        if let onClose {
                            Button(action: onClose) { Image(systemName: "chevron.left") }
                                .accessibilityLabel("Назад към събитието")
                        }
                        Button { Task { await store.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                            .accessibilityLabel("Обнови данните").disabled(!store.configured || store.busy)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Label("Добави", systemImage: "plus") }.disabled(!store.canSave)
                }
            }
            .sheet(item: $selected) { ToiletDetailView(toilet: $0) }
            .sheet(isPresented: $showAdd) { ToiletEditor(existing: nil) }
            .sheet(item: $nearestRequest) { request in
                RouteView(destinations: request.destinations, nearest: true)
            }
            .onChange(of: location.location) { _, newLocation in
                guard let newLocation else { return }
                withAnimation { position = .region(.init(center: newLocation.coordinate, span: .init(latitudeDelta: 0.025, longitudeDelta: 0.025))) }
            }
        }
    }
    private func discoveryContent(resultHeight: CGFloat?) -> some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Наблизо, когато ти трябва.").font(.title2.bold())
                        Label("Бургас", systemImage: "location.fill")
                            .font(.caption.weight(.semibold)).foregroundStyle(Theme.teal)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Theme.softTeal, in: Capsule())
                    }
                    Spacer(minLength: 0)
                }
                if !store.configured && !store.starting { DemoNotice() }
                if let status = store.syncStatus { Text(status).font(.caption).foregroundStyle(.secondary) }
                HStack {
                    Image(systemName: "magnifyingglass").font(.body.weight(.medium)).foregroundStyle(Theme.teal)
                    TextField("Място или район", text: $query).submitLabel(.search)
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                .frame(width: 44, height: 44)
                        }.accessibilityLabel("Изчисти търсенето")
                    }
                }
                .padding(.leading, 14).padding(.trailing, query.isEmpty ? 14 : 2)
                .frame(minHeight: 48).appCard(cornerRadius: 16)
                Label("Отворени или отварят до 1 час", systemImage: "clock.badge.checkmark")
                    .font(.caption.weight(.medium)).foregroundStyle(Theme.teal)
                Text("Без график? Показваме мястото с обозначени неизвестни часове.")
                    .font(.caption2).foregroundStyle(.secondary)
                Picker("Изглед", selection: $mapMode) {
                    Text("Карта").tag(true)
                    Text("Списък").tag(false)
                }.pickerStyle(.segmented)
            }.padding(.horizontal)

            if let message = location.message {
                VStack(alignment: .leading, spacing: 6) {
                    Text(message).font(.caption)
                    if location.denied {
                        Button("Отвори Настройки") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }.font(.caption.bold())
                    }
                }.padding(.horizontal).frame(maxWidth: .infinity, alignment: .leading)
            }
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let places = results(at: context.date)
                VStack(spacing: 8) {
                    HStack {
                        Label("\(places.count) места", systemImage: "mappin.and.ellipse")
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Spacer()
                        Button { location.request() } label: {
                            Label(location.isLocating ? "Търсене…" : "Около мен", systemImage: "location")
                                .frame(minHeight: 44).contentShape(Rectangle())
                        }.font(.subheadline.weight(.semibold)).disabled(location.isLocating)
                    }.padding(.horizontal)
                    Button {
                        nearestRequest = NearestRouteRequest(destinations: places)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "figure.walk")
                            Text("До най-близката тоалетна")
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right").font(.subheadline.weight(.semibold))
                        }.frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppPrimaryButtonStyle()).disabled(places.isEmpty).padding(.horizontal)
                    if store.starting || (store.busy && !store.catalogueLoaded) {
                        ProgressView("Зареждане на местата…").padding(8)
                    } else if !store.catalogueLoaded {
                        VStack(spacing: 8) {
                            Text("Не успяхме да заредим местата.").font(.subheadline)
                            Button("Опитай отново") { Task { await store.refresh() } }.disabled(store.busy)
                        }.padding(8)
                    } else if places.isEmpty {
                        VStack(spacing: 8) {
                            Text(store.toilets.isEmpty ? "Още няма добавени тоалетни" : "Няма отворени или отварящи скоро места").font(.headline)
                            if store.toilets.isEmpty {
                                if store.canSave {
                                    Button("Добави първата тоалетна") { showAdd = true }
                                } else {
                                    Text("Отворете „Профил“ и влезте, за да добавите първото място.")
                                        .font(.caption).multilineTextAlignment(.center)
                                }
                            } else {
                                if !query.isEmpty { Button("Изчисти търсенето") { query = "" } }
                            }
                        }.padding(8)
                    }
                    if mapMode {
                        Map(position: $position) {
                            if location.location != nil { UserAnnotation() }
                            ForEach(places) { toilet in
                                Annotation(toilet.name, coordinate: toilet.coordinate) {
                                    Button { selected = toilet } label: {
                                        Image(systemName: "toilet.fill")
                                            .font(.headline).foregroundStyle(.white)
                                            .frame(width: 44, height: 44).background(Theme.teal, in: Circle())
                                            .overlay(Circle().stroke(.white, lineWidth: 3))
                                            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                                    }.accessibilityLabel("\(toilet.name), подробности")
                                }
                            }
                        }
                        .mapStyle(.standard(pointsOfInterest: .excludingAll))
                        .frame(height: resultHeight)
                        .frame(minHeight: 180, maxHeight: .infinity)
                        .mapControls { MapCompass(); MapScaleView() }
                        .overlay(alignment: .topTrailing) {
                            Button { withAnimation { position = .region(Self.burgas) } } label: {
                                Label("Бургас", systemImage: "map").font(.caption.bold()).padding(.horizontal, 12).frame(minHeight: 44)
                            }.background(.regularMaterial, in: Capsule()).padding(12)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.border, lineWidth: 1))
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    } else {
                        if resultHeight == nil {
                            ScrollView { resultList(places) }
                                .refreshable { await store.refresh() }
                        } else {
                            resultList(places)
                        }
                    }
                }
            }
        }
    }
    private func resultList(_ places: [Toilet]) -> some View {
        LazyVStack(spacing: 12) {
            if location.location == nil {
                Text("По име • разрешете позицията за подредба по разстояние")
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(places) { toilet in
                Button { selected = toilet } label: { ToiletCard(toilet: toilet) }.buttonStyle(.plain)
            }
        }.padding(.horizontal).padding(.bottom)
    }

}

struct FavoritesView: View {
    var body: some View {
        NavigationStack { FavoritesContentView() }
    }
}

struct FavoritesContentView: View {
    @EnvironmentObject private var store: AppStore
    @State private var category: EventCategory?
    @State private var shopFilter: ShopFilter = .all
    @State private var healthcareFilter: HealthcareFilter = .hospitals
    @State private var selectedToilet: Toilet?
    @State private var selectedPlace: CityPlace?
    private var categories: [EventCategory] { category.map { [$0] } ?? EventCategory.navigationCategories }
    private var accent: Color { category?.ink ?? EventTheme.ink }
    private func places(in section: EventCategory) -> [SavedCityPlace] {
        store.displayedCityFavorites.filter {
            $0.category.navigationGroup == section
                && (category != .shopping || shopFilter.matches($0.place))
                && (category?.isHealthcare != true || healthcareFilter.matches($0.place))
        }
    }
    private var visibleCount: Int {
        if let category, category == .shopping || category.isHealthcare || category.isFuel { return places(in: category).count }
        return category.map { store.favoriteCount(in: $0) } ?? store.totalFavoriteCount
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Твоят Бургас").font(.title.bold())
                        Text("Любимите ти места, винаги подръка.").font(.subheadline).foregroundStyle(.secondary)
                        Text("\(store.totalFavoriteCount) запазени места")
                            .font(.caption.bold()).foregroundStyle(EventTheme.ink)
                            .padding(.horizontal, 11).padding(.vertical, 7)
                            .background(EventTheme.ink.opacity(0.10), in: Capsule())
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "heart.fill").font(.system(size: 29, weight: .medium)).foregroundStyle(EventTheme.ink)
                        .frame(width: 66, height: 76).background(EventTheme.ink.opacity(0.09), in: RoundedRectangle(cornerRadius: 24))
                        .rotationEffect(.degrees(8)).accessibilityHidden(true)
                }.padding(20).appCard(cornerRadius: 26).padding(.horizontal, 16)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryChip(category: nil, selected: category == nil, count: store.totalFavoriteCount) { category = nil }
                        ForEach(EventCategory.navigationCategories) { value in
                            CategoryChip(category: value, selected: category == value, count: value.isHealthcare ? store.favoriteCount(in: .hospitals) + store.favoriteCount(in: .pharmacies) : store.favoriteCount(in: value)) { category = value }
                        }
                    }.padding(.horizontal, 16)
                }
                if category == .shopping {
                    ScrollView(.horizontal, showsIndicators: false) {
                        ShopFilterControl(selection: $shopFilter).padding(.horizontal, 16)
                    }
                }
                if category?.isHealthcare == true {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HealthcareFilterControl(selection: healthcareFilter) { healthcareFilter = $0 }.padding(.horizontal, 16)
                    }
                }
                if store.profile == nil && store.configured {
                    Label("Влез от „Профил“, за да запазваш любими места.", systemImage: "person.crop.circle")
                        .font(.subheadline).foregroundStyle(.secondary).padding(.horizontal, 16)
                }
                if store.cityFavoritesBusy {
                    ProgressView("Синхронизиране на любимите…").font(.caption).padding(.horizontal, 16)
                }
                if let message = store.cityFavoritesStatus {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(message, systemImage: "iphone").font(.caption).foregroundStyle(.secondary)
                        Button("Опитай синхронизация") { Task { await store.refreshCityFavorites() } }
                            .font(.caption.bold()).frame(minHeight: 44).disabled(store.cityFavoritesBusy || store.busy)
                    }.padding(14).appCard(cornerRadius: 18).padding(.horizontal, 16)
                }
                if visibleCount == 0 { emptyCollection }
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(categories) { segment in
                        let saved = places(in: segment)
                        let count = segment == .toilets ? store.favoriteToilets.count : saved.count
                        if count > 0 {
                            HStack(spacing: 10) {
                                Image(systemName: segment.symbol).foregroundStyle(segment.ink).accessibilityHidden(true)
                                Text(segment.navigationGroupTitle).font(.headline)
                                Spacer()
                                Text("\(count)").font(.caption.bold()).foregroundStyle(segment.ink)
                                    .padding(.horizontal, 9).padding(.vertical, 5)
                                    .background(segment.ink.opacity(0.08), in: Capsule())
                            }.padding(.top, 4).padding(.horizontal, 4)
                            if segment == .toilets {
                                ForEach(store.favoriteToilets) { toilet in
                                    Button { selectedToilet = toilet } label: { ToiletCard(toilet: toilet) }.buttonStyle(.plain)
                                        .contextMenu {
                                            Button(role: .destructive) { Task { await store.toggleFavorite(toilet.id) } } label: {
                                                Label("Премахни от любими", systemImage: "heart.slash")
                                            }.disabled(!store.canSave)
                                        }
                                }
                            } else {
                                ForEach(saved) { value in
                                    HStack(spacing: 0) {
                                        Button { selectedPlace = value.place } label: { CityPlaceRow(place: value.place) }
                                            .buttonStyle(.plain)
                                        Button { Task { await store.toggleCityFavorite(value.place) } } label: {
                                            Image(systemName: "heart.fill").font(.headline).foregroundStyle(segment.ink)
                                                .frame(width: 48, height: 48)
                                        }.accessibilityLabel("Премахни \(value.name) от любими")
                                            .disabled(!store.canSaveCityFavorite).padding(.trailing, 6)
                                    }.appCard(cornerRadius: 22)
                                }
                            }
                        }
                    }
                }.padding(.horizontal, 16)
                if category == .shopping && shopFilter == .nonstop {
                    Text("Филтърът използва означенията в имената. Провери работното време преди посещение.")
                        .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 20)
                }
            }.padding(.vertical, 16)
        }
        .background(Theme.background).navigationTitle("Любими").navigationBarTitleDisplayMode(.inline)
        .tint(accent)
        .refreshable { await store.refresh(); await store.refreshCityFavorites() }
        .sheet(item: $selectedToilet) { ToiletDetailView(toilet: $0).tint(Theme.teal) }
        .sheet(item: $selectedPlace) { CityPlaceDetailView(place: $0) }
        .storeError()
    }
    private var emptyCollection: some View {
        VStack(spacing: 14) {
            Image(systemName: category?.symbol ?? "heart")
                .font(.system(size: 30, weight: .medium)).foregroundStyle(accent)
                .frame(width: 80, height: 80).background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 26))
                .accessibilityHidden(true)
            Text(category == .shopping && shopFilter == .nonstop ? "Няма запазени нонстопи" : "Място за любимите ти места")
                .font(.title3.bold()).multilineTextAlignment(.center)
            Text("Отвори място от картата и натисни „Запази“. Ще го намериш тук, подредено по категория.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(28).appCard(cornerRadius: 26).padding(.horizontal, 16)
    }
}
