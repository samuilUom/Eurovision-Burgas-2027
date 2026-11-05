import SwiftUI

struct MoreView: View {
    @EnvironmentObject private var store: AppStore
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.9.0"
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .center, spacing: 16) {
                        Image("EventLaunchLogo").resizable().scaledToFit()
                            .frame(width: 64, height: 64).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Eurovision Burgas 2027").font(.title2.bold())
                            Text("Независим градски гид · \(version)").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(20).appCard()
                    VStack(alignment: .leading, spacing: 12) {
                        Label(store.configured ? "Свързани с общността" : "Демонстрация", systemImage: store.configured ? "person.2.fill" : "info.circle")
                            .font(.headline).foregroundStyle(EventTheme.ink)
                        Text(store.configured ? "Тоалетните, ревютата и снимките се споделят между потребителите. В другите категории можеш да добавяш места чрез + и да разглеждаш резултати от Apple Maps. „Супермаркети и магазини“ има филтър „Нонстоп“, според подателя или името. Статусът на официалните спирки и живите GPS позиции е в панела „Бургасбус“ на картата." : "Тоалетните са примерни. Свържете общата база от „Профил“, за да добавяте тоалетни и ревюта. Другите категории използват Apple Maps.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        if !store.configured { DemoNotice() }
                    }.padding(18).appCard()
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Поверителност и маршрути", systemImage: "hand.raised.fill")
                            .font(.headline).foregroundStyle(EventTheme.ink)
                        information("Твоите данни", symbol: "person.crop.circle", text: "Публичното име, добавените места, ревютата и снимките са видими за другите. Любимите са лични; сигналите се виждат от автора и администраторите.")
                        Divider()
                        information("Защитен вход", symbol: "lock.shield", text: "Паролата не се пази на телефона. Сесията за вход се съхранява защитено в Keychain.")
                        Divider()
                        information("Местоположение", symbol: "location", text: "Позицията се използва за близки места. Търсенето и видимата област на картата се изпращат към Apple Maps; заявеният маршрут използва и началната Ви позиция. Те не се записват в нашата база.")
                        Divider()
                        information("По пътя", symbol: "figure.walk", text: "Маршрутите остават в приложението и изискват интернет. При придвижване се обновяват автоматично; можете да натиснете и „Обнови“. Няма гласови инструкции.")
                    }.padding(18).appCard()
                    Label(store.isAdmin ? "Сигнали от потребителите" : "Моите сигнали", systemImage: "flag")
                        .font(.headline).padding(.horizontal, 4)
                    if store.data.reports.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark.bubble").font(.title).foregroundStyle(EventTheme.ink)
                            Text("Няма сигнали").font(.headline)
                            Text("При неточна информация можеш да изпратиш сигнал от страницата на мястото.")
                                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }.frame(maxWidth: .infinity).padding(24).appCard()
                    }
                    ForEach(store.data.reports.sorted { $0.createdAt > $1.createdAt }) { report in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(store.toilets.first { $0.id == report.toiletID }?.name ?? report.toiletID).font(.headline)
                            Text(report.category.title).font(.caption.weight(.semibold)).foregroundStyle(EventTheme.ink)
                                .padding(.horizontal, 10).padding(.vertical, 6).background(EventTheme.ink.opacity(0.09), in: Capsule())
                            Text(report.message).font(.subheadline)
                            Text(report.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(18).appCard()
                    }
                }.padding(16)
            }
            .background(Theme.background)
            .refreshable { await store.refresh() }
            .navigationTitle("Още")
        }
    }
    private func information(_ title: String, symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(EventTheme.ink)
                .frame(width: 32, height: 32).background(EventTheme.ink.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
