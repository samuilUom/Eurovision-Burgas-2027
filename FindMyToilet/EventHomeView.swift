import SwiftUI
import MapKit

// Color surfaces adapt to appearance; filled actions keep enough contrast for white labels.
enum EventTheme {
    static let accent = Color(red: 0.43, green: 0.24, blue: 0.79)
    static let background = Color(red: 0.045, green: 0.035, blue: 0.11)
    static let surface = Color(red: 0.10, green: 0.085, blue: 0.19)
    static let pink = Color(red: 1, green: 0.39, blue: 0.69)
    static let violet = Color(red: 0.67, green: 0.55, blue: 1)
    static let blue = Color(red: 0.37, green: 0.73, blue: 1)
    static let mint = Color(red: 0.37, green: 0.9, blue: 0.75)
    static let muted = Color(red: 0.72, green: 0.70, blue: 0.81)
    static let ink = adaptive(0x6E3CCA, dark: 0xBAA3FF)
    static func adaptive(_ light: UInt32, dark: UInt32) -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 255) / 255,
                           green: CGFloat((hex >> 8) & 255) / 255,
                           blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
        #else
        return Color(red: Double((light >> 16) & 255) / 255,
                     green: Double((light >> 8) & 255) / 255, blue: Double(light & 255) / 255)
        #endif
    }
}

enum EventCategory: String, Codable, CaseIterable, Identifiable {
    case toilets, restaurants, atms, convenience, shopping, hospitals, pharmacies, fuel, charging, transport
    // Keep the legacy raw value readable for existing local/cloud favorites.
    static let allCases: [EventCategory] = [.toilets, .restaurants, .atms, .shopping, .hospitals, .pharmacies, .fuel, .charging, .transport]
    // Navigation grouping only: stored categories and saved-place identities stay unchanged.
    static var navigationCategories: [EventCategory] { allCases.filter { $0 != .pharmacies } }
    var navigationGroup: EventCategory { isHealthcare ? .hospitals : section }
    var navigationGroupTitle: String { isHealthcare ? "Здраве" : title }
    var navigationGroupSubtitle: String { isHealthcare ? "Болници и аптеки" : subtitle }
    var section: EventCategory { self == .convenience ? .shopping : self }
    var id: String { rawValue }
    var title: String {
        switch self {
        case .toilets: return "Тоалетни"
        case .restaurants: return "Хапване"
        case .atms: return "Банкомати"
        case .convenience, .shopping: return "Супермаркети и магазини"
        case .hospitals: return "Болници"
        case .pharmacies: return "Аптеки"
        case .fuel: return "Бензиностанции"
        case .charging: return "Зарядни станции"
        case .transport: return "Транспорт"
        }
    }
    var subtitle: String {
        switch self {
        case .toilets: return "Удобствата наблизо"
        case .restaurants: return "Вкусна пауза в града"
        case .atms: return "В брой, на една крачка"
        case .convenience, .shopping: return "Всичко за деня и нощта"
        case .hospitals: return "Медицинска помощ наблизо"
        case .pharmacies: return "Денонощни и с работно време"
        case .fuel: return "Гориво по пътя ти"
        case .charging: return "Енергия за електромобила"
        case .transport: return "Следващата ти спирка"
        }
    }
    var symbol: String {
        switch self {
        case .toilets: return "toilet.fill"
        case .restaurants: return "fork.knife"
        case .atms: return "banknote.fill"
        case .convenience, .shopping: return "bag.fill"
        case .hospitals: return "cross.case.fill"
        case .pharmacies: return "pills.fill"
        case .fuel: return "fuelpump.fill"
        case .charging: return "bolt.car.fill"
        case .transport: return "tram.fill"
        }
    }
    var color: Color {
        switch self {
        case .toilets: return Color(red: 0.04, green: 0.48, blue: 0.43)
        case .restaurants: return Color(red: 0.70, green: 0.27, blue: 0.06)
        case .atms: return Color(red: 0.10, green: 0.40, blue: 0.72)
        case .convenience, .shopping: return Color(red: 0.70, green: 0.16, blue: 0.39)
        case .hospitals: return Color(red: 0.72, green: 0.16, blue: 0.25)
        case .pharmacies: return Color(red: 0.08, green: 0.43, blue: 0.32)
        case .fuel: return Color(red: 0.67, green: 0.32, blue: 0.04)
        case .charging: return Color(red: 0.12, green: 0.42, blue: 0.58)
        case .transport: return Color(red: 0.36, green: 0.28, blue: 0.75)
        }
    }
    var ink: Color {
        switch self {
        case .toilets: return EventTheme.adaptive(0x097A6E, dark: 0x68D9C5)
        case .restaurants: return EventTheme.adaptive(0xB3450F, dark: 0xFFAF77)
        case .atms: return EventTheme.adaptive(0x1966B8, dark: 0x87BFFF)
        case .convenience, .shopping: return EventTheme.adaptive(0xB32964, dark: 0xFFA1C4)
        case .hospitals: return EventTheme.adaptive(0xB82940, dark: 0xFF9DAA)
        case .pharmacies: return EventTheme.adaptive(0x146E52, dark: 0x75DDB5)
        case .fuel: return EventTheme.adaptive(0xAB520A, dark: 0xFFBC78)
        case .charging: return EventTheme.adaptive(0x1F6B94, dark: 0x86D6FF)
        case .transport: return EventTheme.adaptive(0x5C47BF, dark: 0xB8AAFF)
        }
    }
    var navigationTitle: String {
        switch self {
        case .toilets: return "До най-близката тоалетна"
        case .restaurants: return "До най-близкото заведение"
        case .atms: return "До най-близкия банкомат"
        case .convenience, .shopping: return "До най-близкия магазин"
        case .hospitals: return "До най-близката болница"
        case .pharmacies: return "До най-близката отворена аптека"
        case .fuel: return "До най-близката бензиностанция"
        case .charging: return "До най-близката зарядна станция"
        case .transport: return "До най-близката спирка"
        }
    }
    var detailNote: String {
        switch self {
        case .fuel: return "Провери актуалните цени и наличните горива на място или на сайта на оператора."
        case .charging: return "Провери конектора, мощността, цената и достъпа при оператора. Свободните зарядни точки не се показват в реално време."
        case .hospitals: return "При спешност се обади на 112. Графикът на кабинетите не е график за спешен прием. Потвърди подходящото отделение и вход с болницата."
        case .pharmacies: return "Провери графика и се обади преди посещение. Възможни са празнични промени; наличността на лекарства не се показва в реално време."
        case .atms: return "Провери таксата и условията на екрана на банкомата, преди да потвърдиш теглене."
        case .restaurants: return "Менюто, цените и резервациите са на сайта на заведението."
        case .shopping, .convenience: return "Провери работното време на магазина, преди да тръгнеш."
        case .transport: return "Пешеходен маршрут до спирката или гарата. За разписания и билети отвори портала на Бургасбус от категория „Транспорт“."
        case .toilets: return "Информация от общността."
        }
    }
}

