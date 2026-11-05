import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    @State private var signup = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmationCode = ""
    @State private var serverURL = ""
    @State private var publicKey = ""
    @State private var showEditor = false
    @State private var showPhotoEditor = false
    @State private var editingName = false
    @State private var showConnection = false
    private var cleanName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var body: some View {
        NavigationStack {
            Form {
                if store.starting && !store.configured {
                    Section { ProgressView("Подготовка на профила…") }
                } else if !store.configured || showConnection {
                    connectionSection
                } else if let profile = store.profile {
                    accountSections(profile)
                } else if let confirmationEmail = store.pendingConfirmationEmail {
                    profileWelcome(title: "Още една стъпка", subtitle: "Потвърдете имейла си и открийте повече с Вашия профил.", symbol: "envelope.open.fill")
                    Section("Потвърдете имейла") {
                        Label(confirmationEmail, systemImage: "envelope").font(.subheadline.weight(.medium)).textSelection(.enabled)
                        Text("Въведете кода от имейла, за да завършите регистрацията тук.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        TextField("Код от имейла", text: $confirmationCode)
                            .keyboardType(.numberPad).textContentType(.oneTimeCode)
                            .font(.title2.monospacedDigit()).padding(.vertical, 8)
                        Button("Потвърди и влез") {
                            Task {
                                if await store.confirmRegistration(code: confirmationCode) {
                                    confirmationCode = ""; password = ""
                                }
                            }
                        }.buttonStyle(AppPrimaryButtonStyle(color: EventTheme.accent))
                            .disabled(store.busy || !ConfirmationCode.isValid(confirmationCode.trimmingCharacters(in: .whitespacesAndNewlines)))
                        Button("Изпрати нов код") {
                            confirmationCode = ""
                            Task { await store.resendConfirmation(email: confirmationEmail) }
                        }.disabled(store.busy)
                        if let message = store.authMessage { Text(message).font(.caption) }
                        Button("Назад към вход / промени имейла") {
                            store.cancelConfirmation(); confirmationCode = ""; signup = false
                        }.disabled(store.busy)
                    }
                } else {
                    profileWelcome(title: signup ? "Създайте своя профил" : "Вашите места. Вашият Бургас.",
                                   subtitle: "Запазвайте любими места, добавяйте тоалетни и споделяйте впечатления.",
                                   symbol: "person.crop.circle.badge.checkmark")
                    Section {
                        Picker("Профил", selection: $signup) {
                            Text("Вход").tag(false)
                            Text("Регистрация").tag(true)
                        }.pickerStyle(.segmented).disabled(store.busy)
                        if signup {
                            HStack(spacing: 12) {
                                Image(systemName: "person").foregroundStyle(EventTheme.ink).frame(width: 22).accessibilityHidden(true)
                                TextField("Публично име", text: $name).textContentType(.nickname)
                            }.padding(.vertical, 6)
                        }
                        HStack(spacing: 12) {
                            Image(systemName: "envelope").foregroundStyle(EventTheme.ink).frame(width: 22).accessibilityHidden(true)
                            TextField("Имейл", text: $email).textContentType(.emailAddress).keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                        }.padding(.vertical, 6)
                        HStack(spacing: 12) {
                            Image(systemName: "lock").foregroundStyle(EventTheme.ink).frame(width: 22).accessibilityHidden(true)
                            SecureField("Парола", text: $password).textContentType(signup ? .newPassword : .password)
                        }.padding(.vertical, 6)
                        if signup { Text("Поне 8 символа. Регистрацията създава обикновен потребителски профил.").font(.caption) }
                        Button(signup ? "Създай профил" : "Влез") {
                            Task {
                                if await store.authenticate(name: cleanName, email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password, signup: signup) {
                                    password = ""
                                    signup = false
                                }
                            }
                        }.buttonStyle(AppPrimaryButtonStyle(color: EventTheme.accent))
                            .disabled(store.busy || !email.contains("@") || password.isEmpty || (signup && (password.count < 8 || !(2...50).contains(cleanName.count))))
                        if !signup {
                            Button("Имам непотвърден профил — изпрати код") {
                                Task { await store.resendConfirmation(email: email.trimmingCharacters(in: .whitespacesAndNewlines)) }
                            }.font(.subheadline).padding(.vertical, 5).disabled(store.busy || !email.contains("@"))
                        }
                        if let message = store.authMessage { Text(message).foregroundStyle(EventTheme.ink) }
                    } header: { Text(signup ? "Регистрация" : "Добре дошли отново") }
                    footer: { Text("Тоалетните и ревютата са общи за всички устройства, свързани към същия сървър. При регистрация потвърдете имейла с код в приложението.") }
                    Section {
                        Button { showConnection = true } label: { Label("Настройки на връзката", systemImage: "network") }.disabled(store.busy)
                        Button { Task { await store.refresh() } } label: { Label("Обнови данните", systemImage: "arrow.clockwise") }.disabled(store.busy)
                    }
                }
                if store.busy { ProgressView("Свързване…") }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .tint(EventTheme.ink)
            .navigationTitle("Профил")
            .sheet(isPresented: $showPhotoEditor) {
                ProfilePhotoEditor(current: store.profile?.avatarData)
            }
            .task(id: store.profile?.id) {
                guard store.profile != nil else { return }
                // Wait for login to finish; refresh private collections once, not on a timer.
                while store.busy {
                    do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
                }
                guard !Task.isCancelled else { return }
                await store.refresh(quiet: true)
            }
            .sheet(isPresented: $showEditor) { ToiletEditor(existing: nil) }
            .onChange(of: store.profile?.display_name) { _, value in if let value { name = value } }
            .onAppear { if let profile = store.profile { name = profile.display_name } }
        }
    }
    private func profileWelcome(title: String, subtitle: String, symbol: String) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: symbol).font(.system(size: 28, weight: .medium))
                    .foregroundStyle(EventTheme.ink).frame(width: 58, height: 58)
                    .background(EventTheme.ink.opacity(0.09), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityHidden(true)
                Text(title).font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
        }.listRowBackground(Theme.surface)
    }
    @ViewBuilder private func accountSections(_ profile: UserProfile) -> some View {
        Section {
            VStack(spacing: 14) {
                Button { showPhotoEditor = true } label: {
                    ProfileAvatar(profile: profile, size: 100)
                        .padding(6)
                        .background(EventTheme.ink.opacity(0.09), in: Circle())
                        .overlay(Circle().stroke(EventTheme.ink.opacity(0.18), lineWidth: 1))
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "camera.fill").font(.caption.bold()).foregroundStyle(.white)
                                .padding(9).background(EventTheme.ink, in: Circle())
                        }
                }.buttonStyle(.plain).disabled(!store.canSave)
                    .accessibilityLabel("Промени профилната снимка")
                VStack(spacing: 5) {
                    Text(profile.display_name).font(.title2.bold()).multilineTextAlignment(.center)
                    Text(store.email).font(.subheadline).foregroundStyle(.secondary).textSelection(.enabled)
                        .multilineTextAlignment(.center)
                }
                Label(profile.isAdmin ? "Администратор" : "Изследовател на Бургас",
                      systemImage: profile.isAdmin ? "checkmark.shield.fill" : "location.circle.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(EventTheme.ink)
                    .padding(.horizontal, 12).padding(.vertical, 6).background(EventTheme.ink.opacity(0.1), in: Capsule())
                HStack(alignment: .top, spacing: 8) {
                    profileStat(store.totalFavoriteCount, "Любими", symbol: "heart.fill")
                    profileStat(store.myToilets.count + store.myCityPlaces.count, "Добавени", symbol: "mappin.and.ellipse")
                    profileStat(store.myReviews.count, "Ревюта", symbol: "star.fill")
                }.padding(.top, 8)
            }.frame(maxWidth: .infinity).padding(.vertical, 16)
        }.listRowBackground(Theme.surface)
        Section("Моите места") {
            NavigationLink { FavoritesContentView() } label: {
                collectionLabel("Любими места", symbol: "heart.fill", count: store.totalFavoriteCount)
            }
            NavigationLink { ProfileCollectionView(kind: .added) } label: {
                collectionLabel("Добавени от мен", symbol: "mappin.and.ellipse", count: store.myToilets.count + store.myCityPlaces.count)
            }
            NavigationLink { ProfileCollectionView(kind: .reviews) } label: {
                collectionLabel("Моите ревюта", symbol: "star.bubble.fill", count: store.myReviews.count)
            }
        }
        Section {
            Button { showEditor = true } label: { Label("Добави тоалетна", systemImage: "plus.circle.fill") }
                .buttonStyle(AppPrimaryButtonStyle(color: EventTheme.accent)).disabled(!store.canSave)
        }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
        Section("Редактиране на профила") {
            Button { showPhotoEditor = true } label: { Label("Профилна снимка", systemImage: "person.crop.circle") }
                .disabled(!store.canSave)
            DisclosureGroup("Публично име", isExpanded: $editingName) {
                TextField("Вашето име", text: $name).textContentType(.nickname)
                Button("Запази името") { Task { await store.renameProfile(cleanName) } }
                    .buttonStyle(AppSecondaryButtonStyle(color: EventTheme.accent, ink: EventTheme.ink))
                    .disabled(!store.canSave || !(2...50).contains(cleanName.count) || cleanName == profile.display_name)
            }
            Text("Името и снимката Ви са публични и се показват до Вашите ревюта.")
                .font(.caption).foregroundStyle(.secondary)
        }
        if profile.isAdmin {
            Section {
                Label("Администраторски достъп", systemImage: "checkmark.shield.fill")
                    .font(.headline).foregroundStyle(EventTheme.ink)
                Text("Можете да редактирате всички тоалетни.").font(.subheadline)
                Text("Отворете място → Общ преглед → Администрация.").font(.caption).foregroundStyle(.secondary)
            }
        }
        Section {
            if let status = store.syncStatus { Text(status).font(.caption).foregroundStyle(.secondary) }
            Button { Task { await store.refresh() } } label: { Label("Обнови профила и местата", systemImage: "arrow.clockwise") }.disabled(store.busy)
            Button("Изход", role: .destructive) { Task { await store.logout(); password = "" } }.disabled(store.busy)
        }
    }
    private func profileStat(_ count: Int, _ title: String, symbol: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.caption.weight(.semibold)).foregroundStyle(EventTheme.ink).accessibilityHidden(true)
            Text("\(count)").font(.title2.bold()).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(EventTheme.ink.opacity(0.09), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityElement(children: .combine)
    }
    private func collectionLabel(_ title: String, symbol: String, count: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.body.weight(.medium)).foregroundStyle(EventTheme.ink)
                .frame(width: 40, height: 40).background(EventTheme.ink.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
            Text("\(count)").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).monospacedDigit()
        }.padding(.vertical, 4)
    }
    private var connectionSection: some View {
        Section {
            Text("Свързване към общата база").font(.headline)
            Text("Собственикът на проекта създава Supabase проект и изпълнява приложения setup.sql. След това въведете един и същ Project URL и публичен ключ на тестовите телефони.")
                .font(.subheadline)
            TextField("https://your-project.supabase.co", text: $serverURL).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
            TextField("Publishable / anon key", text: $publicKey).textInputAutocapitalization(.never).autocorrectionDisabled()
            Button("Провери и свържи") {
                Task {
                    let config = BackendConfiguration(url: serverURL.trimmingCharacters(in: .whitespacesAndNewlines), publicKey: publicKey.trimmingCharacters(in: .whitespacesAndNewlines))
                    if await store.connect(config) { showConnection = false }
                }
            }.disabled(store.busy || serverURL.isEmpty || publicKey.isEmpty)
            if store.configured { Button("Отказ") { showConnection = false } }
            Text("Не поставяйте secret или service-role ключ. Без тази настройка приложението показва само локалната демонстрация.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}


struct ProfileAvatar: View {
    let profile: UserProfile?
    var size: CGFloat = 40
    var body: some View {
        Group {
            if let data = profile?.avatarData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [Theme.teal, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Text(String(profile?.display_name.prefix(1) ?? "?").uppercased())
                        .font(.system(size: size * 0.4, weight: .bold)).foregroundStyle(.white)
                }
            }
        }.frame(width: size, height: size).clipShape(Circle())
            .accessibilityLabel("Профилна снимка на \(profile?.display_name ?? "потребител")")
    }
}

struct ProfileCollectionView: View {
    enum Kind { case added, reviews }
    let kind: Kind
    @EnvironmentObject private var store: AppStore
    @State private var selected: Toilet?
    @State private var selectedCityPlace: CityPlace?
    private var title: String {
        switch kind { case .added: return "Добавени от мен"; case .reviews: return "Моите ревюта" }
    }
    private var places: [Toilet] {
        store.myToilets
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if kind == .reviews {
                    if store.myReviews.isEmpty { empty("Вашите ревюта ще се появят тук.", symbol: "star.bubble") }
                    ForEach(store.myReviews) { review in
                        if let place = store.toilets.first(where: { $0.id == review.toiletID }) {
                            Button { selected = place } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                                        Text(place.name).font(.headline).foregroundStyle(.primary)
                                        Spacer(minLength: 8)
                                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                                    }
                                    RatingStars(value: review.average ?? 0)
                                    Text(review.updatedAt.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                                    if !review.comment.isEmpty { Text(review.comment).lineLimit(3).foregroundStyle(.primary) }
                                    Text("Отвори мястото и редактирай ревюто").font(.caption).foregroundStyle(Theme.teal)
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(18).appCard()
                            }.buttonStyle(.plain)
                        }
                    }
                } else {
                    if places.isEmpty && store.myCityPlaces.isEmpty {
                        empty("Добавените от Вас места ще се появят тук.", symbol: "mappin.and.ellipse")
                    }
                    ForEach(store.myCityPlaces) { row in
                        Button { selectedCityPlace = row.place } label: { CityPlaceRow(place: row.place).appCard() }.buttonStyle(.plain)
                    }
                    ForEach(places) { place in
                        Button { selected = place } label: { ToiletCard(toilet: place) }.buttonStyle(.plain)
                    }
                }
                if store.busy { ProgressView("Обновяване…").frame(maxWidth: .infinity) }
            }.padding(16)
        }.background(Theme.background).navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .refreshable { await store.refresh() }
            .sheet(item: $selected) { ToiletDetailView(toilet: $0) }
            .sheet(item: $selectedCityPlace) { CityPlaceDetailView(place: $0) }
    }
    private func empty(_ message: String, symbol: String) -> some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text(message))
    }
}

