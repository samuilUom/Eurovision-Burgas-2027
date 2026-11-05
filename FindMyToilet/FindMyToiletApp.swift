import SwiftUI

@main
struct FindMyToiletApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var location = LocationService()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(location)
                .tint(Theme.teal)
        }
    }
}

enum Theme {
    static let teal = Color(red: 0.04, green: 0.48, blue: 0.43)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let border = Color.primary.opacity(0.07)
    static let softTeal = teal.opacity(0.09)
}

private struct AppCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    func body(content: Content) -> some View {
        content
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Theme.border, lineWidth: 1).allowsHitTesting(false))
    }
}

extension View {
    func appCard(cornerRadius: CGFloat = 22) -> some View {
        modifier(AppCardModifier(cornerRadius: cornerRadius))
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.teal
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .frame(minHeight: 48)
            .foregroundStyle(.white)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    var color: Color = Theme.teal
    var ink: Color? = nil
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(minHeight: 44)
            .foregroundStyle(configuration.role == .destructive ? Color.red : (ink ?? color))
            .background(configuration.role == .destructive ? Color.red.opacity(0.08) : (ink ?? color).opacity(0.09),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.65 : 1) : 0.45)
    }
}

private enum AppTab: Int, CaseIterable, Identifiable {
    case event, map, favorites, profile, more
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .event: return "Събитие"
        case .map: return "Карта"
        case .favorites: return "Любими"
        case .profile: return "Профил"
        case .more: return "Още"
        }
    }
    var symbol: String {
        switch self {
        case .event: return "sparkles"
        case .map: return "map"
        case .favorites: return "heart"
        case .profile: return "person.crop.circle"
        case .more: return "square.grid.2x2"
        }
    }
    var selectedSymbol: String { self == .event ? symbol : symbol + ".fill" }
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: AppTab = .event
    @State private var showingLaunch = true
    @State private var mapOpened = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedCategory: EventCategory = .toilets
    var body: some View {
        ZStack {
            mainTabs.accessibilityHidden(showingLaunch).allowsHitTesting(!showingLaunch)
            if showingLaunch { AppLoadingView().transition(.opacity).zIndex(1) }
        }
        .preferredColorScheme(selectedTab == .event || showingLaunch ? .dark : nil)
        .task { await store.start() }
        .task {
            // Present the local event page promptly; slow network requests continue separately.
            do { try await Task.sleep(for: .milliseconds(800)) } catch { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { showingLaunch = false }
        }
    }
    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            EventLandingView(openMap: { value in selectedCategory = value; selectedTab = .map },
                             openFavorites: { selectedTab = .favorites })
                .toolbar(.hidden, for: .tabBar).tag(AppTab.event).tabItem { Label("Събитие", systemImage: "sparkles") }
            Group {
                if mapOpened || selectedTab == .map {
                    EventHomeView(category: $selectedCategory, isActive: selectedTab == .map)
                } else { Color.clear }
            }
                .toolbar(.hidden, for: .tabBar).tag(AppTab.map).tabItem { Label("Карта", systemImage: "map") }
            FavoritesView().toolbar(.hidden, for: .tabBar).tag(AppTab.favorites).tabItem { Label("Любими", systemImage: "heart") }
            ProfileView().toolbar(.hidden, for: .tabBar).tag(AppTab.profile).tabItem { Label("Профил", systemImage: "person.crop.circle") }
            MoreView().toolbar(.hidden, for: .tabBar).tag(AppTab.more).tabItem { Label("Още", systemImage: "ellipsis.circle") }
        }
        .tint(selectedTab == .map ? selectedCategory.ink : EventTheme.ink)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            EventTabBar(selection: $selectedTab, category: selectedCategory, favoritesCount: store.totalFavoriteCount)
                .environment(\.colorScheme, selectedTab == .event ? .dark : colorScheme)
                .background(selectedTab == .event ? EventTheme.background : Theme.background)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let message = store.errorMessage {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(message).font(.caption).lineLimit(4)
                    Spacer(minLength: 0)
                    Button { store.errorMessage = nil } label: {
                        Image(systemName: "xmark").font(.caption.bold()).frame(width: 44, height: 44)
                    }
                        .accessibilityLabel("Скрий съобщението")
                }
                .padding(.leading, 16).padding(.trailing, 4).padding(.vertical, 8)
                .appCard(cornerRadius: 16).padding(.horizontal, 12).padding(.vertical, 6)
            }
        }
        .task(id: "\(scenePhase)-\(selectedTab)") {
            guard scenePhase == .active, selectedTab != .profile else { return }
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                if selectedTab != .profile { await store.refresh(quiet: true) }
            }
        }
        .onChange(of: selectedTab) { _, tab in
            if tab == .map { mapOpened = true }
            if tab != .profile { Task { await store.refresh(quiet: true) } }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active && selectedTab != .profile { Task { await store.refresh(quiet: true) } } }
    }
}