enum ShopFilter: String, CaseIterable, Identifiable {
    case all, nonstop
    var id: String { rawValue }
    var title: String { self == .all ? "Всички магазини" : "Нонстоп" }
    var symbol: String { self == .all ? "bag" : "moon.stars.fill" }
    func matches(_ place: CityPlace) -> Bool {
        if self == .all { return true }
        if let hours = place.hours { return OpeningSchedule.isValid(hours) && OpeningSchedule.isAllDay(hours) }
        return place.isNonstop ?? Self.hasNonstopLabel(place.name)
    }
    // MapKit on the supported SDK does not expose structured hours. Never infer 24/7 from store type.
    static func hasNonstopLabel(_ name: String) -> Bool {
        let value = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        return value.range(of: #"(?<![\p{L}\p{N}])(non[\s-]*stop|нон[\s-]*стоп|24\s*[/xх×]\s*7|24\s*(hours?|hrs?|часа|ч\.?))(?=$|[^\p{L}\p{N}])|денонощ[\p{L}]*"#,
                           options: .regularExpression) != nil
    }
}

extension EventCategory {
    var isHealthcare: Bool { self == .hospitals || self == .pharmacies }
    var isFuel: Bool { self == .fuel || self == .charging }
    var supportsNonstop: Bool { self == .shopping || self == .pharmacies || isFuel }
}

enum PharmacyScheduleKind: Equatable {
    case nonstop, scheduled, unknown
    init(place: CityPlace) {
        if let hours = place.hours {
            self = OpeningSchedule.isValid(hours) ? (OpeningSchedule.isAllDay(hours) ? .nonstop : .scheduled) : .unknown
        } else if let nonstop = place.isNonstop {
            self = nonstop ? .nonstop : .scheduled
        } else { self = .unknown }
    }
    var title: String {
        switch self {
        case .nonstop: return "Денонощна · 24/7"
        case .scheduled: return "С работно време · не е денонощна"
        case .unknown: return "Непотвърден график"
        }
    }
    var symbol: String {
        switch self {
        case .nonstop: return "moon.stars.fill"
        case .scheduled: return "clock"
        case .unknown: return "questionmark.circle"
        }
    }
}

enum PharmacyFilter: String, CaseIterable, Identifiable {
    case all, nonstop, scheduled
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "Всички"
        case .nonstop: return "Денонощни"
        case .scheduled: return "С график"
        }
    }
    var symbol: String {
        switch self {
        case .all: return "pills"
        case .nonstop: return "moon.stars.fill"
        case .scheduled: return "clock"
        }
    }
    func matches(_ place: CityPlace) -> Bool {
        self == .all || PharmacyScheduleKind(place: place) == (self == .nonstop ? .nonstop : .scheduled)
    }
}

enum HealthcareFilter: String, CaseIterable, Identifiable {
    case hospitals, pharmacies
    var id: String { rawValue }
    var category: EventCategory { self == .hospitals ? .hospitals : .pharmacies }
    var title: String { category.title }
    var symbol: String { category.symbol }
    init(category: EventCategory) { self = category == .pharmacies ? .pharmacies : .hospitals }
    func matches(_ place: CityPlace) -> Bool { place.category == category }
}

struct HealthcareFilterControl: View {
    let selection: HealthcareFilter
    let select: (HealthcareFilter) -> Void
    var body: some View {
        HStack(spacing: 8) {
            ForEach(HealthcareFilter.allCases) { value in
                Button { select(value) } label: {
                    Label(value.title, systemImage: value.symbol)
                        .font(.caption.bold()).padding(.horizontal, 12).frame(minHeight: 44)
                        .foregroundStyle(selection == value ? .white : EventCategory.hospitals.ink)
                        .background(selection == value ? EventCategory.hospitals.color : EventCategory.hospitals.ink.opacity(0.08), in: Capsule())
                }.buttonStyle(.plain).accessibilityAddTraits(selection == value ? .isSelected : [])
            }
        }
    }
}

struct PharmacyHoursBadge: View {
    let place: CityPlace
    private var kind: PharmacyScheduleKind { PharmacyScheduleKind(place: place) }
    var body: some View {
        Label(kind.title, systemImage: kind.symbol).font(.caption.weight(.semibold))
            .foregroundStyle(kind == .unknown ? Color.secondary : EventCategory.pharmacies.ink)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(EventCategory.pharmacies.ink.opacity(0.08), in: Capsule())
    }
}

private struct CityRouteRequest: Identifiable {
    let id = UUID()
    let destinations: [Toilet]
    let symbol: String
    let category: EventCategory
}

