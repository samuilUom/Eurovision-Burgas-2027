import SwiftUI
import MapKit

struct CityPlaceEditor: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    private let existing: CommunityPlace?
    private let onSave: (CommunityPlace) -> Void
    @State private var category: EventCategory
    @State private var name: String
    @State private var address: String
    @State private var website: String
    @State private var notes: String
    @State private var hours: [OpeningInterval]?
    @State private var camera: MapCameraPosition
    @State private var center: CLLocationCoordinate2D
    @State private var selected: CLLocationCoordinate2D?
    @State private var saving = false
    @State private var message: String?
    @State private var newID = UUID().uuidString.lowercased()

    init(category: EventCategory, region: MKCoordinateRegion = CitySearchArea.burgas, existing: CommunityPlace? = nil, onSave: @escaping (CommunityPlace) -> Void = { _ in }) {
        self.existing = existing
        self.onSave = onSave
        _category = State(initialValue: existing?.category ?? category.section)
        _name = State(initialValue: existing?.name ?? "")
        _address = State(initialValue: existing?.address ?? "")
        _website = State(initialValue: existing?.website ?? "")
        _notes = State(initialValue: existing?.notes ?? "")
        _hours = State(initialValue: existing?.hours ?? (existing?.is_nonstop == true ? OpeningSchedule.allDay : nil))
        let initial = existing.map { MKCoordinateRegion(center: $0.coordinate, span: .init(latitudeDelta: 0.008, longitudeDelta: 0.008)) } ?? region
        _center = State(initialValue: initial.center)
        _selected = State(initialValue: existing?.coordinate)
        _camera = State(initialValue: .region(initial))
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Label(existing == nil ? "Ново място за всички" : "Редакция на мястото", systemImage: category.symbol)
                        .font(.title2.bold()).foregroundStyle(category.ink)
                    Text("Избери категория, отбележи точката на картата и добави това, което знаеш.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("Категория", selection: $category) {
                            ForEach(CommunityPlace.categories) { Text($0.title).tag($0) }
                        }
                        field("Име", placeholder: "Име на мястото", text: $name)
                        field("Адрес", placeholder: "Улица, номер или ориентир", text: $address)
                    }.padding(18).appCard()
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Точната локация", systemImage: "mappin.and.ellipse").font(.headline)
                        Text("Премести картата, докато мястото е под кръстчето, и потвърди точката.")
                            .font(.caption).foregroundStyle(.secondary)
                        Map(position: $camera) {
                            if let selected { Marker(name.isEmpty ? "Избрано място" : name, coordinate: selected).tint(category.color) }
                        }.mapStyle(.standard).onMapCameraChange(frequency: .onEnd) { center = $0.region.center }
                            .frame(height: 250).overlay {
                                Image(systemName: "plus.viewfinder").font(.title).foregroundStyle(category.ink)
                                    .padding(6).background(.regularMaterial, in: Circle()).allowsHitTesting(false)
                            }.clipShape(RoundedRectangle(cornerRadius: 18))
                        Button { selected = center } label: {
                            Label("Избери тази точка", systemImage: "mappin.circle.fill").frame(maxWidth: .infinity)
                        }.buttonStyle(CategoryButtonStyle(category: category, prominent: false))
                        if let selected {
                            Text("Избрано: \(selected.latitude, specifier: "%.5f"), \(selected.longitude, specifier: "%.5f")")
                                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                        }
                    }.padding(18).appCard()
                    if category != .transport {
                        CommunityHoursEditor(hours: $hours).padding(18).appCard()
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        field("Уебсайт", placeholder: "https://… (по желание)", text: $website, url: true)
                        Text("Полезно да се знае").font(.headline)
                        TextField("Достъп или ориентир (по желание)", text: $notes, axis: .vertical)
                            .lineLimit(3...6).padding(12).background(Theme.background, in: RoundedRectangle(cornerRadius: 12))
                    }.padding(18).appCard()
                    if let message { Text(message).font(.subheadline).foregroundStyle(.red) }
                    if saving { ProgressView("Запазване…") }
                    Button { Task { await save() } } label: {
                        Label("Запази мястото", systemImage: "checkmark").frame(maxWidth: .infinity)
                    }.buttonStyle(CategoryButtonStyle(category: category)).disabled(saving || !store.canSave || selected == nil)
                    if selected == nil { Text("Първо избери точката на картата.").font(.caption).foregroundStyle(.secondary) }
                    if store.profile == nil { Text("За добавяне е нужен вход от „Профил“.").font(.caption).foregroundStyle(.secondary) }
                }.padding(18)
            }.background(Theme.background).navigationTitle(existing == nil ? "Добави място" : "Редактирай")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отказ") { dismiss() }.disabled(saving) } }
        }.tint(category.ink).interactiveDismissDisabled(saving)
    }
    private func field(_ title: String, placeholder: String, text: Binding<String>, url: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.headline)
            TextField(placeholder, text: text).textInputAutocapitalization(url ? .never : .sentences)
                .keyboardType(url ? .URL : .default).autocorrectionDisabled(url)
                .padding(12).background(Theme.background, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    private func save() async {
        guard let selected, let userID = store.userID, !saving else { return }
        let cleanURL = website.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = CommunityPlace(id: existing?.id ?? newID, created_by: existing?.created_by ?? userID,
                                  category: category, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                  address: address.trimmingCharacters(in: .whitespacesAndNewlines),
                                  latitude: selected.latitude, longitude: selected.longitude,
                                  website: cleanURL.isEmpty ? nil : cleanURL, notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                                  is_nonstop: category.supportsNonstop ? hours.map { OpeningSchedule.isAllDay($0) } : nil,
                                  hours: category == .transport ? nil : hours)
        if let problem = value.validationMessage { message = problem; return }
        saving = true
        message = await store.saveCityPlace(value, editing: existing != nil)
        saving = false
        if message == nil { onSave(value); dismiss() }
    }
}