private struct EventTabBar: View {
    @Binding var selection: AppTab
    let category: EventCategory
    let favoritesCount: Int
    private var accent: Color { selection == .map ? category.ink : selection == .event ? EventTheme.pink : EventTheme.ink }
    var body: some View {
        HStack(alignment: .top, spacing: 2) {
            ForEach(AppTab.allCases) { tab in
                Button { selection = tab } label: {
                    VStack(spacing: 4) {
                        Image(systemName: selection == tab ? tab.selectedSymbol : tab.symbol)
                            .font(.system(size: 21, weight: .semibold)).frame(width: 44, height: 32)
                            .background(selection == tab ? accent.opacity(0.13) : Color.clear, in: Capsule())
                            .accessibilityHidden(true)
                        Text(tab.title).font(.caption.weight(selection == tab ? .bold : .medium))
                            .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.center)
                    }.foregroundStyle(selection == tab ? accent : Color.secondary)
                        .frame(maxWidth: .infinity, minHeight: 56).padding(.vertical, 4).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel(tab.title)
                    .accessibilityValue(tab == .favorites ? "\(favoritesCount) запазени места" : "")
                    .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }.padding(7).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 27))
            .overlay(RoundedRectangle(cornerRadius: 27).stroke(Theme.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
            .padding(.horizontal, 12).padding(.top, 6).padding(.bottom, 4)
    }
}

struct DemoNotice: View {
    var body: some View {
        Label("Демо • Обектите и условията са примерни", systemImage: "info.circle")
            .font(.caption).foregroundStyle(.secondary)
    }
}

struct StoreError: ViewModifier {
    @EnvironmentObject private var store: AppStore
    func body(content: Content) -> some View {
        content.alert("Неуспешно действие", isPresented: Binding(
            get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("Разбрах", role: .cancel) { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }
}
extension View { func storeError() -> some View { modifier(StoreError()) } }

extension PlaceAvailability {
    var color: Color {
        switch self {
        case .open: return Theme.teal
        case .openingSoon: return EventTheme.adaptive(0x99520A, dark: 0xFFC078)
        case .closed, .unknown: return .secondary
        }
    }
}

struct AvailabilityBadge: View {
    let availability: PlaceAvailability
    var body: some View {
        Label(availability.title, systemImage: availability.symbol)
            .font(.caption.weight(.semibold)).foregroundStyle(availability.color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct StatusLabel: View {
    let toilet: Toilet
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            AvailabilityBadge(availability: toilet.availability(at: context.date))
        }
    }
}

struct ToiletCard: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var location: LocationService
    let toilet: Toilet
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "toilet.fill")
                    .font(.title2.weight(.medium)).foregroundStyle(Theme.teal)
                    .frame(width: 48, height: 48)
                    .background(Theme.softTeal, in: RoundedRectangle(cornerRadius: 15))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(toilet.name).font(.headline).foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(toilet.address).font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary).padding(.top, 6).accessibilityHidden(true)
            }
            if toilet.isDemo {
                Label("Демо • непроверено място", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.orange)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { status; cost }
                VStack(alignment: .leading, spacing: 8) { status; cost }
            }
            if let distance = toilet.distance(from: location.location) {
                Label(distance < 1000 ? "\(Int(distance)) м по права линия" : String(format: "%.1f км по права линия", distance / 1000), systemImage: "location")
                    .font(.caption).foregroundStyle(.secondary)
            }
            amenityBadges
            ratingSummary.foregroundStyle(Theme.teal)
        }
        .padding(16).appCard()
        .contentShape(RoundedRectangle(cornerRadius: 22))
    }
    private var amenityBadges: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 135), alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(toilet.amenities) { amenity in
                Label(amenity == .wheelchair ? "Достъпност" : amenity == .changingTable ? "Повиване" : "Вода",
                      systemImage: amenity.symbol)
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.teal)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Theme.softTeal, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel(amenity.title)
            }
        }
    }
    @ViewBuilder private var ratingSummary: some View {
        if let score = store.rating(for: toilet.id) {
            Label(String(format: "%.1f · %d", score, store.reviews(for: toilet.id).count), systemImage: "star.fill")
                .font(.subheadline.weight(.semibold))
                .accessibilityLabel(String(format: "%.1f от 5, %d ревюта", score, store.reviews(for: toilet.id).count))
        } else { Text("Без оценки").font(.caption).foregroundStyle(.secondary) }
    }
    private var status: some View {
        StatusLabel(toilet: toilet)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Theme.softTeal, in: Capsule())
    }
    private var cost: some View {
        Text(toilet.priceText).font(.caption.weight(.medium)).foregroundStyle(.secondary)
    }
}