struct CategoryChip: View {
    let category: EventCategory?
    let selected: Bool
    var count: Int? = nil
    let action: () -> Void
    private var color: Color { category?.navigationGroup.color ?? EventTheme.accent }
    private var ink: Color { category?.navigationGroup.ink ?? EventTheme.ink }
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: category?.navigationGroup.symbol ?? "square.grid.2x2.fill")
                    .font(.subheadline.weight(.semibold)).frame(width: 22).accessibilityHidden(true)
                Text(category?.navigationGroupTitle ?? "Всички")
                if let count {
                    Text("\(count)").font(.caption.bold()).monospacedDigit()
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(selected ? Color.white.opacity(0.18) : ink.opacity(0.08), in: Capsule())
                }
            }.font(.subheadline.weight(.semibold)).padding(.horizontal, 14).frame(minHeight: 46)
                .foregroundStyle(selected ? .white : ink)
                .background(selected ? color : Theme.surface, in: Capsule())
                .overlay(Capsule().stroke(selected ? Color.clear : ink.opacity(0.14), lineWidth: 1))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct ShopFilterControl: View {
    @Binding var selection: ShopFilter
    var body: some View {
        HStack(spacing: 8) {
            ForEach(ShopFilter.allCases) { value in
                Button { selection = value } label: {
                    Label(value.title, systemImage: value.symbol).font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 13).frame(minHeight: 44)
                        .foregroundStyle(selection == value ? .white : EventCategory.shopping.ink)
                        .background(selection == value ? EventCategory.shopping.color : EventCategory.shopping.ink.opacity(0.08), in: Capsule())
                }.buttonStyle(.plain).accessibilityAddTraits(selection == value ? .isSelected : [])
            }
        }
    }
}

struct CategoryButtonStyle: ButtonStyle {
    let category: EventCategory
    var prominent = true
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.bold()).padding(.horizontal, 16).padding(.vertical, 14)
            .frame(minHeight: 50)
            .foregroundStyle(prominent ? .white : category.ink)
            .background(prominent ? category.color : category.ink.opacity(0.10), in: RoundedRectangle(cornerRadius: 17))
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.45)
    }
}

struct CityPlaceRow: View {
    let place: CityPlace
    private var category: EventCategory { place.category.section }
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: category.symbol).font(.title3.weight(.semibold))
                .foregroundStyle(category.ink).frame(width: 50, height: 54)
                .background(category.ink.opacity(0.10), in: RoundedRectangle(cornerRadius: 17))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(place.name).font(.headline).foregroundStyle(.primary)
                if !place.address.isEmpty { Text(place.address).font(.subheadline).foregroundStyle(.secondary).lineLimit(2) }
                if category == .transport {
                    Label("Спирка / гара", systemImage: "tram.fill").font(.caption).foregroundStyle(category.ink)
                } else {
                    if category == .pharmacies {
                        PharmacyHoursBadge(place: place)
                    }
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        AvailabilityBadge(availability: place.availability(at: context.date))
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary).accessibilityHidden(true)
        }.padding(16).contentShape(Rectangle())
    }
}

