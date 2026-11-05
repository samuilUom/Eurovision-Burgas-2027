import SwiftUI
import MapKit


private struct EditableHours: Identifiable {
    let id = UUID()
    var weekday = 2
    var opens = "08:00"
    var closes = "20:00"
    init() {}
    init(_ interval: OpeningInterval) {
        weekday = interval.weekday
        opens = String(format: "%02d:%02d", interval.opens / 60, interval.opens % 60)
        closes = String(format: "%02d:%02d", interval.closes / 60, interval.closes % 60)
    }
    var interval: OpeningInterval? {
        func minutes(_ value: String, end: Bool) -> Int? {
            let parts = value.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]), (0...59).contains(m),
                  (0...23).contains(h) || (end && h == 24 && m == 0) else { return nil }
            return h * 60 + m
        }
        guard let a = minutes(opens, end: false), let b = minutes(closes, end: true), a != b else { return nil }
        return OpeningInterval(weekday: weekday, opens: a, closes: b)
    }
}

struct ToiletEditor: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let existing: Toilet?
    @State private var name: String
    @State private var address: String
    @State private var kind: String
    @State private var price: String
    @State private var unknownPrice: Bool
    @State private var currency: String
    @State private var note: String
    @State private var latitude: Double
    @State private var longitude: Double
    @State private var amenities: Set<Amenity>
    @State private var unknownHours: Bool
    @State private var hours: [EditableHours]
    @State private var verified: Bool
    @State private var verificationDate: Date
    @State private var discard = false
    @State private var copyDay: Int?
    @State private var showCopy = false
    @State private var position: MapCameraPosition
    @State private var newID = UUID().uuidString.lowercased()
    private let weekdays = [(2, "Понеделник"), (3, "Вторник"), (4, "Сряда"), (5, "Четвъртък"), (6, "Петък"), (7, "Събота"), (1, "Неделя")]

    init(existing: Toilet?) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _address = State(initialValue: existing?.address ?? "")
        _kind = State(initialValue: existing?.kind ?? "Обществена тоалетна")
        _price = State(initialValue: existing?.price.map { String(format: "%.2f", $0) } ?? "0")
        _unknownPrice = State(initialValue: existing?.price == nil)
        _currency = State(initialValue: existing?.currency ?? "EUR")
        _note = State(initialValue: existing?.accessNote ?? "")
        let lat = existing?.latitude ?? 42.497
        let lon = existing?.longitude ?? 27.473
        _latitude = State(initialValue: lat); _longitude = State(initialValue: lon)
        _amenities = State(initialValue: Set(existing?.amenities ?? []))
        _unknownHours = State(initialValue: existing?.hours == nil)
        _hours = State(initialValue: (existing?.hours ?? []).map(EditableHours.init))
        _verified = State(initialValue: existing?.verifiedAt != nil)
        _verificationDate = State(initialValue: existing?.verifiedAt ?? Date())
        _position = State(initialValue: .region(.init(center: .init(latitude: lat, longitude: lon), span: .init(latitudeDelta: 0.02, longitudeDelta: 0.02))))
    }
    private var candidate: Toilet {
        Toilet(id: existing?.id ?? newID, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
               address: address.trimmingCharacters(in: .whitespacesAndNewlines), latitude: latitude, longitude: longitude,
               kind: kind.trimmingCharacters(in: .whitespacesAndNewlines),
               price: unknownPrice ? nil : Double(price.replacingOccurrences(of: ",", with: ".")), currency: currency.uppercased(),
               amenities: Amenity.allCases.filter { amenities.contains($0) }, hours: unknownHours ? nil : hours.compactMap(\.interval),
               accessNote: note, isDemo: existing?.isDemo ?? false, verifiedAt: store.isAdmin && verified ? verificationDate : nil)
    }
    private var problem: String? {
        if !unknownPrice && Double(price.replacingOccurrences(of: ",", with: ".")) == nil { return "Въведете валидна цена." }
        if !unknownHours && hours.contains(where: { $0.interval == nil }) { return "Началото и краят не могат да съвпадат. За цял ден изберете „24 часа“." }
        return candidate.validationError
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    EditorIntroduction(symbol: "mappin.and.ellipse",
                                       title: existing == nil ? "Ново място" : "Детайли за мястото",
                                       subtitle: "Помогнете на другите да намерят точната информация.")
                }
                Section {
                    editorField("Име", placeholder: "Име на мястото", text: $name)
                    editorField("Адрес", placeholder: "Улица, номер или описание на входа", text: $address)
                    editorField("Тип", placeholder: "Например обществена тоалетна", text: $kind)
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Условия за достъп").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        TextField("Полезни детайли за посетителите…", text: $note, axis: .vertical)
                            .lineLimit(3...6).accessibilityLabel("Условия за достъп и описание")
                    }.padding(.vertical, 6)
                } header: { Label("За мястото", systemImage: "building.2") }
                Section {
                    MapReader { proxy in
                        Map(position: $position) {
                            Marker("Вход", coordinate: .init(latitude: latitude, longitude: longitude))
                        }
                        .onTapGesture { point in
                            if let coordinate = proxy.convert(point, from: .local) { latitude = coordinate.latitude; longitude = coordinate.longitude }
                        }
                    }.frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(alignment: .topLeading) {
                            Label("Докоснете точния вход", systemImage: "hand.tap")
                                .font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 9)
                                .background(.regularMaterial, in: Capsule()).padding(10)
                                .allowsHitTesting(false)
                        }
                        .padding(.vertical, 4)
                    DisclosureGroup("Точни координати") {
                        LabeledContent("Ширина") { TextField("42.497", value: $latitude, format: .number.precision(.fractionLength(6))).keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing) }
                        LabeledContent("Дължина") { TextField("27.473", value: $longitude, format: .number.precision(.fractionLength(6))).keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing) }
                    }
                } header: { Label("Местоположение", systemImage: "mappin.and.ellipse") }
                footer: { Text("Обхватът е районът на Бургас. Поставете точката при входа, а не в центъра на сградата.") }
                Section {
                    Toggle(isOn: Binding(get: { !unknownPrice }, set: { unknownPrice = !$0 })) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Цената е известна").font(.headline)
                            Text(unknownPrice ? "Показва се като неизвестна" : "Добавете точната сума по-долу")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 4)
                    }
                    if !unknownPrice {
                        LabeledContent("Цена") {
                            TextField("0 за безплатно", text: $price)
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                .font(.title3.weight(.semibold)).foregroundStyle(Theme.teal)
                                .accessibilityLabel("Цена")
                        }.padding(.vertical, 4)
                        editorField("Валута", placeholder: "EUR", text: $currency)
                            .textInputAutocapitalization(.characters)
                    }
                } header: { Label("Цена", systemImage: "creditcard") }
                footer: { if !unknownPrice { Text("Въведете 0, ако достъпът е безплатен.") } }
                Section {
                    ForEach(Amenity.allCases) { amenity in
                        Toggle(isOn: Binding(get: { amenities.contains(amenity) }, set: { if $0 { amenities.insert(amenity) } else { amenities.remove(amenity) } })) {
                            Label {
                                Text(amenity.title).font(.subheadline.weight(.semibold))
                            } icon: {
                                Image(systemName: amenity.symbol).foregroundStyle(Theme.teal)
                                    .frame(width: 34, height: 34)
                                    .background(Theme.softTeal, in: RoundedRectangle(cornerRadius: 10))
                            }.padding(.vertical, 5)
                        }
                    }
                } header: { Label("Удобства", systemImage: "checkmark.seal") }
                Section {
                    Toggle(isOn: Binding(get: { !unknownHours }, set: { unknownHours = !$0 })) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Работното време е известно").font(.headline)
                            Text(unknownHours ? "Не е добавен график" : "Изберете отворените дни")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 4)
                    }
                    if !unknownHours {
                        Text("Включете дните, в които е отворено, и изберете от колко до колко.").font(.subheadline).foregroundStyle(.secondary)
                    }
                } header: { Label("Работно време", systemImage: "clock") }
                if !unknownHours {
                    Section {
                        ForEach(weekdays, id: \.0) { day in
                            VStack(alignment: .leading, spacing: 12) {
                                dayCard(day.0, title: day.1)
                            }.padding(.vertical, 8)
                        }
                    } header: { Label("Седмичен график", systemImage: "calendar") }
                    Section {
                        Button { copyDay = nil; showCopy = true } label: {
                            Label("24 часа всеки ден", systemImage: "clock.arrow.circlepath")
                                .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                        }.buttonStyle(.borderless)
                    } footer: {
                        Text("Часовете са по местно време за Бургас. Край преди началото означава работа след полунощ.")
                    }
                }
                if store.isAdmin {
                    Section("Административна проверка") {
                        Toggle("Проверено на място", isOn: $verified)
                        if verified { DatePicker("Дата на проверка", selection: $verificationDate, in: ...Date(), displayedComponents: .date) }
                    }
                }
                if let problem {
                    Section {
                        Label(problem, systemImage: "info.circle")
                            .font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 3)
                    }
                }
                if store.busy { ProgressView("Запазване…") }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .scrollDismissesKeyboard(.interactively)
            .tint(Theme.teal)
            .disabled(store.busy)
            .navigationTitle(existing == nil ? "Добави тоалетна" : "Редактирай обекта")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отказ") { discard = true }.disabled(store.busy) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Запази") { Task { if await store.saveToilet(candidate, editing: existing != nil) { dismiss() } } }
                        .fontWeight(.semibold)
                        .disabled(problem != nil || !store.canSave)
                }
            }
            .interactiveDismissDisabled()
            .confirmationDialog("Да се откажете ли от промените?", isPresented: $discard, titleVisibility: .visible) {
                Button("Откажи промените", role: .destructive) { dismiss() }
            }
            .confirmationDialog("Замяна на работното време", isPresented: $showCopy, titleVisibility: .visible) {
                if let day = copyDay {
                    Button("Копирай за понеделник – петък") { copySchedule(from: day, to: [2, 3, 4, 5, 6]) }
                        .disabled(copiedCount(from: day, to: [2, 3, 4, 5, 6]) > 28)
                    Button("Копирай за всички дни") { copySchedule(from: day, to: [1, 2, 3, 4, 5, 6, 7]) }
                        .disabled(copiedCount(from: day, to: [1, 2, 3, 4, 5, 6, 7]) > 28)
                } else {
                    Button("Задай 24 часа всеки ден") { hours = DemoData.daily(0, 24).map(EditableHours.init) }
                }
                Button("Отказ", role: .cancel) {}
            } message: {
                Text("Съществуващите часове за избраните дни ще бъдат заменени.")
            }
            .storeError()
        }
    }
    private func editorField(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            TextField(placeholder, text: text).accessibilityLabel(title)
        }.padding(.vertical, 6)
    }

    private func copiedCount(from day: Int, to days: [Int]) -> Int {
        hours.filter { !days.contains($0.weekday) }.count + hours.filter { $0.weekday == day }.count * days.count
    }

    private func copySchedule(from day: Int, to days: [Int]) {
        guard copiedCount(from: day, to: days) <= 28 else { return }
        let source = hours.filter { $0.weekday == day }
        hours.removeAll { days.contains($0.weekday) }
        for target in days {
            for row in source {
                var copy = EditableHours()
                copy.weekday = target; copy.opens = row.opens; copy.closes = row.closes
                hours.append(copy)
            }
        }
    }

    private func addHours(_ day: Int, allDay: Bool = false) {
        var row = EditableHours()
        row.weekday = day
        if allDay { row.opens = "00:00"; row.closes = "24:00" }
        hours.append(row)
    }

    @ViewBuilder private func dayCard(_ day: Int, title: String) -> some View {
        let rows = hours.filter { $0.weekday == day }
        Toggle(isOn: Binding(get: { !hours.filter { $0.weekday == day }.isEmpty }, set: { open in
            if open {
                if hours.count < 28 { addHours(day) }
            } else {
                hours.removeAll { $0.weekday == day }
            }
        })) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Label(rows.isEmpty ? "Затворено" : "Отворено", systemImage: rows.isEmpty ? "minus.circle" : "checkmark.circle.fill")
                    .font(.caption.weight(.medium)).foregroundStyle(rows.isEmpty ? Color.secondary : Theme.teal)
            }
        }.disabled(rows.isEmpty && hours.count >= 28)
        ForEach($hours) { $row in
            if row.weekday == day {
                VStack(spacing: 10) {
                    if row.opens == "00:00" && row.closes == "24:00" {
                        Label("24 часа", systemImage: "clock").font(.headline).foregroundStyle(Theme.teal)
                        Button("Промени часовете") { row.opens = "08:00"; row.closes = "20:00" }
                            .buttonStyle(.borderless).frame(minHeight: 44)
                    } else {
                        timePicker("От", text: $row.opens, closing: false)
                        timePicker("До", text: $row.closes, closing: true)
                    }
                    if let interval = row.interval, interval.closes < interval.opens {
                        Label("До следващия ден", systemImage: "moon.stars.fill")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if rows.count > 1 {
                        Button(role: .destructive) { hours.removeAll { $0.id == row.id } } label: {
                            Label("Премахни интервала", systemImage: "minus.circle")
                        }.buttonStyle(.borderless).font(.subheadline).frame(minHeight: 44)
                    }
                }.padding(14).background(Theme.softTeal, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.border))
            }
        }
        if !rows.isEmpty {
            Menu {
                Button("Същите часове за други дни…") { copyDay = day; showCopy = true }
                Button("Отворено 24 часа") {
                    hours.removeAll { $0.weekday == day }; addHours(day, allDay: true)
                }
                Button("Добави втори интервал") { addHours(day) }.disabled(hours.count >= 28)
            } label: {
                Label("Още опции", systemImage: "ellipsis.circle").font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    .accessibilityLabel("Още опции за \(title)")
            }
        }
    }

    private func timePicker(_ title: String, text: Binding<String>, closing: Bool) -> some View {
        // Fixed UTC anchor represents wall-clock minutes, independent of the device timezone and DST.
        let anchor = Date(timeIntervalSince1970: 946684800)
        let selection = Binding<Date>(get: {
            let parts = text.wrappedValue.split(separator: ":").compactMap { Int($0) }
            let minutes = parts.count == 2 ? (parts[0] * 60 + parts[1]) % 1440 : 0
            return anchor.addingTimeInterval(Double(minutes * 60))
        }, set: { date in
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let hour = calendar.component(.hour, from: date)
            let minute = calendar.component(.minute, from: date)
            text.wrappedValue = closing && hour == 0 && minute == 0 ? "24:00" : String(format: "%02d:%02d", hour, minute)
        })
        return DatePicker(title, selection: selection, displayedComponents: .hourAndMinute)
            .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
            .environment(\.locale, Locale(identifier: "bg_BG"))
            .datePickerStyle(.compact)
            .font(.headline)
    }

}