private struct AppLoadingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        SharedLaunchScreen(animating: !reduceMotion && scenePhase == .active)
            .ignoresSafeArea()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Eurovision Burgas 2027. Откриваме ритъма на града…")
    }
}

// Use the actual system launch layout after startup too, avoiding two drifting copies.
private struct SharedLaunchScreen: UIViewControllerRepresentable {
    let animating: Bool
    final class Coordinator {
        let orbit = LoadingOrbitView()
        let equalizer = LoadingEqualizerView()
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIStoryboard(name: "LaunchScreenEurovision", bundle: .main).instantiateInitialViewController()!
        controller.loadViewIfNeeded()
        let orbit = context.coordinator.orbit
        orbit.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(orbit)
        NSLayoutConstraint.activate([
            orbit.widthAnchor.constraint(equalToConstant: 268),
            orbit.heightAnchor.constraint(equalToConstant: 268),
            orbit.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
            orbit.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor)
        ])
        let equalizer = context.coordinator.equalizer
        equalizer.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(equalizer)
        NSLayoutConstraint.activate([
            equalizer.widthAnchor.constraint(equalToConstant: 70),
            equalizer.heightAnchor.constraint(equalToConstant: 28),
            equalizer.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
            equalizer.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor, constant: 267)
        ])
        return controller
    }
    func updateUIViewController(_ controller: UIViewController, context: Context) {
        // The static launch glyph and moving glyph share the same top-of-orbit position.
        (controller.view.viewWithTag(110) as? UIImageView)?.image = UIImage(named: animating ? "EventLaunchRing" : "EventLaunchOrbit")
        controller.view.viewWithTag(111)?.isHidden = animating
        context.coordinator.orbit.isHidden = !animating
        context.coordinator.orbit.setAnimating(animating)
        controller.view.viewWithTag(114)?.isHidden = animating
        context.coordinator.equalizer.isHidden = !animating
        context.coordinator.equalizer.setAnimating(animating)
        if let logo = controller.view.viewWithTag(112)?.layer {
            if animating && logo.animation(forKey: "breath") == nil {
                let pulse = CABasicAnimation(keyPath: "transform.scale")
                pulse.fromValue = 1; pulse.toValue = 1.04; pulse.duration = 1.8
                pulse.autoreverses = true; pulse.repeatCount = .infinity
                pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                logo.add(pulse, forKey: "breath")
            } else if !animating { logo.removeAnimation(forKey: "breath") }
        }
    }
    static func dismantleUIViewController(_ controller: UIViewController, coordinator: Coordinator) {
        coordinator.orbit.setAnimating(false)
        coordinator.equalizer.setAnimating(false)
        controller.view.viewWithTag(112)?.layer.removeAnimation(forKey: "breath")
    }
}