struct EventHomeView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var location: LocationService
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var search = CityPlacesSearch()
    @StateObject private var transit = BurgasTransitStore()
    @State private var showTransit = false
    @State private var selectedBus: BurgasLiveBus?
    @State private var transitRefreshID = 0
    @Binding var category: EventCategory
    var isActive = true
    @State private var shopFilter: ShopFilter = .all
    @State private var query = ""
    @State private var availabilityDate = Date()
    @State private var mapMode = true
    @State private var viewport = CityMapViewport()
    @State private var searchRegion = CitySearchArea.burgas
    @State private var refreshID = 0
    @State private var forceSearch = false
    @State private var awaitingLocation = false
    @State private var selectedToilet: Toilet?
    @State private var selectedPlace: CityPlace?
    @State private var route: CityRouteRequest?
    @State private var showAdd = false
    @State private var showLoginHint = false

    private var toilets: [Toilet] {
        store.toilets.filter { $0.matchesDiscovery(query: query, at: availabilityDate) }.sorted {
            if let a = $0.distance(from: location.location), let b = $1.distance(from: location.location), a != b { return a < b }
            return $0.name.localizedCompare($1.name) == .orderedAscending
        }
    }
    private var searchIdentity: String { "\(isActive)|\(category.rawValue)|\(shopFilter.rawValue)|\(query)|\(refreshID)" }
    private var visiblePlaces: [CityPlace] {
        CityPlaceCatalogue.visible(transit.stops.map(\.place) + store.sharedPlaces.map(\.place) + HealthcareDirectory.places + search.places,
            category: category, query: query, region: searchRegion, shopFilter: shopFilter, at: availabilityDate)
    }
    private var routePlaces: [CityPlace] {
        visiblePlaces.filter { category != .pharmacies || $0.availability(at: availabilityDate) == .open }
    }
    private var pins: [CityMapPin] {
        if category == .toilets { return toilets.map(CityMapPin.init) }
        let buses = category == .transport ? transit.vehicles.filter { CitySearchArea.contains($0.coordinate, in: viewport.region) } : []
        return visiblePlaces.map(CityMapPin.init) + buses.map(CityMapPin.init)
    }
    private var count: Int { category == .toilets ? toilets.count : visiblePlaces.count }
    private var loading: Bool { category == .toilets ? store.busy && !store.catalogueLoaded : search.loading }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if geometry.size.height < 620 || dynamicTypeSize.isAccessibilitySize {
                    ScrollView { content(mapHeight: max(280, geometry.size.height * 0.60)) }
                        .scrollDismissesKeyboard(.interactively)
                } else { content(mapHeight: nil) }
            }
            .background(Theme.background.overlay(category.ink.opacity(0.025)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Eurovision").font(.headline)
                        Text("Burgas 2027").font(.caption).foregroundStyle(EventTheme.accent)
                    }.accessibilityElement(children: .combine)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button { Task { await refresh() } } label: { Label("Обнови местата", systemImage: "arrow.clockwise") }
                            .disabled(store.busy || search.loading)
                        NavigationLink("Програма", destination: EventProgrammeView())
                        NavigationLink("Преди шоуто", destination: EventPreparationView())
                    } label: { Image(systemName: "music.note.list") }
                        .accessibilityLabel("Програма и подготовка")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if store.profile == nil { showLoginHint = true } else { showAdd = true }
                    } label: { Image(systemName: "plus") }
                        .accessibilityLabel(category == .toilets ? "Добави тоалетна" : "Добави място в \(category.title)")
                        .disabled(store.busy)
                }
            }
            .sheet(item: $selectedToilet) { ToiletDetailView(toilet: $0).tint(Theme.teal) }
            .sheet(item: $selectedPlace) { CityPlaceDetailView(place: $0) }
            .sheet(isPresented: $showAdd) {
                if category == .toilets { ToiletEditor(existing: nil).tint(Theme.teal) }
                else {
                    CityPlaceEditor(category: category, region: viewport.region) { saved in
                        let region = MKCoordinateRegion(center: saved.coordinate, span: .init(latitudeDelta: 0.012, longitudeDelta: 0.012))
                        viewport.recenter(region); searchRegion = region
                        category = saved.category; query = ""; shopFilter = .all; refreshID += 1
                    }
                }
            }
            .alert("Добави място", isPresented: $showLoginHint) {
                Button("Разбрах", role: .cancel) {}
            } message: { Text("Влез или се регистрирай от раздел „Профил“, след което натисни + в избраната категория.") }
            .sheet(item: $route) { RouteView(destinations: $0.destinations, nearest: true, destinationSymbol: $0.symbol, category: $0.category).tint($0.category.ink) }
            .sheet(isPresented: $showTransit) { TransitStatusView(transit: transit) }
            .alert(selectedBus?.title ?? "Автобус", isPresented: Binding(get: { selectedBus != nil }, set: { if !$0 { selectedBus = nil } })) {
                Button("Готово", role: .cancel) { selectedBus = nil }
            } message: {
                if let bus = selectedBus {
                    Text("\(bus.label)\nGPS: \(Date(timeIntervalSince1970: bus.observed_at).formatted(date: .omitted, time: .standard))\nБургасбус · реална позиция на превозното средство")
                }
            }
            .task(id: "\(isActive && category == .transport && scenePhase == .active)|\(store.transitScope)|\(transitRefreshID)") {
                guard isActive, category == .transport, scenePhase == .active else { return }
                await transit.run(scope: store.transitScope, stops: { try await store.loadTransitStops() }, live: { try await store.loadTransitLive() })
            }
            .task(id: "availability|\(isActive)|\(scenePhase == .active)") {
                guard isActive, scenePhase == .active else { return }
                availabilityDate = .now
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(30)) } catch { return }
                    availabilityDate = .now
                }
            }
            .task(id: searchIdentity) {
                if (category == .restaurants || category.isHealthcare || category.isFuel) && refreshID == 0 && query.isEmpty && !viewport.needsSearch {
                    searchRegion = CitySearchArea.restaurantBurgas
                }
                guard isActive, category != .toilets else { search.cancel(clear: true); return }
                search.prepare(category: category, query: query, region: searchRegion, shopFilter: shopFilter)
                do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                let force = forceSearch
                forceSearch = false
                await search.search(category: category, query: query, region: searchRegion, shopFilter: shopFilter, force: force)
            }
            .onChange(of: category) { previous, current in
                // Healthcare filters replace pins without resetting the camera, search area or text.
                if previous.navigationGroup == current.navigationGroup { return }
                search.cancel(); query = ""
                searchRegion = current.isHealthcare || current.isFuel || current == .restaurants ? CitySearchArea.restaurantBurgas : viewport.region
                viewport.markSearched()
            }
            .onChange(of: shopFilter) { _, _ in search.cancel() }
            .onChange(of: location.location) { _, fix in
                guard awaitingLocation, let fix else { return }
                awaitingLocation = false
                let region = MKCoordinateRegion(center: fix.coordinate, span: .init(latitudeDelta: 0.025, longitudeDelta: 0.03))
                viewport.recenter(region)
                searchRegion = region
                if category != .toilets { refreshID += 1 }
            }
        }.tint(category.ink)
    }
    private func content(mapHeight: CGFloat?) -> some View {
        VStack(spacing: 10) {
            controls
            if let message = location.message {
                HStack {
                    Text(message).font(.caption)
                    if location.denied {
                        Button("Настройки") { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } }.font(.caption.bold())
                    }
                }.padding(.horizontal, 16)
            }
            if mapMode { cityMap.frame(height: mapHeight).frame(minHeight: 220, maxHeight: .infinity) }
            else if mapHeight == nil { ScrollView { resultList }.refreshable { await refresh() } }
            else { resultList }
            footer
        }.padding(.top, 6).padding(.bottom, 8)
    }
    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(category.ink)
                TextField("Търси в „\(category.title)“", text: $query).submitLabel(.search).autocorrectionDisabled()
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).frame(width: 44, height: 44) }.accessibilityLabel("Изчисти търсенето")
                }
            }.padding(.leading, 14).padding(.trailing, query.isEmpty ? 14 : 0).frame(minHeight: 46).appCard(cornerRadius: 18).padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(EventCategory.navigationCategories) { value in
                        CategoryChip(category: value, selected: category.navigationGroup == value) {
                            guard category.navigationGroup != value else { return }
                            search.cancel()
                            category = value; query = ""; searchRegion = category.isHealthcare || category.isFuel || category == .restaurants ? CitySearchArea.restaurantBurgas : viewport.region; viewport.markSearched()
                        }
                    }
                }.padding(.horizontal, 16)
            }
            // Every category reserves the same control-row height, keeping map geometry stable.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if category == .transport {
                        Button { showTransit = true } label: {
                            Label(transit.vehicles.isEmpty ? "Бургасбус · спирки и автобуси" : "\(transit.vehicles.count) автобуса на живо", systemImage: "bus.fill")
                                .font(.caption.weight(.semibold)).padding(.horizontal, 13).frame(minHeight: 44)
                                .background(category.ink.opacity(0.08), in: Capsule())
                        }.buttonStyle(.plain)
                    } else if category.isHealthcare {
                        HealthcareFilterControl(selection: HealthcareFilter(category: category)) { value in
                            category = value.category
                        }
                    } else {
                        Label("Отворени или отварят до 1 час", systemImage: "clock.badge.checkmark")
                            .font(.caption.weight(.medium)).foregroundStyle(category.ink)
                        if category == .shopping {
                            Button { shopFilter = shopFilter == .all ? .nonstop : .all } label: {
                                Label("Нонстоп", systemImage: "moon.stars.fill")
                                    .font(.caption.bold()).padding(.horizontal, 12).frame(minHeight: 44)
                                    .foregroundStyle(shopFilter == .nonstop ? .white : category.ink)
                                    .background(shopFilter == .nonstop ? category.color : category.ink.opacity(0.08), in: Capsule())
                            }.buttonStyle(.plain).accessibilityAddTraits(shopFilter == .nonstop ? .isSelected : [])
                        }
                    }
                }.frame(minHeight: 44).padding(.horizontal, 16)
            }
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(category.title).font(.title3.bold()).lineLimit(2)
                    Text(category.subtitle).font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 4) {
                    displayModeButton(true, symbol: "map.fill", title: "Карта")
                    displayModeButton(false, symbol: "list.bullet", title: "Списък")
                }.padding(4).background(Theme.surface, in: Capsule())
            }.frame(minHeight: 74).padding(.horizontal, 16)

        }
    }
    private func displayModeButton(_ mode: Bool, symbol: String, title: String) -> some View {
        Button { mapMode = mode } label: {
            Image(systemName: symbol).font(.subheadline.bold()).frame(width: 44, height: 40)
                .foregroundStyle(mapMode == mode ? .white : category.ink)
                .background(mapMode == mode ? category.color : Color.clear, in: Capsule())
        }.buttonStyle(.plain).accessibilityLabel(title).accessibilityAddTraits(mapMode == mode ? .isSelected : [])
    }
    private var cityMap: some View {
        CityMapView(pins: pins, viewport: viewport, showUserLocation: location.location != nil,
                    onRegionChange: { region, moved in viewport.record(region, userMoved: moved) },
                    onSelect: { id in
                        if category == .toilets { selectedToilet = toilets.first { CityMapPin(toilet: $0).id == id } }
                        else if let bus = transit.vehicles.first(where: { CityMapPin(bus: $0).id == id }) { selectedBus = bus }
                        else { selectedPlace = visiblePlaces.first { CityMapPin(place: $0).id == id } }
                    })
            .overlay(alignment: .topTrailing) {
                VStack(spacing: 10) {
                    Button { awaitingLocation = true; location.request() } label: { Image(systemName: "location.fill").frame(width: 44, height: 44) }
                        .accessibilityLabel("Около мен").disabled(location.isLocating)
                    Button {
                        viewport.recenter(CitySearchArea.burgas)
                        searchRegion = CitySearchArea.burgas
                        if category != .toilets { refreshID += 1 }
                    } label: { Image(systemName: "building.2").frame(width: 44, height: 44) }.accessibilityLabel("Върни картата в Бургас")
                }.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)).padding(12)
            }
            .overlay(alignment: .bottom) {
                if category != .toilets && viewport.needsSearch {
                    Button { searchRegion = viewport.region; viewport.markSearched(); refreshID += 1 } label: {
                        Label("Търси в тази област", systemImage: "arrow.clockwise").font(.subheadline.bold()).padding(13)
                    }.background(.regularMaterial, in: Capsule()).padding(12)
                }
            }.clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(category.ink.opacity(0.17), lineWidth: 1))
            .padding(.horizontal, 12)
    }
    private var resultList: some View {
        LazyVStack(spacing: 12) {
            if category == .toilets {
                ForEach(toilets) { toilet in Button { selectedToilet = toilet } label: { ToiletCard(toilet: toilet) }.buttonStyle(.plain) }
            } else {
                ForEach(visiblePlaces) { place in
                    Button { selectedPlace = place } label: {
                        CityPlaceRow(place: place).appCard()
                    }.buttonStyle(.plain)
                }
            }
        }.padding(.horizontal, 16)
    }
    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if category != .toilets, let status = store.sharedPlacesStatus {
                Text(status).font(.caption2).foregroundStyle(.secondary).lineLimit(3)
            }
            Group {
            if loading { ProgressView(category == .restaurants ? "Търсим заведения в районите…" : "Зареждане на местата…").font(.caption) }
            else if category == .toilets && !store.catalogueLoaded {
                Button("Местата не са заредени · Опитай отново") { Task { await store.refresh() } }.font(.caption)
            } else if let message = category == .toilets ? store.syncStatus : search.message {
                Button { Task { await refresh() } } label: { Label(message, systemImage: "arrow.clockwise") }.font(.caption)
            } else if count == 0 {
                Text(category == .transport ? "Няма спирки в тази област." : (category.isHealthcare ? "Няма места за този избор в областта." : "Няма отворени или отварящи скоро места за това търсене."))
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("\(count) места · \(category == .toilets ? (store.configured ? "От общността" : "Демо данни") : (category == .transport && !transit.stops.isEmpty ? "Бургасбус, Apple Maps и общността" : (category.isHealthcare ? "Каталог, Apple Maps и общността" : "Apple Maps и общността")))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            }.frame(maxWidth: .infinity, minHeight: 36, alignment: .leading).lineLimit(2)
            if category.isHealthcare {
                Link("Каталог и Apple Maps · координати © OpenStreetMap", destination: URL(string: "https://www.openstreetmap.org/copyright")!)
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if category == .restaurants {
                Text("Заведения от Apple Maps и общността • списъкът може да е непълен.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Text(category == .transport ? transit.status : (category == .pharmacies ? "Най-близка аптека: само отворени по известен график. При неизвестни часове се обади преди посещение." : category == .hospitals ? "Потвърди отделението и входа. При спешност: 112." : "Местата без график също се виждат, с обозначени неизвестни часове."))
                .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .topLeading)
            Button {
                let destinations = category == .toilets ? toilets : routePlaces.map(\.walkingDestination)
                guard !destinations.isEmpty else { return }
                route = CityRouteRequest(destinations: destinations, symbol: category.symbol, category: category)
            } label: {
                Label(category.navigationTitle, systemImage: "figure.walk")
                    .font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 13)
                    .foregroundStyle(.white).background(category.color, in: RoundedRectangle(cornerRadius: 14))
            }.buttonStyle(.plain).disabled(category == .toilets ? toilets.isEmpty : routePlaces.isEmpty)
                .opacity((category == .toilets ? toilets.isEmpty : routePlaces.isEmpty) ? 0.45 : 1)
        }.padding(.horizontal, 16)
    }
    private func refresh() async {
        if category == .toilets { await store.refresh() } else { forceSearch = true; refreshID += 1; if category == .transport { transitRefreshID += 1 }; await store.refreshSharedPlaces() }
    }
}

struct CityPlaceDetailView: View {
    let place: CityPlace
    var body: some View {
        if place.category == .restaurants { RestaurantDetailView(originalPlace: place) }
        else { BasicCityPlaceDetailView(place: place) }
    }
}

private struct BasicCityPlaceDetailView: View {
    private let originalPlace: CityPlace
    init(place: CityPlace) { originalPlace = place }
    private var record: CommunityPlace? {
        guard originalPlace.source == .community else { return nil }
        return store.sharedPlaces.first { $0.id == originalPlace.sourceID }
    }
    private var place: CityPlace { record?.place ?? originalPlace }
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var showRoute = false
    @State private var showEdit = false
    @State private var confirmDelete = false
    private var category: EventCategory { place.category.section }
    private var website: URL? {
        guard let value = SavedCityPlace.safeWebsite(place.item.url?.absoluteString) else { return nil }
        return URL(string: value)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Map(initialPosition: .region(.init(center: place.coordinate, span: .init(latitudeDelta: 0.008, longitudeDelta: 0.008)))) {
                        Annotation(place.name, coordinate: place.coordinate) {
                            VStack(spacing: 2) {
                                if place.hasKnown24HourSchedule { Text("24/7").font(.caption2.bold()).padding(4).background(.regularMaterial, in: Capsule()) }
                                Image(systemName: category.symbol).font(.title3).foregroundStyle(.white).padding(12).background(category.color, in: Circle())
                            }.accessibilityLabel(place.name + (place.hasKnown24HourSchedule ? ", денонощно" : ""))
                        }
                    }.mapStyle(.standard(pointsOfInterest: .excludingAll))
                        .mapControls { MapCompass(); MapScaleView() }
                        .frame(height: 245).clipShape(RoundedRectangle(cornerRadius: 26))
                        .overlay(alignment: .bottomLeading) {
                            Label("Разгледай района", systemImage: "hand.draw").font(.caption.weight(.semibold))
                                .padding(10).background(.regularMaterial, in: Capsule()).padding(12).allowsHitTesting(false)
                        }
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: category.symbol).font(.title2.weight(.semibold)).foregroundStyle(.white)
                                .frame(width: 58, height: 58).background(category.color.gradient, in: RoundedRectangle(cornerRadius: 19))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 7) {
                                Text(category.title.uppercased()).font(.caption.bold()).tracking(1).foregroundStyle(category.ink)
                                Text(place.name).font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if !place.address.isEmpty {
                            Label(place.address, systemImage: "mappin.and.ellipse").font(.subheadline).foregroundStyle(.secondary)
                        }
                        if category != .transport {
                            if category == .pharmacies { PharmacyHoursBadge(place: place) }
                            TimelineView(.periodic(from: .now, by: 30)) { context in
                                AvailabilityBadge(availability: place.availability(at: context.date))
                            }
                            if place.walkingDestination.hours != nil {
                                DisclosureGroup("Седмичен график") {
                                    Text(place.walkingDestination.hoursText).font(.subheadline).monospacedDigit()
                                        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                                }.font(.subheadline.weight(.medium))
                            }
                        }
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 10) { routeButton; saveButton }
                            VStack(spacing: 10) { routeButton; saveButton }
                        }
                    }.padding(20).appCard(cornerRadius: 24)
                    if store.profile == nil {
                        Label("Влез от „Профил“, за да запазиш това място.", systemImage: "person.crop.circle")
                            .font(.caption).foregroundStyle(.secondary)
                    } else if let status = store.cityFavoritesStatus {
                        Text(status).font(.caption).foregroundStyle(.secondary)
                    }
                    if store.cityFavoritesBusy { ProgressView("Синхронизиране…").font(.caption) }
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Преди да тръгнеш", systemImage: category == .atms ? "creditcard" : "info.circle")
                            .font(.headline).foregroundStyle(category.ink)
                        Text(category.detailNote).font(.subheadline).foregroundStyle(.secondary)
                        if !place.notes.isEmpty { Text(place.notes).font(.subheadline) }
                        if category.isHealthcare, let phone = place.phoneURL {
                            Link(destination: phone) {
                                Label("Обади се", systemImage: "phone.fill").frame(maxWidth: .infinity)
                            }.buttonStyle(CategoryButtonStyle(category: category, prominent: false))
                        }
                        if category == .hospitals {
                            Link(destination: URL(string: "tel:112")!) {
                                Label("Спешна помощ · 112", systemImage: "phone.fill").frame(maxWidth: .infinity)
                            }.buttonStyle(CategoryButtonStyle(category: category, prominent: false))
                        }
                        if let website {
                            Link(destination: website) {
                                HStack {
                                    Label("Уебсайт", systemImage: "globe")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                }.frame(maxWidth: .infinity)
                            }.buttonStyle(CategoryButtonStyle(category: category, prominent: false))
                        }
                    }.padding(18).appCard(cornerRadius: 22)
                    if place.source == .healthcareDirectory {
                        Link("Координати © OpenStreetMap contributors", destination: URL(string: "https://www.openstreetmap.org/copyright")!)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text("\(place.source.title) · провери часовете и услугите преди посещение.")
                        .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
                }.padding(16)
            }.background(Theme.background.overlay(category.ink.opacity(0.025)))
                .navigationTitle(category.title).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Готово") { dismiss() } }
                    if store.isAdmin, record != nil {
                        ToolbarItem(placement: .primaryAction) {
                            Menu {
                                Button("Редактирай", systemImage: "pencil") { showEdit = true }
                                Button("Изтрий мястото", systemImage: "trash", role: .destructive) { confirmDelete = true }
                            } label: { Image(systemName: "ellipsis.circle") }.disabled(!store.canSave)
                        }
                    }
                }
                .sheet(isPresented: $showEdit) {
                    if let record { CityPlaceEditor(category: record.category, existing: record) }
                }
                .confirmationDialog("Изтриване на мястото?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Изтрий", role: .destructive) {
                        if let record { Task { if await store.deleteCityPlace(record) { dismiss() } } }
                    }
                }
                .sheet(isPresented: $showRoute) {
                    RouteView(destinations: [place.walkingDestination], nearest: false,
                              destinationSymbol: category.symbol, category: category).tint(category.ink)
                }
        }.tint(category.ink).storeError()
    }
    private var routeButton: some View {
        Button { showRoute = true } label: {
            Label("Маршрут", systemImage: "figure.walk").frame(maxWidth: .infinity)
        }.buttonStyle(CategoryButtonStyle(category: category))
    }
    private var saveButton: some View {
        Button { Task { await store.toggleCityFavorite(place) } } label: {
            Label(store.isCityFavorite(place) ? "Запазено" : "Запази",
                  systemImage: store.isCityFavorite(place) ? "heart.fill" : "heart").frame(maxWidth: .infinity)
        }.buttonStyle(CategoryButtonStyle(category: category, prominent: false)).disabled(!store.canSaveCityFavorite)
    }
}