// Compact optional schedule: explicit known/unknown, a selected day, and time pickers.
private struct CommunityHoursEditor: View {
    @Binding var hours: [OpeningInterval]?
    @State private var day = 2
    private let days = [(2, "Пон"), (3, "Вт"), (4, "Ср"), (5, "Чет"), (6, "Пет"), (7, "Съб"), (1, "Нед")]
    private var rows: [Int] { (hours ?? []).indices.filter { hours?[$0].weekday == day } }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: Binding(get: { hours != nil }, set: { hours = $0 ? [] : nil })) {
                Label("Знам работното време", systemImage: "clock.fill").font(.headline)
            }
            if hours != nil {
                HStack {
                    Text("По график • часът в Бургас").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        Button("24 часа всеки ден") { hours = OpeningSchedule.allDay }
                        Button("Копирай деня за цялата седмица") {
                            let source = (hours ?? []).filter { $0.weekday == day }
                            hours = (1...7).flatMap { weekday in source.map { OpeningInterval(weekday: weekday, opens: $0.opens, closes: $0.closes) } }
                        }.disabled(rows.count > 4)
                    } label: { Label("Бързо", systemImage: "wand.and.stars").font(.subheadline).frame(minHeight: 44) }
                }
                Text("Дните без часове се считат за затворени.").font(.caption).foregroundStyle(.secondary)
                Picker("Ден", selection: $day) {
                    ForEach(days, id: \.0) { Text($0.1).tag($0.0) }
                }.pickerStyle(.segmented)
                Toggle("Отворено през този ден", isOn: Binding(get: { !rows.isEmpty }, set: { open in
                    if open { addInterval() } else { hours?.removeAll { $0.weekday == day } }
                })).disabled(rows.isEmpty && (hours?.count ?? 0) >= 28)
                ForEach(rows, id: \.self) { index in
                    if let values = hours, values.indices.contains(index) {
                        let row = values[index]
                        VStack(alignment: .leading, spacing: 8) {
                            if row.opens == 0 && row.closes == 1440 {
                                Label("24 часа", systemImage: "moon.stars.fill").font(.subheadline.bold())
                                Button("Задай часове") { replace(index, opens: 8 * 60, closes: 20 * 60) }
                            } else {
                                DatePicker("От", selection: time(index, closing: false), displayedComponents: .hourAndMinute)
                                DatePicker("До", selection: time(index, closing: true), displayedComponents: .hourAndMinute)
                                if row.closes < row.opens { Text("Затваря на следващия ден").font(.caption).foregroundStyle(.secondary) }
                                if row.closes == row.opens { Text("Избери различен краен час или 24 часа.").font(.caption).foregroundStyle(.red) }
                            }
                            if rows.count > 1 {
                                Button("Премахни интервала", role: .destructive) {
                                    if let values = hours, values.indices.contains(index) { hours?.remove(at: index) }
                                }
                                    .font(.caption).frame(minHeight: 44)
                            }
                        }.padding(12).background(Theme.background, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                if !rows.isEmpty {
                    HStack {
                        Button("24 часа") {
                            hours?.removeAll { $0.weekday == day }
                            hours?.append(.init(weekday: day, opens: 0, closes: 1440))
                        }
                        Spacer()
                        Button("Още интервал") { addInterval() }.disabled((hours?.count ?? 0) >= 28 || rows.count >= 4)
                    }.font(.subheadline).frame(minHeight: 44)
                }
            } else {
                Text("Ще се показва „Неизвестно работно време“. Добави график само ако го знаеш.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.environment(\.timeZone, OpeningSchedule.calendar.timeZone)
            .environment(\.locale, Locale(identifier: "bg_BG"))
    }
    private func addInterval() { hours?.append(.init(weekday: day, opens: 8 * 60, closes: 20 * 60)) }
    private func replace(_ index: Int, opens: Int, closes: Int) {
        guard let values = hours, values.indices.contains(index) else { return }
        hours?[index] = .init(weekday: values[index].weekday, opens: opens, closes: closes)
    }
    private func time(_ index: Int, closing: Bool) -> Binding<Date> {
        Binding(get: {
            let row = hours.flatMap { $0.indices.contains(index) ? $0[index] : nil }
            let minutes = (closing ? row?.closes : row?.opens) ?? 0
            return OpeningSchedule.calendar.date(from: DateComponents(year: 2026, month: 1, day: 5,
                hour: (minutes / 60) % 24, minute: minutes % 60))!
        }, set: { value in
            guard let values = hours, values.indices.contains(index) else { return }
            let row = values[index]
            let parts = OpeningSchedule.calendar.dateComponents([.hour, .minute], from: value)
            let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            replace(index, opens: closing ? row.opens : minute, closes: closing ? (minute == 0 ? 1440 : minute) : row.closes)
        })
    }
}
