import SwiftUI

struct EntityBadge: View {
    let kind: RecordKind
    let size: CGFloat
    var body: some View {
        Image(systemName: kind.icon)
            .font(.system(size: size * 0.43, weight: .medium))
            .foregroundStyle(AppTheme.accent)
            .frame(width: size, height: size)
            .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.24))
            .accessibilityHidden(true)
    }
}

struct RecordEditor: View {
    @State var draft: RecordDraft
    let records: [RecordKind: [DatabaseRecord]]
    let attributeChoices: [String: [AttributeChoice]]
    let onSave: (RecordDraft) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?
    @State private var attemptedSave = false
    @State private var playerSection = "Details"
    @State private var initialValues: [String: String]?
    @State private var initialAssignment = ""
    @State private var confirmDiscard = false
    @FocusState private var focusedField: String?
    private var isDirty: Bool {
        guard let initialValues else { return false }
        return draft.values != initialValues || draft.assignment != initialAssignment
    }
    private var sectionTitle: String { draft.kind == .player ? "Personal information" : "\(draft.kind.singular) details" }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                EntityBadge(kind: draft.kind, size: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(draft.id == nil ? "New" : "Edit") \(draft.kind.singular.lowercased())")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text(draft.id == nil ? "Add to your football database." : "Update this record for future careers.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
            }.padding(24)
            Divider()
            if draft.kind == .player {
                Picker("Player section", selection: $playerSection) {
                    Text("Details").tag("Details")
                    Text("Physical").tag("Physical")
                    Text("Mental").tag("Mental")
                }.pickerStyle(.segmented).padding(.horizontal, 24).padding(.top, 16)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if draft.kind == .team { teamPreview }
                    if draft.kind != .player || playerSection == "Details" {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            SectionCaption(sectionTitle)
                            Spacer()
                            Text("All fields required").font(.caption).foregroundStyle(.secondary)
                        }
                        VStack(spacing: 0) {
                            ForEach(Array(draft.kind.fields.enumerated()), id: \.element.id) { index, field in
                                fieldRow(field)
                                if index < draft.kind.fields.count - 1 { Divider().padding(.leading, 16) }
                            }
                        }.background(AppTheme.panel, in: RoundedRectangle(cornerRadius: AppTheme.panelRadius))
                            .overlay(RoundedRectangle(cornerRadius: AppTheme.panelRadius).strokeBorder(Color.primary.opacity(0.08)))
                    }
                    if let target = draft.kind.assignment {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                SectionCaption(target == .team ? "Team assignment" : "Competition")
                                Spacer()
                                Text("Optional").font(.caption).foregroundStyle(.secondary)
                            }
                            HStack(spacing: 16) {
                                Text(target.singular).frame(width: 120, alignment: .leading)
                                Picker(target.singular, selection: $draft.assignment) {
                                    Text("Unassigned").tag("")
                                    ForEach(records[target] ?? []) { record in Text(record.title).tag(String(record.id)) }
                                }.labelsHidden().frame(maxWidth: .infinity).controlSize(.large)
                            }.padding(16).background(AppTheme.panel, in: RoundedRectangle(cornerRadius: AppTheme.panelRadius))
                                .overlay(RoundedRectangle(cornerRadius: AppTheme.panelRadius).strokeBorder(Color.primary.opacity(0.08)))
                            Text(target == .team ? "You can assign a club now or come back to it later." : "You can choose a league now or leave this club unassigned.")
                                .font(.caption).foregroundStyle(.secondary)
                            if draft.id != nil, draft.assignment != initialAssignment {
                                Label("Saving will replace the previous assignment.", systemImage: "info.circle")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    }
                    if draft.kind == .player, playerSection != "Details" {
                        attributeSection
                    }
                    if let message = error ?? (attemptedSave ? draft.validation : nil) {
                        Label(message, systemImage: "exclamationmark.circle.fill")
                            .font(.callout).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                    }
                }.padding(24)
            }.frame(height: editorBodyHeight)
            Divider()
            HStack {
                Label("Saved on this Mac", systemImage: "internaldrive")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
                Button(draft.id == nil ? "Create \(draft.kind.singular.lowercased())" : "Save changes", action: save)
                    .gamePrimaryAction().keyboardShortcut(.defaultAction)
            }.controlSize(.large).padding(.horizontal, 24).padding(.vertical, 16)
        }
        .frame(width: 600)
        .background(AppTheme.background)
        .preferredColorScheme(.dark)
        .tint(AppTheme.accent)
        .defaultFocus($focusedField, draft.kind.fields.first?.id)
        .interactiveDismissDisabled(isDirty)
        .onAppear {
            normalizeAttributeChoices()
            initialValues = draft.values
            initialAssignment = draft.assignment
        }
        .confirmationDialog("Discard your changes?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard changes", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) { }
        } message: { Text("Your changes haven’t been saved.") }
    }
    private var attributeSection: some View {
        let attributes = playerSection == "Physical" ? PlayerAttributes.physical : PlayerAttributes.mental
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    SectionCaption("\(playerSection) attributes")
                    Text(playerSection == "Physical" ? "Skills: 1–20. Condition: 0–100%." : "Skills: 1–20.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Randomize skills", systemImage: "shuffle") {
                    do {
                        draft.values.merge(try PlayerAttributes.randomized(choices: attributeChoices)) { _, new in new }
                        error = nil
                    } catch { self.error = error.localizedDescription }
                }.help("Randomize physical and mental skills, condition, preferred foot and morale. Changes are only applied when you save.")
            }
            VStack(spacing: 0) {
                ForEach(Array(attributes.enumerated()), id: \.element.id) { index, attribute in
                    HStack(spacing: 12) {
                        Text(attribute.label).frame(maxWidth: .infinity, alignment: .leading)
                        TextField(attribute.label, text: Binding(get: { draft.values[attribute.id] ?? "" }, set: { draft.values[attribute.id] = $0; error = nil }))
                            .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing)
                            .frame(width: 55).monospacedDigit()
                            .accessibilityLabel(attribute.label).accessibilityIdentifier(attribute.id)
                        Stepper(attribute.label, value: Binding(get: { Int(draft.values[attribute.id] ?? "") ?? attribute.initial }, set: { draft.values[attribute.id] = String($0); error = nil }), in: attribute.range)
                            .labelsHidden().fixedSize().accessibilityLabel("Adjust \(attribute.label)")
                        Text(attribute.range.upperBound == 100 ? "%" : "/ 20").font(.caption).foregroundStyle(.secondary).frame(width: 30)
                    }.padding(.horizontal, 16).padding(.vertical, 10)
                    if index < attributes.count - 1 { Divider().padding(.leading, 16) }
                }
                if playerSection == "Physical" {
                    Divider()
                    attributePicker("Preferred foot", key: "player_foot_id")
                    Divider().padding(.leading, 16)
                    attributePicker("Morale", key: "player_morale_id")
                }
            }.background(AppTheme.panel, in: RoundedRectangle(cornerRadius: AppTheme.panelRadius))
                .overlay(RoundedRectangle(cornerRadius: AppTheme.panelRadius).strokeBorder(Color.primary.opacity(0.08)))
            Text("New players start with skills of 10 and condition of 100%. Adjust them or randomize before saving.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private func normalizeAttributeChoices() {
        guard draft.kind == .player else { return }
        for key in ["player_foot_id", "player_morale_id"] {
            if draft.values[key, default: ""].isEmpty {
                draft.values[key] = attributeChoices[key]?.first?.id ?? ""
            }
        }
    }
    private func attributePicker(_ label: String, key: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Picker(label, selection: Binding(get: { draft.values[key] ?? "" }, set: { draft.values[key] = $0; error = nil })) {
                Text("Choose…").tag("")
                ForEach(attributeChoices[key] ?? []) { choice in Text(choice.name).tag(choice.id) }
            }.labelsHidden().frame(width: 200).accessibilityLabel(label)
        }.padding(16)
            .help((attributeChoices[key] ?? []).isEmpty ? "No options in \(key == "player_foot_id" ? "player_foot" : "player_morale"). Populate the table first." : "Options come from the database.")
    }
    private var editorBodyHeight: CGFloat {
        let fields = CGFloat(draft.kind.fields.count) * 68
        return min(470, fields + 90 + (draft.kind.assignment == nil ? 0 : 150))
    }
    private var teamPreview: some View {
        let name = (draft.values["team_name"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let cityID = Int(draft.values["city_id"] ?? "")
        let cityName = records[.city]?.first { $0.id == cityID }?.title
        let championshipName = records[.championship]?.first { String($0.id) == draft.assignment }?.title
        let year = (draft.values["team_foundation_date"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return HStack(spacing: 16) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 56, height: 56)
                .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(name.isEmpty ? "New team" : name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(name.isEmpty ? .secondary : Color.primary)
                if let cityName {
                    Label(cityName, systemImage: "mappin.and.ellipse").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Choose a city to place the club.").font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 10) {
                    if !year.isEmpty { Text("Founded \(year)").font(.caption).foregroundStyle(.secondary) }
                    if let championshipName {
                        Label(championshipName, systemImage: "trophy").font(.caption).foregroundStyle(AppTheme.accent)
                    } else {
                        Text("Unassigned league").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(16)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: AppTheme.panelRadius))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.panelRadius).strokeBorder(Color.primary.opacity(0.08)))
    }

    private func cancel() {
        if isDirty { confirmDiscard = true } else { dismiss() }
    }
    private func save() {
        attemptedSave = true
        guard draft.validation == nil else {
            if draft.kind == .player {
                playerSection = "Details"
                if PlayerAttributes.validation(draft.values) != nil {
                    let invalidPhysical = PlayerAttributes.physical.contains { attribute in
                        guard let number = Int(draft.values[attribute.id] ?? "") else { return true }
                        return !attribute.range.contains(number)
                    }
                    playerSection = invalidPhysical ? "Physical" : "Mental"
                }
            }
            if let empty = draft.kind.fields.first(where: { (draft.values[$0.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                focusedField = empty.id
            }
            return
        }
        do { try onSave(draft); dismiss() } catch { self.error = error.localizedDescription }
    }
    private func binding(_ field: RecordField) -> Binding<String> {
        Binding(get: { draft.values[field.id] ?? "" }, set: { draft.values[field.id] = $0; error = nil })
    }
    private func fieldRow(_ field: RecordField) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(field.label).font(.callout).frame(width: 120, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                fieldControl(field)
                if case .iso = field.type {
                    Text("Three letters, for example ITA or KEN.").font(.caption).foregroundStyle(.secondary)
                }
                if case .relation(let target) = field.type, (records[target] ?? []).isEmpty {
                    Text("Create a \(target.singular.lowercased()) in \(target.title) first.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(16)
    }
    @ViewBuilder private func fieldControl(_ field: RecordField) -> some View {
        switch field.type {
        case .relation(let kind):
            Picker(field.label, selection: binding(field)) {
                Text("Choose \(field.label.lowercased())…").tag("")
                ForEach(records[kind] ?? []) { record in Text(record.title).tag(String(record.id)) }
            }.labelsHidden().controlSize(.large)
                .accessibilityLabel(field.label)
        case .date:
            DatePicker(field.label, selection: Binding(get: {
                RecordDraft.dateFormatter.date(from: draft.values[field.id] ?? "") ?? Date()
            }, set: { draft.values[field.id] = RecordDraft.dateFormatter.string(from: $0); error = nil }), in: ...Date(), displayedComponents: .date)
                .labelsHidden().controlSize(.large)
                .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                .accessibilityLabel(field.label)
        default:
            TextField(placeholder(field), text: binding(field))
                .labelsHidden().textFieldStyle(.roundedBorder).controlSize(.large)
                .focused($focusedField, equals: field.id)
                .accessibilityLabel(field.label).accessibilityIdentifier(field.id)
        }
    }
    private func placeholder(_ field: RecordField) -> String {
        switch field.type {
        case .iso: "e.g. ITA"
        case .number: "Enter a number"
        default: "Enter \(field.label.lowercased())"
        }
    }
}

struct FakeDataSheet: View {
    let kind: RecordKind
    let url: URL
    let onComplete: (GenerationReport) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var countText = "10"
    private var count: Int { Int(countText) ?? 0 }
    @State private var includeSquads = true
    @State private var useRealPlayers = true
    @State private var selectedNationalities: Set<String> = []
    @State private var busy = false
    private var availableNationalities: [(iso: String, name: String)] {
        let countries = (try? CountryCatalog.load()) ?? []
        let teamISOs = Set((try? CSVTeam.load().map(\.country)) ?? [])
        return countries.filter { teamISOs.contains($0.iso3) }.map { (iso: $0.iso3, name: $0.name) }.sorted { $0.name < $1.name }
    }
    @State private var error: String?
    private var explanation: String {
        switch kind {
        case .country: "Uses country names and ISO codes from countries.csv."
        case .city: "Preserves all countries and existing data. Adds at least one city to every country that has none, then distributes any extra cities across countries. If no countries exist, imports the country catalog first."
        case .championship: "Uses existing countries, or selects a country from countries.csv if needed."
        case .stadium: "Uses existing cities, or creates a placeholder city with a country from countries.csv."
        case .team: "Uses team_details.csv for club names, countries and available leagues. Squads use 22 matching player_profiles.csv records. Missing cities, foundation years and leagues use generated placeholders."
        case .player: "Adds players to the smallest squads first, using CSV names, birth dates, positions and known preferred feet. Skills, condition and morale are randomized. Creates a team, league, city and country if needed."
        case .tactic: "Creates additional tactic profiles."
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                EntityBadge(kind: kind, size: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(kind == .team ? "Generate teams" : "Generate fake \(kind.title.lowercased())").font(.system(size: 24, weight: .bold, design: .rounded))
                    Text(kind == .city ? "Add cities across all countries." : "Replace the database world with a fresh set of records.").foregroundStyle(.secondary)
                }
            }
            Divider()
            HStack {
                Text(kind == .city ? "Minimum new cities" : "Number of \(kind.title.lowercased())")
                Spacer()
                TextField("Count", text: $countText)
                    .textFieldStyle(.roundedBorder).frame(width: 70).accessibilityLabel("Number of records")
                Stepper("Number of records", value: Binding(get: { min(100, max(1, count)) }, set: { countText = String($0) }), in: 1...100).labelsHidden().fixedSize()
            }
            Text("Choose between 1 and 100 records.").font(.caption).foregroundStyle(.secondary)
            if kind == .team {
                Toggle("Create a 22-player squad for each team", isOn: $includeSquads)
                if includeSquads {
                    Toggle("Use real club players for squads", isOn: $useRealPlayers)
                        .help("When enabled, players come from player_profiles.csv for the selected club. When disabled, players are chosen randomly from all profiles.")
                    Text(useRealPlayers ? "Players are taken from the real club's squad in player_profiles.csv." : "Players are chosen randomly from all available profiles.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("\(count) teams + \(includeSquads ? min(100, max(0, count)) * 22 : 0) players")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Text("Nationalities").font(.caption.bold())
                    Spacer()
                    Button(selectedNationalities.isEmpty ? "All selected" : "Clear selection") {
                        selectedNationalities.removeAll()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(selectedNationalities.isEmpty ? .secondary : AppTheme.accent)
                    .disabled(selectedNationalities.isEmpty)
                }.padding(.top, 4)
                if availableNationalities.isEmpty {
                    Text("No nationality data is available.").font(.caption).foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], alignment: .leading, spacing: 8) {
                            ForEach(availableNationalities, id: \.iso) { item in
                                let selected = selectedNationalities.contains(item.iso)
                                Button {
                                    if selected { selectedNationalities.remove(item.iso) } else { selectedNationalities.insert(item.iso) }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                            .font(.caption)
                                        Text(item.name)
                                            .font(.callout.weight(selected ? .semibold : .medium))
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 7)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundStyle(selected ? AppTheme.background : Color.primary)
                                    .background(selected ? AppTheme.accent : AppTheme.panel, in: Capsule())
                                    .overlay(Capsule().strokeBorder(Color.primary.opacity(selected ? 0 : 0.12)))
                                }.buttonStyle(.plain)
                                    .accessibilityLabel(item.name)
                                    .accessibilityAddTraits(selected ? .isSelected : [])
                            }
                        }.padding(2)
                    }.frame(height: 150)
                        .background(AppTheme.panel.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.08)))
                }
                Text(selectedNationalities.isEmpty ? "All nationalities" : "\(selectedNationalities.count) of \(availableNationalities.count) selected")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text(explanation).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Label(kind == .city ? "More cities may be created than requested so every country has at least one. Existing records are preserved." : "Replaces all players, teams, leagues, stadiums, countries, cities and manager records. Position, foot and morale options and saved careers are preserved.", systemImage: kind == .city ? "info.circle" : "exclamationmark.triangle")
                .font(.callout).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            Text("Only the selected dataset and its required dependencies are generated. If generation fails, the previous database is restored automatically.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("Countries, teams and players use your CSV catalogs. Skills, morale, missing feet and unavailable club details are generated.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let error { Text(error).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
            Divider()
            HStack {
                if busy { ProgressView().controlSize(.small); Text("Generating…").font(.callout) }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).disabled(busy)
                Button(kind == .city ? "Generate cities" : "Replace all data and generate") {
                    busy = true
                    Task { @MainActor in
                        await Task.yield()
                        do {
                            let report = try FootballDatabase(url: url, writable: true).generate(kind, count: count, includeSquads: includeSquads, replaceAll: true, nationalities: Array(selectedNationalities), realSquads: useRealPlayers)
                            onComplete(report)
                            dismiss()
                        } catch { self.error = error.localizedDescription; busy = false }
                    }
                }.gamePrimaryAction().keyboardShortcut(.defaultAction)
                    .disabled(busy || !(1...100).contains(count))
            }
        }.padding(24).frame(width: 510)
            .background(AppTheme.background).preferredColorScheme(.dark).tint(AppTheme.accent)
            .interactiveDismissDisabled(busy)
            .onAppear { countText = kind == .player ? "40" : kind == .team ? "8" : "10" }
    }
}
