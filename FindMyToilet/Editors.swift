import SwiftUI
import PhotosUI
import ImageIO

struct ReviewEditor: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let toilet: Toilet
    private let existingID: UUID?
    @State private var scores: [String: Int]
    @State private var observations: [String: Bool]
    @State private var comment: String
    @State private var photos: [Data]
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var loadingPhotos = false
    @State private var photoError: String?
    @State private var discard = false
    private let original: Review?

    init(toilet: Toilet, existing: Review?) {
        self.toilet = toilet
        original = existing
        existingID = existing?.id
        _scores = State(initialValue: existing?.scores.filter { key, _ in Criterion.ratingCases.contains { $0.rawValue == key } } ?? [:])
        _observations = State(initialValue: existing?.observations ?? [:])
        _comment = State(initialValue: existing?.comment ?? "")
        _photos = State(initialValue: existing?.photos ?? [])
    }
    private var hasChanges: Bool {
        scores != (original?.scores.filter { key, _ in Criterion.ratingCases.contains { $0.rawValue == key } } ?? [:]) || observations != (original?.observations ?? [:]) || comment != (original?.comment ?? "") || photos != (original?.photos ?? [])
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    EditorIntroduction(symbol: "star.bubble.fill", title: toilet.name,
                                       subtitle: "Споделете впечатленията си от мястото.")
                    Text("Оценете само това, което сте видели. 1 = много лошо, 5 = отлично.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if original?.scores.keys.contains(where: { key in !Criterion.ratingCases.contains { $0.rawValue == key } }) == true {
                        Text("При запис старите числови оценки за сапун, хартия и достъпност се заменят с отговорите по-долу. Попълнете ги отново; не ги преобразуваме автоматично.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Ревюто и снимките ще бъдат видими за всички потребители.").font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    ForEach(Criterion.ratingCases) { criterion in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(criterion.title).font(.headline)
                                Spacer(minLength: 8)
                                if scores[criterion.rawValue] != nil {
                                    Button("Изчисти") { scores.removeValue(forKey: criterion.rawValue) }
                                        .font(.caption.weight(.semibold)).buttonStyle(.borderless)
                                        .frame(minHeight: 44)
                                        .accessibilityLabel("Изчисти оценката за \(criterion.title)")
                                }
                            }
                            StarRatingInput(title: criterion.title, value: Binding(
                                get: { scores[criterion.rawValue] ?? 0 },
                                set: { scores[criterion.rawValue] = $0 }
                            ))
                        }.padding(.vertical, 8)
                    }
                } header: { Label("Вашата оценка", systemImage: "star") }
                Section {
                    ForEach(ReviewFeature.allCases) { feature in
                        FeatureAnswerPicker(feature: feature, answer: Binding(
                            get: { observations[feature.rawValue] },
                            set: { observations[feature.rawValue] = $0 }
                        ))
                    }
                } header: { Label("При посещението", systemImage: "checkmark.circle") }
                footer: { Text("Тези отговори не променят звездната оценка. Изберете „Непроверено“, ако не сте сигурни.") }
                Section {
                    TextField("Какво е полезно да знаят другите?", text: $comment, axis: .vertical)
                        .lineLimit(4...8).padding(.vertical, 6)
                        .accessibilityLabel("Коментар")
                } header: { Label("Коментар", systemImage: "text.bubble") }
                footer: {
                    HStack {
                        Text("Незадължително")
                        Spacer()
                        Text("\(comment.count)/1000").monospacedDigit()
                            .foregroundStyle(comment.count > 1000 ? Color.red : Color.secondary)
                    }
                }
                Section {
                    if photos.count < 3 {
                        PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 3 - photos.count, matching: .images) {
                            HStack(spacing: 12) {
                                Image(systemName: "photo.badge.plus").font(.title2)
                                    .frame(width: 42, height: 42)
                                    .background(Theme.softTeal, in: RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Добави снимки").font(.headline)
                                    Text("Още \(3 - photos.count) свободни места").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "plus.circle.fill").font(.title3)
                            }.padding(.vertical, 6).foregroundStyle(Theme.teal)
                        }.buttonStyle(.borderless).disabled(loadingPhotos)
                    }
                    if loadingPhotos { ProgressView("Зареждане на снимки…") }
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, data in
                        HStack {
                            if let image = UIImage(data: data) {
                                Image(uiImage: image).resizable().scaledToFill().frame(width: 84, height: 84)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .accessibilityLabel("Избрана снимка \(index + 1)")
                            }
                            Text("Снимка \(index + 1)").font(.subheadline.weight(.medium))
                            Spacer(minLength: 0)
                            Button(role: .destructive) { photos.remove(at: index) } label: {
                                Image(systemName: "trash").frame(width: 44, height: 44)
                            }.buttonStyle(.borderless)
                                .accessibilityLabel("Премахни снимка \(index + 1)")
                                .disabled(loadingPhotos)
                        }
                    }
                    if let photoError { Text(photoError).foregroundStyle(.red).font(.caption) }
                } header: { Label("Снимки • \(photos.count)/3", systemImage: "photo.on.rectangle") }
                footer: { Text("Избирайте снимки без хора и лични данни. Снимките се намаляват преди запис.") }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .scrollDismissesKeyboard(.interactively)
            .tint(Theme.teal)
            .navigationTitle(existingID == nil ? "Ново ревю" : "Моето ревю")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отказ") { if hasChanges || loadingPhotos { discard = true } else { dismiss() } }.disabled(store.busy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Запази") { Task { await save() } }
                        .fontWeight(.semibold)
                        .disabled(scores.isEmpty || comment.count > 1000 || loadingPhotos || !store.canSave)
                }
            }
            .interactiveDismissDisabled(hasChanges || loadingPhotos || store.busy)
            .confirmationDialog("Да се откажете ли от промените?", isPresented: $discard, titleVisibility: .visible) {
                Button("Откажи промените", role: .destructive) { dismiss() }
            }
            .task(id: selectedPhotos) { await importPhotos() }
            .storeError()
        }
    }
    @MainActor private func importPhotos() async {
        guard !selectedPhotos.isEmpty else { return }
        loadingPhotos = true
        photoError = nil
        defer { loadingPhotos = false }
        let items = selectedPhotos
        for item in items {
            guard !Task.isCancelled, photos.count < 3 else { break }
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let jpeg = Self.thumbnail(data) else {
                    photoError = "Една от снимките не може да бъде прочетена. Опитайте с друга."
                    continue
                }
                guard !Task.isCancelled else { return }
                photos.append(jpeg)
            } catch {
                if !Task.isCancelled { photoError = "Неуспешно зареждане. За снимки в iCloud проверете връзката." }
            }
        }
        if !Task.isCancelled { selectedPhotos = [] }
    }
    // ImageIO downsamples before decoding; redraw encodes a new JPEG without the original EXIF location.
    private static func thumbnail(_ data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1280
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: image).jpegData(compressionQuality: 0.75)
    }
    private func save() async {
        var review = Review(toiletID: toilet.id, scores: scores,
                            comment: comment.trimmingCharacters(in: .whitespacesAndNewlines), photos: photos)
        review.observations = observations
        if let existingID { review.id = existingID }
        if await store.saveReview(review) { dismiss() }
    }
}