struct ProfilePhotoEditor: View {
    let current: Data?
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var selection: PhotosPickerItem?
    @State private var photo: Data?
    @State private var loaded = false
    @State private var loading = false
    @State private var message: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Group {
                        if let photo, let image = UIImage(data: photo) {
                            Image(uiImage: image).resizable().scaledToFill()
                        } else { Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(Theme.teal) }
                    }.frame(width: 160, height: 160).clipShape(Circle())
                        .padding(8).background(Theme.softTeal, in: Circle())
                        .frame(maxWidth: .infinity).padding(.vertical, 24)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Покажете кой стои зад ревютата").font(.headline)
                        Text("Изберете снимка, която другите ще разпознават.").font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.vertical, 6)
                    PhotosPicker(selection: $selection, matching: .images) { Label("Избери снимка", systemImage: "photo") }
                        .buttonStyle(AppPrimaryButtonStyle()).disabled(loading || store.busy)
                    if photo != nil {
                        Button(role: .destructive) { photo = nil; selection = nil } label: {
                            Label("Премахни снимката", systemImage: "trash").frame(minHeight: 44)
                        }.disabled(loading || store.busy)
                    }
                    Text("Снимката е публична. Показва се до ревютата Ви. Намаляваме размера и премахваме оригиналните метаданни преди качване.")
                        .font(.caption).foregroundStyle(.secondary)
                    if loading { ProgressView("Подготовка на снимката…") }
                    if let message { Text(message).foregroundStyle(.red).font(.caption) }
                }
            }.scrollContentBackground(.hidden).background(Theme.background).tint(Theme.teal)
                .navigationTitle("Профилна снимка").navigationBarTitleDisplayMode(.inline)
                .onAppear { if !loaded { photo = current; loaded = true } }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Отказ") { dismiss() }.disabled(store.busy) }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Запази") { Task { if await store.saveAvatar(photo) { dismiss() } } }
                            .disabled(loading || !loaded || !store.canSave || photo == current)
                    }
                }
                .interactiveDismissDisabled(store.busy)
                .task(id: selection) {
                    guard let selection else { return }
                    loading = true; message = nil
                    defer { loading = false }
                    do {
                        guard let bytes = try await selection.loadTransferable(type: Data.self) else { throw CloudError("Снимката не може да бъде прочетена.") }
                        let result = await Task.detached(priority: .userInitiated) { AvatarImage.prepare(bytes) }.value
                        try Task.checkCancellation()
                        guard let result else { throw CloudError("Неуспешна обработка. Изберете друга снимка.") }
                        photo = result
                    } catch is CancellationError { }
                    catch { message = error.localizedDescription }
                }
                .storeError()
        }
    }
}


