import SwiftUI

struct DatabaseManagerView: View {
    let url: URL
    let onBack: () -> Void
    @State private var kind: RecordKind = .country
    @State private var records: [RecordKind: [DatabaseRecord]] = [:]
    @State private var attributeChoices: [String: [AttributeChoice]] = [:]
    @State private var search = ""
    @State private var confirmClear = false
    @State private var viewedPlayer: Footballer?
    @State private var playerTeamName = ""
    @State private var playerTeam: Club?
    @State private var viewedCountry: DatabaseRecord?
    @State private var viewedChampionship: DatabaseRecord?
    @State private var championshipTeams: [Club] = []
    @State private var viewedTeam: Club?
    @State private var teamContext = ""
    @State private var deleting: DatabaseRecord?
    @State private var deletingKind: RecordKind = .country
    @State private var editing: EditorSelection?
    @State private var error: String?
    @State private var status = ""
    @State private var generating: RecordKind?

    private struct EditorSelection: Identifiable {
        let id = UUID()
        var draft: RecordDraft
    }
    private var filtered: [DatabaseRecord] {
        (records[kind] ?? []).filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                GameBrand().padding(.bottom, 24)
                Button(action: onBack) {
                    Label("Back to main page", systemImage: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain).keyboardShortcut("[", modifiers: .command)
                    .padding(.bottom, 16)
                SectionCaption("Football database").padding(.bottom, 16)
                ForEach([RecordKind.player, .team, .championship, .stadium]) { item in
                    sidebarRow(item)
                }
                SectionCaption("Places").padding(.top, 24).padding(.bottom, 16)
                ForEach([RecordKind.country, .city]) { item in sidebarRow(item) }
                Spacer(minLength: 24)
                Divider().padding(.bottom, 16)
                Button("Clear database…", systemImage: "trash", role: .destructive) { confirmClear = true }
                    .buttonStyle(.plain).padding(.bottom, 16)
                Label("Local database", systemImage: "externaldrive")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(24).frame(width: 230)
                .frame(maxHeight: .infinity)
                .background(Color.black.opacity(0.18))
            Divider()
            if let player = viewedPlayer {
                ScrollView {
                    PlayerDetailView(player: player, teamName: playerTeamName, backLabel: "Back to players", onTeam: playerTeam.map { club in
                        { viewedPlayer = nil; viewedTeam = club; teamContext = "" }
                    }) { viewedPlayer = nil }.padding(28)
                }
            } else if let club = viewedTeam {
                ScrollView {
                    TeamDetailView(club: club, context: teamContext, backLabel: "Back to teams") { viewedTeam = nil }
                        .padding(28)
                }
            } else if let championship = viewedChampionship {
                ScrollView {
                    ChampionshipDetailView(championship: championship, teams: championshipTeams,
                        country: records[.country]?.first { String($0.id) == championship.values["country_id"] }?.title ?? "",
                        backLabel: viewedCountry == nil ? "Back to leagues" : "Back to country") {
                            viewedChampionship = nil
                        }.padding(28)
                }
            } else if let country = viewedCountry {
                ScrollView {
                    CountryDetailView(country: country,
                        leagues: (records[.championship] ?? []).filter { $0.values["country_id"] == String(country.id) },
                        onLeague: showChampionship) { viewedCountry = nil }.padding(28)
                }
            } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    SectionCaption("Club football / Database")
                    Spacer()
                    Label("LOCAL DATA", systemImage: "externaldrive")
                        .font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                }.padding(.horizontal, 28).padding(.top, 28)
                HStack(alignment: .center, spacing: 14) {
                    EntityBadge(kind: kind, size: 46)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kind.title).font(.system(size: 35, weight: .bold, design: .rounded))
                        Text("\(records[kind]?.count ?? 0) records · Available to new careers")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 10) {
                        Button { editing = EditorSelection(draft: RecordDraft(kind: kind)) } label: {
                            Label("Add \(kind.singular.lowercased())", systemImage: "plus")
                        }.gamePrimaryAction().controlSize(.large)
                        Button("Generate data…", systemImage: "sparkles") { generating = kind }
                            .buttonStyle(.borderless)
                    }
                }.padding(24)
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search \(kind.title.lowercased())", text: $search)
                        .textFieldStyle(.plain).accessibilityLabel("Search \(kind.title.lowercased())")
                    if !search.isEmpty {
                        Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Clear search")
                    }
                }.padding(10).background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.10)))
                    .padding(.horizontal, 24).padding(.bottom, 16)
                if filtered.isEmpty {
                    ContentUnavailableView {
                        Label(search.isEmpty ? "Add your first \(kind.singular.lowercased())" : "No matching records", systemImage: kind.icon)
                    } description: {
                        Text(search.isEmpty ? emptyDescription : "Try a different name or clear your search.")
                    } actions: {
                        if search.isEmpty {
                            Button("Add \(kind.singular.lowercased())") { editing = EditorSelection(draft: RecordDraft(kind: kind)) }
                        } else { Button("Clear search") { search = "" } }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filtered) { record in
                        HStack(spacing: 12) {
                            EntityBadge(kind: kind, size: 32)
                            VStack(alignment: .leading, spacing: 4) {
                                if kind == .team {
                                    Button(record.title) { showTeam(record) }
                                        .buttonStyle(.plain).foregroundStyle(AppTheme.accent)
                                        .font(.body.weight(.medium)).help("View team and squad")
                                } else if kind == .player {
                                    Button(record.title) { showPlayer(record) }.buttonStyle(.plain).foregroundStyle(AppTheme.accent).font(.body.weight(.medium)).help("View player profile")
                                } else if kind == .championship {
                                    Button(record.title) { showChampionship(record) }.buttonStyle(.plain).foregroundStyle(AppTheme.accent).font(.body.weight(.medium)).help("View league teams")
                                } else if kind == .country {
                                    Button(record.title) { viewedCountry = record }.buttonStyle(.plain).foregroundStyle(AppTheme.accent).font(.body.weight(.medium)).help("View country leagues")
                                } else { Text(record.title).font(.body.weight(.medium)) }
                                Text(detail(record)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button { edit(record) } label: { Image(systemName: "pencil") }
                                .buttonStyle(.borderless).help("Edit \(record.title)")
                                .accessibilityLabel("Edit \(record.title)")
                            Button(role: .destructive) { deletingKind = kind; deleting = record } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless).help("Delete \(record.title)").accessibilityLabel("Delete \(record.title)")
                        }.padding(.vertical, 10)
                            .listRowBackground(AppTheme.panel)
                            .contextMenu {
                                Button("Edit…") { edit(record) }
                                Button("Delete…", role: .destructive) { deletingKind = kind; deleting = record }
                            }
                    }.listStyle(.inset).scrollContentBackground(.hidden).padding(.horizontal, 12)
                }
                Divider()
                HStack {
                    if !status.isEmpty {
                        Label(status, systemImage: "checkmark.circle.fill").foregroundStyle(.secondary)
                    } else { Text("Changes are saved when you select Save.").foregroundStyle(.secondary) }
                    Spacer()
                    Text(url.lastPathComponent).foregroundStyle(.tertiary).help(url.path)
                }.font(.caption).padding(.horizontal, 24).padding(.vertical, 12)
            }.background(AppTheme.background)
            }
        }
        .background(AppTheme.background)
        .preferredColorScheme(.dark)
        .tint(AppTheme.accent)
        .frame(minWidth: 900, idealWidth: 980, minHeight: 580, idealHeight: 700)
        .onAppear(perform: reload)
        .onChange(of: kind) { _, _ in search = ""; status = "" }
        .sheet(item: $editing) { selection in
            RecordEditor(draft: selection.draft, records: records, attributeChoices: attributeChoices) { draft in
                let database = try FootballDatabase(url: url, writable: true)
                try database.save(draft)
                status = "\(draft.kind.singular) saved"
                reload()
            }
        }
        .sheet(item: $generating) { selected in
            FakeDataSheet(kind: selected, url: url) { report in
                search = ""
                status = report.summary
                reload()
            }
        }
        .confirmationDialog("Clear all database records?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear database", role: .destructive) { clearDatabase() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Deletes all players, teams, leagues, countries, cities, stadiums, managers, skills, statistics and assignments. Position, foot and morale options are kept. Saved careers are unchanged. This cannot be undone.")
        }
        .confirmationDialog("Delete \(deleting?.title ?? "record")?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible, presenting: deleting) { record in
            Button("Delete \(deletingKind.singular.lowercased())", role: .destructive) { deleteRecord(record) }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: { _ in
            Text(deletionMessage + " This cannot be undone. Existing saved careers are unchanged.")
        }
        .alert("Database unavailable", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }
    private func clearDatabase() {
        do {
            try FootballDatabase(url: url, writable: true).clearWorld()
            viewedCountry = nil; viewedChampionship = nil; viewedTeam = nil; viewedPlayer = nil
            search = ""
            status = "Database cleared. Position, foot and morale options preserved."
            reload()
        } catch { self.error = error.localizedDescription }
    }
    private var deletionMessage: String {
        switch deletingKind {
        case .player: "This removes the player, team assignments, skills and statistics."
        case .team: "This removes the team and its assignments. Its players remain in the database."
        case .championship: "This removes the league and its team assignments. Teams and players remain."
        case .country, .city: "This record can only be removed when no other records use it."
        case .stadium: "This removes the stadium from the database."
        case .tactic: "This removes the tactic from the database."
        }
    }
    private func deleteRecord(_ record: DatabaseRecord) {
        do {
            try FootballDatabase(url: url, writable: true).delete(deletingKind, id: record.id)
            status = "\(record.title) deleted"
            reload()
        } catch { self.error = error.localizedDescription }
        deleting = nil
    }
    private func showPlayer(_ record: DatabaseRecord) {
        do {
            let database = try FootballDatabase(url: url)
            let assignment = try database.assignment(for: record, kind: .player)
            let club = try Database.load(url).first { String($0.id) == assignment }
            playerTeamName = club?.name ?? "Unassigned"
            playerTeam = club
            viewedPlayer = try club?.players.first { $0.id == record.id }
                ?? database.marketSnapshot().first { $0.id == record.id }?.player
        } catch { self.error = error.localizedDescription }
    }
    private func showChampionship(_ record: DatabaseRecord) {
        do {
            let ids = try FootballDatabase(url: url).teamIDs(inChampionship: record.id)
            championshipTeams = try Database.load(url).filter { ids.contains($0.id) }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            viewedChampionship = record
        } catch { self.error = error.localizedDescription }
    }
    private func showTeam(_ record: DatabaseRecord) {
        do {
            let database = try FootballDatabase(url: url)
            let assignment = try database.assignment(for: record, kind: .team)
            let championship = records[.championship]?.first { String($0.id) == assignment }?.title
            teamContext = [record.values["team_foundation_date"].map { "Founded \($0)" }, championship].compactMap { $0 }.joined(separator: " · ")
            viewedTeam = try Database.load(url).first { $0.id == record.id }
        } catch { self.error = error.localizedDescription }
    }
    private func sidebarRow(_ item: RecordKind) -> some View {
        Button { viewedCountry = nil; viewedChampionship = nil; viewedPlayer = nil; viewedTeam = nil; kind = item } label: {
            HStack(spacing: 10) {
                Label(item.title, systemImage: item.icon)
                Spacer()
                Text("\(records[item]?.count ?? 0)").font(.caption).monospacedDigit()
            }
            .font(.system(size: 14, weight: .semibold))
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(kind == item ? AppTheme.accent : .secondary)
            .background(kind == item ? AppTheme.accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain).padding(.bottom, 5)
            .accessibilityAddTraits(kind == item ? .isSelected : [])
    }
    private var emptyDescription: String {
        switch kind {
        case .country: "Start with the countries your clubs and players call home."
        case .city: "Connect each city to a country, then use it for clubs, players and stadiums."
        case .player: "Build your squad with player profiles and team assignments."
        case .team: "Create a club, choose its home city and assign a league."
        case .championship: "Give your competition a name, a country and a league size."
        case .stadium: "Add the grounds where your football world comes to life."
        case .tactic: "Define the tactical profiles available to your clubs."
        }
    }
    private func reload() {
        do {
            let database = try FootballDatabase(url: url)
            var loaded: [RecordKind: [DatabaseRecord]] = [:]
            for type in RecordKind.allCases { loaded[type] = try database.records(type) }
            attributeChoices = try database.attributeChoices()
            records = loaded
        } catch { self.error = error.localizedDescription }
    }
    private func edit(_ record: DatabaseRecord) {
        do {
            var draft = RecordDraft(kind: kind, record: record)
            draft.assignment = try FootballDatabase(url: url).assignment(for: record, kind: kind)
            editing = EditorSelection(draft: draft)
        } catch { self.error = error.localizedDescription }
    }
    private func detail(_ record: DatabaseRecord) -> String {
        var parts: [String] = []
        for field in kind.fields {
            switch field.type {
            case .relation(let target):
                let id = Int(record.values[field.id] ?? "")
                if let match = records[target]?.first(where: { $0.id == id }) { parts.append(match.title) }
            case .iso: parts.append(record.values[field.id] ?? "")
            default: break
            }
        }
        if kind == .stadium, let seats = Int(record.values["stadium_seats"] ?? ""), seats > 0 {
            parts.append("\(seats.formatted()) seats")
        }
        return parts.isEmpty ? kind.singular : parts.joined(separator: " · ")
    }
}