private extension View {
    func eventCard() -> some View {
        background(EventTheme.surface, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.07)).allowsHitTesting(false))
    }
    func eventPage(_ title: String) -> some View {
        background(EventTheme.background.ignoresSafeArea())
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(EventTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .tint(EventTheme.pink)
    }
}

private struct EventProgrammeView: View {
    @State private var inTheCity = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("ОТ ПЪРВАТА ДО ПОСЛЕДНАТА ПЕСЕН", systemImage: "music.note")
                        .font(.caption2.bold()).foregroundStyle(EventTheme.pink)
                    Text("Повече от\nедна вечер.").font(.largeTitle.bold()).foregroundStyle(.white)
                    Text("Шоуто, срещите и моментите между тях.").font(.subheadline).foregroundStyle(EventTheme.muted)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(24).eventCard()
                HStack(spacing: 10) {
                    programmeFilter("На сцената", selected: !inTheCity) { inTheCity = false }
                    programmeFilter("В града", selected: inTheCity) { inTheCity = true }
                }
                EventPreviewNotice(text: "Програмата за този гид още не е добавена. Тук ще показваме само потвърдени дати, часове и места.")
                if inTheCity {
                    EventInfoRow(symbol: "person.3.fill", title: "Фен зони", text: "Места за срещи, музика и споделено гледане.", color: EventTheme.blue)
                    EventInfoRow(symbol: "sparkles", title: "Около събитието", text: "Събития за фенове и още поводи да опознаеш града.", color: EventTheme.violet)
                } else {
                    EventInfoRow(symbol: "music.mic", title: "Вечерите на Eurovision", text: "Програма на шоутата с място, начален час и подробности.", color: EventTheme.pink)
                    EventInfoRow(symbol: "ticket", title: "Преди да влезеш", text: "Информация за входове, достъп и подготовка за събитието.", color: EventTheme.violet)
                }
            }.padding(20)
        }.eventPage("Програма")
    }
    private func programmeFilter(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 14)
                .foregroundStyle(selected ? EventTheme.background : .white)
                .background(selected ? EventTheme.pink : EventTheme.surface, in: Capsule())
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct EventPreviewNotice: View {
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Първи поглед · предстои", systemImage: "sparkles").font(.subheadline.bold()).foregroundStyle(EventTheme.violet)
            Text(text).font(.subheadline).foregroundStyle(EventTheme.muted).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
            .background(EventTheme.violet.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct EventInfoRow: View {
    let symbol: String
    let title: String
    let text: String
    let color: Color
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).font(.title3).foregroundStyle(color)
                .frame(width: 44, height: 44).background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.headline).foregroundStyle(.white)
                Text(text).font(.subheadline).foregroundStyle(EventTheme.muted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }.padding(18).eventCard()
    }
}