struct ReportEditor: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let toilet: Toilet
    @State private var category: ReportCategory = .hours
    @State private var message = ""
    @State private var saved = false
    @State private var discard = false
    private var trimmed: String { message.trimmingCharacters(in: .whitespacesAndNewlines) }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    EditorIntroduction(symbol: "flag.fill", title: toilet.name,
                                       subtitle: "Забелязахте неточност? Помогнете ни да я поправим.")
                    Text("Сигналът ще бъде изпратен към общата база и ще бъде видим за администраторите на приложението. Не се изпраща до общината.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section {
                    Picker(selection: $category) {
                        ForEach(ReportCategory.allCases) { Text($0.title).tag($0) }
                    } label: {
                        Label("Категория", systemImage: "tag").foregroundStyle(.primary)
                    }.padding(.vertical, 5)
                } header: { Text("Какво не е наред?") }
                Section {
                    TextField("Опишете неточността…", text: $message, axis: .vertical)
                        .lineLimit(5...10).padding(.vertical, 6)
                        .accessibilityLabel("Описание на неточността")
                } header: { Label("Описание", systemImage: "text.alignleft") }
                footer: {
                    Text("\(trimmed.count)/1000 • поне 10 символа")
                        .foregroundStyle(trimmed.count > 1000 ? Color.red : Color.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .scrollDismissesKeyboard(.interactively)
            .tint(Theme.teal)
            .navigationTitle("Сигнал").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отказ") { if !message.isEmpty { discard = true } else { dismiss() } }.disabled(store.busy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Запази") {
                        Task { saved = await store.saveReport(IssueReport(toiletID: toilet.id, category: category, message: trimmed)) }
                    }.fontWeight(.semibold).disabled(!(10...1000).contains(trimmed.count) || saved || !store.canSave)
                }
            }
            .interactiveDismissDisabled(!message.isEmpty)
            .confirmationDialog("Да се откажете ли от сигнала?", isPresented: $discard, titleVisibility: .visible) {
                Button("Откажи промените", role: .destructive) { dismiss() }
            }
            .alert("Сигналът е изпратен", isPresented: $saved) {
                Button("Готово") { dismiss() }
            } message: { Text("Ще намерите сигнала в „Още“. Администраторите могат да го прегледат.") }
            .storeError()
        }
    }
}