struct PublicProfileView: View {
    let userID: String
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var selection = 0
    @State private var destination: PublicReviewDestination?
    private var profile: UserProfile? { store.profiles.first { $0.id == userID } }
    private var places: [Toilet] {
        store.toilets.filter { store.toiletOwners[$0.id] == userID }.sorted { $0.name < $1.name }
    }
    private var reviews: [Review] {
        store.data.reviews.filter { $0.authorID == userID }.sorted { $0.updatedAt > $1.updatedAt }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if let profile {
                        VStack(spacing: 14) {
                            ProfileAvatar(profile: profile, size: 92)
                                .padding(6).background(Theme.softTeal, in: Circle())
                                .overlay(Circle().stroke(Theme.teal.opacity(0.18), lineWidth: 1))
                            Text(profile.display_name).font(.title2.bold()).multilineTextAlignment(.center)
                            Label("Принос към картата на Бургас", systemImage: "mappin.and.ellipse")
                                .font(.caption.weight(.medium)).foregroundStyle(Theme.teal)
                                .multilineTextAlignment(.center)
                            HStack(alignment: .top, spacing: 12) {
                                contributionStat(places.count, title: "Добавени места", symbol: "mappin.and.ellipse")
                                contributionStat(reviews.count, title: "Ревюта", symbol: "star.bubble.fill")
                            }.padding(.top, 6)
                        }.frame(maxWidth: .infinity).padding(24)
                            .appCard()
                        Picker("Публичен принос", selection: $selection) {
                            Text("Добавени тоалетни").tag(0)
                            Text("Ревюта").tag(1)
                        }.pickerStyle(.segmented)
                        if selection == 0 {
                            if places.isEmpty {
                                ContentUnavailableView("Няма добавени места", systemImage: "mappin.slash", description: Text("Този потребител още не е добавил тоалетни."))
                            }
                            ForEach(places) { place in
                                Button { destination = PublicReviewDestination(toilet: place, reviewID: nil) } label: { ToiletCard(toilet: place) }.buttonStyle(.plain)
                            }
                        } else {
                            if reviews.isEmpty {
                                ContentUnavailableView("Все още няма ревюта", systemImage: "star.bubble", description: Text("Публикуваните ревюта ще се появят тук."))
                            }
                            ForEach(reviews) { review in
                                Button { openReview(review) } label: {
                                  VStack(alignment: .leading, spacing: 12) {
                                    if let place = store.toilets.first(where: { $0.id == review.toiletID }) {
                                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                                Text(place.name).font(.headline).foregroundStyle(.primary)
                                                Spacer()
                                                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                                            }
                                    } else { Text("Мястото вече не е налично").font(.headline) }
                                    ViewThatFits(in: .horizontal) {
                                      HStack(spacing: 12) {
                                        RatingStars(value: review.average ?? 0)
                                        Text(review.updatedAt.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption).foregroundStyle(.secondary)
                                      }
                                      VStack(alignment: .leading, spacing: 6) {
                                        RatingStars(value: review.average ?? 0)
                                        Text(review.updatedAt.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption).foregroundStyle(.secondary)
                                      }
                                    }
                                    if !review.comment.isEmpty { Text(review.comment).font(.subheadline).foregroundStyle(.primary) }
                                    ForEach(ReviewFeature.allCases) { feature in
                                        if let value = review.observations?[feature.rawValue] {
                                            FeatureAnswerRow(feature: feature, answer: value ? "Да" : "Не", positive: value)
                                        }
                                    }
                                    if !review.photos.isEmpty {
                                        Label("\(review.photos.count) снимки · Отвори ревюто", systemImage: "photo")
                                            .font(.caption).foregroundStyle(Theme.teal)
                                    }
                                  }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                                      .appCard().contentShape(RoundedRectangle(cornerRadius: 22))
                                }.buttonStyle(.plain).multilineTextAlignment(.leading)
                                    .disabled(!store.toilets.contains { $0.id == review.toiletID })
                                    .accessibilityHint("Отваря пълното ревю")
                            }
                        }
                    } else {
                        ContentUnavailableView("Профилът не е наличен", systemImage: "person.crop.circle.badge.questionmark")
                    }
                }.padding(16)
            }.background(Theme.background)
                .tint(Theme.teal)
                .navigationTitle("Публичен профил").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Готово") { dismiss() } } }
                .sheet(item: $destination) { ToiletDetailView(toilet: $0.toilet, reviewID: $0.reviewID) }
        }
    }
    private func contributionStat(_ count: Int, title: String, symbol: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(Theme.teal).accessibilityHidden(true)
            Text("\(count)").font(.title2.bold()).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(12)
            .background(Theme.softTeal, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityElement(children: .combine)
    }
    private func openReview(_ review: Review) {
        guard let place = store.toilets.first(where: { $0.id == review.toiletID }) else { return }
        destination = PublicReviewDestination(toilet: place, reviewID: review.id)
    }

}

private struct PublicReviewDestination: Identifiable {
    let id = UUID()
    let toilet: Toilet
    let reviewID: UUID?
}