private struct EventPreparationView: View {
    // This personal checklist stays on the device; it is not an event schedule or ticket wallet.
    @AppStorage("eventGuide.preparation.ticket") private var ticket = false
    @AppStorage("eventGuide.preparation.battery") private var battery = false
    @AppStorage("eventGuide.preparation.return") private var returnTrip = false
    private var completed: Int { [ticket, battery, returnTrip].filter { $0 }.count }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Остава само\nда се забавляваш.").font(.largeTitle.bold()).foregroundStyle(.white)
                    Text("\(completed) от 3 готови").font(.headline).foregroundStyle(EventTheme.mint)
                    ProgressView(value: Double(completed), total: 3).tint(EventTheme.mint)
                        .accessibilityLabel("Подготовка").accessibilityValue("\(completed) от 3")
                }.padding(24).eventCard()
                checklistItem("Билетът е подръка", text: "Провери билета и условията за вход.", symbol: "ticket", checked: $ticket)
                checklistItem("Телефонът е зареден", text: "Батерия за музика, снимки и връщане.", symbol: "battery.100", checked: $battery)
                checklistItem("Имам план за връщане", text: "Провери как ще стигнеш до мястото за нощувка.", symbol: "arrow.turn.up.left", checked: $returnTrip)
                Text("Списъкът се запазва на този телефон.").font(.caption).foregroundStyle(EventTheme.muted)
            }.padding(20)
        }.eventPage("Преди шоуто")
    }
    private func checklistItem(_ title: String, text: String, symbol: String, checked: Binding<Bool>) -> some View {
        Button { checked.wrappedValue.toggle() } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: symbol).font(.title3).foregroundStyle(EventTheme.violet).frame(width: 28)
                VStack(alignment: .leading, spacing: 7) {
                    Text(title).font(.headline).foregroundStyle(.white)
                    Text(text).font(.subheadline).foregroundStyle(EventTheme.muted)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: checked.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.title2).foregroundStyle(checked.wrappedValue ? EventTheme.mint : EventTheme.muted)
            }.multilineTextAlignment(.leading).padding(20).eventCard()
        }.buttonStyle(.plain)
            .accessibilityElement(children: .ignore).accessibilityLabel(title)
            .accessibilityValue(checked.wrappedValue ? "Готово" : "Не е отбелязано")
            .accessibilityHint("Докосни, за да промениш състоянието.")
    }
}