// Core Animation interpolates the orbit without rebuilding SwiftUI on every frame.
private final class LoadingOrbitView: UIView {
    private let orbit = CALayer()
    private let badge = CALayer()
    private let glyph = CALayer()

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        layer.addSublayer(orbit)
        orbit.addSublayer(badge)
        badge.addSublayer(glyph)
        badge.backgroundColor = UIColor(red: 0.43, green: 0.24, blue: 0.79, alpha: 1).cgColor
        badge.cornerRadius = 24
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .regular)
        glyph.contents = UIImage(systemName: "music.note", withConfiguration: config)?
            .withTintColor(.white, renderingMode: .alwaysOriginal).cgImage
        glyph.contentsGravity = .resizeAspect
    }
    required init?(coder: NSCoder) { fatalError("Use init()") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        orbit.bounds = bounds
        orbit.position = CGPoint(x: bounds.midX, y: bounds.midY)
        badge.bounds = CGRect(x: 0, y: 0, width: 48, height: 48)
        badge.position = CGPoint(x: bounds.midX, y: bounds.midY - 110)
        glyph.frame = CGRect(x: 12, y: 10, width: 24, height: 28)
        glyph.contentsScale = window?.screen.scale ?? traitCollection.displayScale
        CATransaction.commit()
    }

    func setAnimating(_ enabled: Bool) {
        guard enabled else {
            orbit.removeAllAnimations()
            badge.removeAllAnimations()
            return
        }
        guard orbit.animation(forKey: "orbit") == nil else { return }
        let start = CACurrentMediaTime()
        for (target, turns, key) in [(orbit, 1.0, "orbit"), (badge, -1.0, "upright")] {
            let animation = CABasicAnimation(keyPath: "transform.rotation.z")
            animation.fromValue = 0
            animation.toValue = turns * 2 * Double.pi
            animation.duration = 5
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .linear)
            animation.beginTime = start
            target.add(animation, forKey: key)
        }
    }
}


// Lightweight layer transforms keep the music animation off SwiftUI's view-update path.
private final class LoadingEqualizerView: UIView {
    private let heights: [CGFloat] = [10, 18, 26, 18, 10]
    private var bars: [CALayer] = []
    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        for index in 0..<5 {
            let bar = CALayer()
            bar.backgroundColor = UIColor(index.isMultiple(of: 2) ? EventTheme.pink : EventTheme.violet).cgColor
            bar.cornerRadius = 3
            layer.addSublayer(bar); bars.append(bar)
        }
    }
    required init?(coder: NSCoder) { fatalError("Use init()") }
    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        for (index, bar) in bars.enumerated() {
            bar.bounds = CGRect(x: 0, y: 0, width: 6, height: heights[index])
            bar.position = CGPoint(x: CGFloat(index) * 14 + 6, y: 14)
        }
        CATransaction.commit()
    }
    func setAnimating(_ enabled: Bool) {
        for (index, bar) in bars.enumerated() {
            guard enabled else { bar.removeAllAnimations(); continue }
            guard bar.animation(forKey: "music") == nil else { continue }
            let animation = CABasicAnimation(keyPath: "transform.scale.y")
            animation.fromValue = 1; animation.toValue = index.isMultiple(of: 2) ? 0.45 : 1.35
            animation.duration = 0.65 + Double(index) * 0.13
            animation.autoreverses = true; animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            bar.add(animation, forKey: "music")
        }
    }
}
