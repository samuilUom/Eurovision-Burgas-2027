import SwiftUI
import SafariServices

struct TransitStatusView: View {
    @ObservedObject var transit: BurgasTransitStore
    @Environment(\.dismiss) private var dismiss
    @State private var showPortal = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Label("С автобус из Бургас", systemImage: "bus.fill").font(.title2.bold()).foregroundStyle(EventCategory.transport.ink)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(transit.stops.count) официални спирки").font(.headline)
                        Text(transit.status).font(.subheadline).foregroundStyle(.secondary)
                        if transit.loading { ProgressView("Проверка на данните…") }
                        Text("Автобус се показва на картата само при GPS позиция от последните 2 минути. Спирките от Apple Maps и общността са обозначени отделно в подробностите.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(20).appCard()
                    Button { showPortal = true } label: {
                        Label("Отвори портала на Бургасбус", systemImage: "globe").frame(maxWidth: .infinity)
                    }.buttonStyle(CategoryButtonStyle(category: .transport))
                    Text("Маршрути, разписания и информация от превозвача.").font(.caption).foregroundStyle(.secondary)
                    ForEach(transit.vehicles) { bus in
                        VStack(alignment: .leading, spacing: 7) {
                            Label(bus.title, systemImage: "bus.fill").font(.headline)
                            if !bus.label.isEmpty { Text(bus.label).font(.subheadline) }
                            Text("GPS: \(Date(timeIntervalSince1970: bus.observed_at).formatted(date: .omitted, time: .standard))")
                                .font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(18).appCard()
                    }
                }.padding(20)
            }.background(Theme.background).navigationTitle("Бургасбус").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Готово") { dismiss() } } }
                .sheet(isPresented: $showPortal) { BurgasTransportPortal().ignoresSafeArea() }
        }.tint(EventCategory.transport.ink)
    }
}

private struct BurgasTransportPortal: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: URL(string: "https://transport.burgasbus.info/app/planner")!)
    }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