struct EventLandingView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let openMap: (EventCategory) -> Void
    let openFavorites: () -> Void
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack(spacing: 10) {
                        Image(systemName: "waveform").foregroundStyle(EventTheme.pink)
                        Text("EUROVISION").font(.subheadline.bold()).tracking(2)
                        Spacer()
                        Text("BURGAS · 2027").font(.caption.bold()).foregroundStyle(EventTheme.violet)
                    }.foregroundStyle(.white).padding(.top, 8)
                    hero
                    if store.starting {
                        HStack(spacing: 10) {
                            ProgressView().tint(EventTheme.violet)
                            Text("Обновяваме местата. Разгледай гида, докато зареждат.")
                                .font(.caption).foregroundStyle(EventTheme.muted)
                        }.accessibilityElement(children: .combine)
                    }
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Градът е част от шоуто.").font(.title3.bold()).foregroundStyle(.white)
                            Text("Избери какво търсиш.").font(.subheadline).foregroundStyle(EventTheme.muted)
                        }
                        Spacer()
                        Image(systemName: "location.magnifyingglass").font(.title2).foregroundStyle(EventTheme.violet).accessibilityHidden(true)
                    }
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(EventCategory.navigationCategories) { value in
                            Button { openMap(value) } label: {
                                VStack(alignment: .leading, spacing: 13) {
                                    HStack {
                                        Image(systemName: value.symbol).font(.title3).foregroundStyle(.white)
                                            .frame(width: 43, height: 43).background(value.color, in: RoundedRectangle(cornerRadius: 14))
                                        Spacer(minLength: 6)
                                        Image(systemName: "arrow.up.right").font(.caption.bold()).foregroundStyle(EventTheme.muted)
                                    }.accessibilityHidden(true)
                                    Text(value.navigationGroupTitle).font(.headline).foregroundStyle(.white)
                                    Text(value.navigationGroupSubtitle).font(.caption).foregroundStyle(EventTheme.muted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(17).eventCard()
                            }.buttonStyle(.plain).accessibilityHint("Отваря категорията на картата")
                        }
                        Button(action: openFavorites) {
                            VStack(alignment: .leading, spacing: 13) {
                                HStack {
                                    Image(systemName: "heart.fill").font(.title3).foregroundStyle(EventTheme.pink)
                                        .frame(width: 43, height: 43).background(EventTheme.pink.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                                    Spacer(minLength: 6)
                                    Image(systemName: "arrow.up.right").font(.caption.bold()).foregroundStyle(EventTheme.muted)
                                }.accessibilityHidden(true)
                                Text("Твоите места").font(.headline).foregroundStyle(.white)
                                Text("\(store.totalFavoriteCount) любими места").font(.caption).foregroundStyle(EventTheme.muted)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(17).eventCard()
                        }.buttonStyle(.plain)
                    }
                    VStack(spacing: 12) {
                        NavigationLink { EventProgrammeView() } label: {
                            eventLink("Програмата", detail: "Дати и събития · очаквайте скоро", symbol: "music.mic", color: EventTheme.pink)
                        }
                        NavigationLink { EventPreparationView() } label: {
                            eventLink("Готов ли си за вечерта?", detail: "Твоят списък преди шоуто", symbol: "checklist", color: EventTheme.blue)
                        }
                    }.buttonStyle(.plain)
                    Text("Независим фен гид · програмата и местата на събитието предстои да бъдат потвърдени.")
                        .font(.caption).foregroundStyle(EventTheme.muted).padding(.horizontal, 4)
                }.padding(20)
            }.background(EventTheme.background.ignoresSafeArea())
                .toolbar(.hidden, for: .navigationBar).tint(EventTheme.pink)
                .refreshable { await store.refresh() }
        }.environment(\.colorScheme, .dark)
    }
    private var hero: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                Label("МУЗИКА · ГРАД · ХОРА", systemImage: "sparkles")
                    .font(.caption2.bold()).tracking(1).foregroundStyle(EventTheme.pink)
                Spacer(minLength: 8)
                Image("EventLaunchLogo").resizable().scaledToFit().frame(width: 66, height: 66).accessibilityHidden(true)
            }
            Text("Един град.\nХиляди гласове.")
                .font(.system(.largeTitle, design: .rounded, weight: .bold)).foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text("Твоят Eurovision Burgas 2027 — от първата разходка до последната песен.")
                .font(.subheadline).foregroundStyle(Color.white.opacity(0.78)).fixedSize(horizontal: false, vertical: true)
            Button { openMap(.toilets) } label: {
                HStack {
                    Label("Разгледай Бургас", systemImage: "map.fill")
                    Spacer(minLength: 12)
                    Image(systemName: "arrow.right")
                }.font(.headline).padding(16).frame(maxWidth: .infinity)
                    .foregroundStyle(EventTheme.background).background(EventTheme.pink, in: RoundedRectangle(cornerRadius: 17))
            }.buttonStyle(.plain)
        }.padding(24).background {
            GeometryReader { proxy in
                Image("EventLaunchBackdrop").resizable().scaledToFill().frame(width: proxy.size.width, height: proxy.size.height).clipped()
                    .overlay(Color.black.opacity(0.14))
            }
        }.clipShape(RoundedRectangle(cornerRadius: 30))
            .overlay(RoundedRectangle(cornerRadius: 30).stroke(EventTheme.violet.opacity(0.23), lineWidth: 1))
    }
    private func eventLink(_ title: String, detail: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title2).foregroundStyle(color).frame(width: 34).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline).foregroundStyle(.white)
                Text(detail).font(.caption).foregroundStyle(EventTheme.muted)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(EventTheme.muted).accessibilityHidden(true)
        }.padding(20).eventCard()
    }
}