struct StarRatingInput: View {
    let title: String
    @Binding var value: Int
    var body: some View {
        HStack(spacing: 5) {
            ForEach(1...5, id: \.self) { star in
                Button { value = star } label: {
                    Image(systemName: star <= value ? "star.fill" : "star")
                        .font(.title2.weight(.medium)).foregroundStyle(star <= value ? Color.orange : Color.secondary)
                        .frame(minWidth: 44, minHeight: 48)
                        .frame(maxWidth: .infinity)
                        .background(star <= value ? Color.orange.opacity(0.10) : Color(uiColor: .tertiarySystemFill),
                                    in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("\(title): \(star) от 5 звезди")
                .accessibilityAddTraits(star == value ? .isSelected : [])
            }
        }
    }
}

struct RatingStars: View {
    let value: Double
    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: value >= Double(star) - 0.25 ? "star.fill" : value >= Double(star) - 0.75 ? "star.leadinghalf.filled" : "star")
            }
        }.foregroundStyle(.orange)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(format: "%.1f от 5 звезди", value))
    }
}


struct FeatureAnswerRow: View {
    let feature: ReviewFeature
    let answer: String
    var positive: Bool? = nil
    private var accent: Color { positive == true ? Theme.teal : positive == false ? .orange : .secondary }
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { heading; Spacer(minLength: 8); badge }
            VStack(alignment: .leading, spacing: 12) { heading; badge }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(feature.accessibilityTitle + ": " + answer)
    }
    private var heading: some View {
        Label(feature.title, systemImage: feature.symbol).font(.headline)
            .foregroundStyle(.primary).fixedSize(horizontal: true, vertical: false)
    }
    private var badge: some View {
        Text(answer).font(.headline.weight(.bold)).foregroundStyle(accent)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(accent.opacity(0.1), in: Capsule()).fixedSize(horizontal: true, vertical: false)
    }
}

struct FeatureAnswerPicker: View {
    let feature: ReviewFeature
    @Binding var answer: Bool?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(feature.title).font(.headline)
            } icon: {
                Image(systemName: feature.symbol).foregroundStyle(Theme.teal)
                    .frame(width: 30, height: 30)
                    .background(Theme.softTeal, in: RoundedRectangle(cornerRadius: 9))
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { options }
                VStack(alignment: .leading, spacing: 8) { options }
            }
        }.padding(.vertical, 10)
    }
    @ViewBuilder private var options: some View {
        option("Да", value: true, color: Theme.teal)
        option("Не", value: false, color: .orange)
        option("Непроверено", value: nil, color: .secondary)
    }
    private func option(_ title: String, value: Bool?, color: Color) -> some View {
        Button { answer = value } label: {
            HStack(spacing: 5) {
                if answer == value { Image(systemName: "checkmark").font(.caption.weight(.bold)) }
                Text(title).font(.body.weight(.semibold))
            }.fixedSize()
                .padding(.horizontal, 12).frame(minWidth: 44, minHeight: 48)
                .foregroundStyle(answer == value ? color : .secondary)
                .background(answer == value ? color.opacity(0.14) : Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(answer == value ? color : .clear, lineWidth: 2))
        }.buttonStyle(.borderless)
            .accessibilityLabel(feature.accessibilityTitle + ": " + title)
            .accessibilityAddTraits(answer == value ? .isSelected : [])
    }
}

// Shared by the contribution forms, with no fixed text height for larger text sizes.
struct EditorIntroduction: View {
    let symbol: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold)).foregroundStyle(Theme.teal)
                .frame(width: 52, height: 52)
                .background(Theme.softTeal, in: RoundedRectangle(cornerRadius: 16))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.title2.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
    }
}
