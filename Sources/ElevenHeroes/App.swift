import SwiftUI
import UniformTypeIdentifiers

@MainActor final class AppLifecycle: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // A Swift Package executable can start without a regular GUI activation policy.
        // A visible window alone does not make it eligible to receive keyboard events.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

@main struct ElevenHeroesApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycle.self) private var appDelegate
    @State private var store = GameStore()
    var body: some Scene {
        WindowGroup {
            ContentView(store: store).frame(minWidth: 1040, minHeight: 700).preferredColorScheme(.dark)
        }.defaultSize(width: 1320, height: 850)
        .commands { CommandGroup(replacing: .newItem) { Button("Import Football Database…") { store.importing = true }.keyboardShortcut("o")
            Button("Load Career…") { store.loadingCareer = true }.keyboardShortcut("o", modifiers: [.command, .shift])
            Button("Manage Database…") { store.openDatabaseManager() }.keyboardShortcut("d", modifiers: [.command, .shift]) } }

    }
}


struct ContentView: View {
    @Bindable var store: GameStore
    @State private var settingTicketPrice = false
    @State private var initialTicketPrice = 10
    @State private var initialMatchParameters = MatchSimulationParameters.default
    @State private var newCareer = false
    @State var viewedPlayer: Footballer?
    @State var viewedSeason: CompletedSeason?
    @State var viewedTeam: Club?
    @State var careerPreview: Club?
    @State private var confirmingNewCareer = false
    private var gameContent: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                GameBrand().padding(.bottom, 45)
                Text("MANAGER'S OFFICE").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary).tracking(2).padding(.bottom, 16)
                ForEach([("Overview", "square.grid.2x2"),("Squad", "person.3"),("Market", "arrow.left.arrow.right"),("Match Centre", "sportscourt"),("League Table", "list.number"),("Stadium", "building.2"),("Training", "figure.run")], id: \.0) { title, icon in
                    Button { viewedSeason = nil; viewedPlayer = nil; viewedTeam = nil; store.screen = title } label: {
                        Label(title, systemImage: icon).font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity, alignment: .leading).padding(14)
                            .background(store.screen == title ? AppTheme.accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(store.screen == title ? AppTheme.accent : .secondary)
                    }.buttonStyle(.plain).padding(.bottom, 5)
                }
                Spacer()
                if let s = store.season {
                    Text(s.demo ? "FICTIONAL LEAGUE" : "DATABASE LEAGUE").font(.system(size: 10, weight: .bold)).tracking(1.4).foregroundStyle(AppTheme.accent)
                    teamLink(s.selectedClub).font(.headline).padding(.top, 8)
                    Text("Season \(s.yearLabel) · Local career").font(.caption).foregroundStyle(.secondary)
                }
                Divider().padding(.vertical, 20)
                Button("Manage database…", systemImage: "externaldrive.badge.person.crop") { store.openDatabaseManager() }.buttonStyle(.plain).padding(.bottom, 16)
                Button("Import database…", systemImage: "externaldrive") { store.importing = true }.buttonStyle(.plain)
                Button("New career", systemImage: "plus.circle") { careerPreview = nil; store.prepareCareer(); newCareer = true }.buttonStyle(.plain).padding(.top, 16)
                Button("Load career…", systemImage: "folder") { loadCareer() }.buttonStyle(.plain).padding(.top, 16)
            }.padding(24).frame(width: 230).background(Color.black.opacity(0.18))
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack {
                        Text("CLUB FOOTBALL / \(store.screen.uppercased())").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(.secondary)
                        Spacer()
                        Label("LOCAL SAVE", systemImage: "checkmark.circle").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                    }
                    if let archived = viewedSeason {
                        SeasonHistoryView(season: archived, fallbackClubs: store.season?.clubs ?? [], career: store.season) { viewedSeason = nil }
                    } else if let player = viewedPlayer {
                        PlayerDetailView(player: player, career: store.season, teamName: store.name(store.season?.selectedClub ?? 0), backLabel: "Back to squad", onTeam: {
                            viewedPlayer = nil; viewedTeam = nil; store.screen = "Squad"
                        }, onOfferRenewal: { wage, years in
                            guard var season = store.season, let player = viewedPlayer else { return }
                            if let clubIndex = season.clubs.firstIndex(where: { $0.id == season.selectedClub }),
                               let playerIndex = season.clubs[clubIndex].players.firstIndex(where: { $0.id == player.id }) {
                                let newEnd = (season.clubs[clubIndex].players[playerIndex].contractEndDate ?? season.year) + years
                                season.clubs[clubIndex].players[playerIndex].contractEndDate = newEnd
                                season.clubs[clubIndex].players[playerIndex].salary = wage
                                store.season = season
                                store.save()
                            }
                            viewedPlayer = nil
                        }) { viewedPlayer = nil }
                    } else if let club = viewedTeam {
                        TeamDetailView(club: club, career: store.season, context: "Current career", backLabel: "Back to \(store.screen.lowercased())") { viewedTeam = nil }
                    } else if let season = store.season {
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 12) {
                                    if store.screen == "Squad" {
                                        let club = season.clubs.first { $0.id == season.selectedClub }
                                        Group {
                                            if let logo = club.flatMap({ CSVTeam.logo(for: $0.name) }), let url = URL(string: logo) {
                                                AsyncImage(url: url) { phase in
                                                    switch phase {
                                                    case .success(let image): image.resizable().scaledToFit()
                                                    default: Image(systemName: "shield.lefthalf.filled").font(.system(size: 35)).foregroundStyle(AppTheme.accent)
                                                    }
                                                }
                                            } else {
                                                Image(systemName: "shield.lefthalf.filled").font(.system(size: 35)).foregroundStyle(AppTheme.accent)
                                            }
                                        }.frame(width: 44, height: 44)
                                    }
                                    Text(store.screen == "Market" ? "Transfer market" : store.screen == "Squad" ? store.name(season.selectedClub) : store.screen == "Overview" ? "Every match. Your story." : store.screen == "Match Centre" ? matchCentreTitle(season) : store.screen).font(.system(size: 35, weight: .bold, design: .rounded))
                                }
                                Text(store.screen == "Market" ? "Build your squad. Make every credit count." : season.finished ? "Season \(season.yearLabel) complete. Ready for the next chapter." : "Season \(season.yearLabel) · Matchweek \(season.round) · \(store.name(season.selectedClub))").foregroundStyle(.secondary)
                            }
                            Spacer()
                            if season.finished && store.screen != "Market" {
                                Button { settingTicketPrice = true } label: {
                                    Label("Start season \(String(season.year + 1))", systemImage: "play.fill")
                                        .padding(.horizontal, 9).padding(.vertical, 7)
                                }
                                    .buttonStyle(.borderedProminent).tint(AppTheme.accent).foregroundStyle(AppTheme.background)
                                    .help("Keep your squad and budget. Players age one year and a new fixture schedule begins.")
                            }
                            if !season.finished && store.screen != "Market" {
                                Button(action: store.play) { Label("Play matchweek", systemImage: "play.fill").padding(.horizontal, 9).padding(.vertical, 7) }
                                    .buttonStyle(.borderedProminent).tint(AppTheme.accent).foregroundStyle(AppTheme.background).disabled(season.lineup.count != 11 || season.replacementsNeeded > 0 || season.goalkeepersNeeded > 0)
                            }
                        }
                        switch store.screen {
                        case "Squad": squad(season)
                        case "League Table": league(season)
                        case "Match Centre": matches(season)
                        case "Market": MarketView(store: store)
                        case "Stadium": StadiumView(store: store)
                        case "Training": training(season)
                        default: overview(season)
                        }
                    } else { onboarding }
                }.padding(36)
            }
        }.background(AppTheme.background)
    }
    var body: some View {
        Group {
            if store.managingDatabase {
                DatabaseManagerView(url: store.databaseURL, onBack: store.returnToMainPage)
            } else {
                gameContent
            }
        }
        .alert("Eleven Heroes", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("OK") { store.error = nil } } message: { Text(store.error ?? "") }
        .sheet(isPresented: $settingTicketPrice) {
            if let season = store.season {
                SeasonTicketSetupView(year: season.year + 1, price: season.homeTicketPrice, parameters: season.matchParameters ?? .default, onStart: { price, parameters in store.startNextSeason(ticketPrice: price, matchParameters: parameters) })
            }
        }
        .sheet(isPresented: $newCareer) { VStack { onboarding; Button("Cancel") { careerPreview = nil; store.prepareCareer(); newCareer = false }.keyboardShortcut(.cancelAction) }.padding(30).frame(width: 650, height: 820) }
        .onChange(of: store.managingDatabase) { _, requested in
            if requested { newCareer = false }
        }
        .onChange(of: store.loadingCareer) { _, requested in
            if requested { store.loadingCareer = false; loadCareer() }
        }
        .fileImporter(isPresented: $store.importing, allowedContentTypes: [.database, .data]) { result in
            do {
                let url = try result.get(); let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                if store.loadDatabase(url) { store.managingDatabase = false; newCareer = true }
            } catch { store.error = error.localizedDescription }
        }
    }
    var onboarding: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let club = careerPreview {
                ScrollView {
                    TeamDetailView(club: club, backLabel: "Back to clubs") { careerPreview = nil }
                }
                TicketPriceEditor(price: $initialTicketPrice)
                Text("1–100 credits per home ticket · Fixed for the season").font(.caption).foregroundStyle(.secondary)
                MatchParametersEditor(parameters: $initialMatchParameters)
                Button("Start career with \(club.name)") {
                    if store.season != nil { confirmingNewCareer = true }
                    else { startCareer(club.id) }
                }.gamePrimaryAction().disabled(!(1...100).contains(initialTicketPrice))
                .alert("Save your current career?", isPresented: $confirmingNewCareer) {
                    Button("Save and Continue…") {
                        let panel = NSSavePanel()
                        panel.title = "Save current career"
                        panel.allowedContentTypes = [.json]
                        panel.nameFieldStringValue = "Career-\(UUID().uuidString.prefix(8)).json"
                        guard panel.runModal() == .OK, let url = panel.url else { return }
                        guard url.resolvingSymlinksInPath().standardizedFileURL != store.saveURL.resolvingSymlinksInPath().standardizedFileURL else {
                            store.error = "Choose a different file from the active season.json so your career is preserved."
                            return
                        }
                        if store.save(to: url) { startCareer(club.id) }
                    }
                    Button("Continue Without Saving", role: .destructive) { startCareer(club.id) }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Starting a new career replaces the current autosave. Save a separate copy to keep your current career.")
                }
                if store.season != nil { Text("You’ll have the option to save your current career before starting.").font(.caption).foregroundStyle(.secondary) }
            } else if store.available.isEmpty {
                Image(systemName: "soccerball").font(.system(size: 40)).foregroundStyle(AppTheme.accent)
                Text("Start a new career").font(.largeTitle.bold())
                Text("Would you like to generate fictional clubs and players?")
                    .font(.title3).fixedSize(horizontal: false, vertical: true)
                Text("Create a ready-to-play league with 8 clubs and 160 players, with fresh squads and ratings for this career.")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button("Generate fictional data", systemImage: "sparkles") {
                    store.generateCareerData()
                }.buttonStyle(.borderedProminent).tint(AppTheme.accent).foregroundStyle(AppTheme.background).controlSize(.large)
                Divider()
                Label("Use your football database", systemImage: "externaldrive").font(.headline)
                if store.databaseClubs.isEmpty {
                    Text("Your database has no clubs yet. Use Manage database in the sidebar to add them, or import a populated database.")
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                } else {
                    Button("Use database clubs (\(store.careerReadyClubs.count) ready)") { store.useDatabase() }
                        .controlSize(.large)
                }
                if !store.incompleteClubs.isEmpty {
                    Text("Excluded until they have 11 players: " + store.incompleteClubs.map { "\($0.name) (\($0.players.count)/11)" }.joined(separator: ", "))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(3)
                        .help(store.incompleteClubs.map { "\($0.name): \($0.players.count)/11 players" }.joined(separator: "\n"))
                    Button("Manage database…") { store.openDatabaseManager() }
                }
                Button("Import database…") { store.importing = true }
                Text("Your current career stays saved until you choose a club. Generated data is saved with the career; your database is unchanged.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                HStack {
                    Button { store.prepareCareer() } label: { Label("Data source", systemImage: "chevron.left") }
                    Spacer()
                    Text(store.isDemo ? "Fictional league" : "Database league").foregroundStyle(.secondary)
                }
                Text("Choose your club").font(.largeTitle.bold())
                Text(store.isDemo ? "Your fictional league is ready. Choose a club to begin." : "Choose a club from your database to begin.").foregroundStyle(.secondary)
                if store.season != nil {
                    Text("Choosing a club replaces your current saved career.").font(.callout).foregroundStyle(.orange)
                }
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(store.available) { club in
                            Button { careerPreview = club } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    Image(systemName: "shield.lefthalf.filled").font(.title2).foregroundStyle(AppTheme.accent)
                                    Text(club.name).font(.headline)
                                    Text("\(club.players.count) players · \(Int(club.strength)) OVR").font(.caption).foregroundStyle(.secondary)
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
                            }.buttonStyle(.bordered).tint(AppTheme.accent)
                        }
                    }
                }.frame(height: 360)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func loadCareer() {
        let panel = NSOpenPanel()
        panel.title = "Load career"
        panel.message = "Choose a saved career. Your current career will be backed up in the Careers folder before loading."
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        let backups = store.saveURL.deletingLastPathComponent().appending(path: "Careers")
        if FileManager.default.fileExists(atPath: backups.path) { panel.directoryURL = backups }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        if store.loadCareer(url) {
            viewedSeason = nil
            viewedPlayer = nil
            viewedTeam = nil
            careerPreview = nil
            newCareer = false
        }
    }
    private func startCareer(_ id: Int) {
        guard store.start(id, ticketPrice: initialTicketPrice, matchParameters: initialMatchParameters) else { return }
        viewedSeason = nil
        viewedPlayer = nil
        careerPreview = nil
        viewedTeam = nil
        newCareer = false
    }
    func showTeam(_ id: Int) {
        viewedSeason = nil
        viewedPlayer = nil
        viewedTeam = store.season?.clubs.first { $0.id == id }
    }
    func teamLink(_ id: Int) -> some View {
        Button(store.name(id)) { showTeam(id) }
            .buttonStyle(.plain).help("View team and squad")
    }
    func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title.uppercased()).font(.system(size: 11, weight: .bold)).tracking(1.7).foregroundStyle(.secondary)
            content()
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 14))
    }
    func matchCentreTitle(_ season: Season) -> String {
        let fixture = season.fixtures.first { $0.round == season.round - 1 && $0.homeGoals != nil && ($0.home == season.selectedClub || $0.away == season.selectedClub) }
            ?? season.fixtures.first { $0.round == season.round && ($0.home == season.selectedClub || $0.away == season.selectedClub) }
        guard let fixture else { return "Match Centre" }
        let home = season.clubs.first { $0.id == fixture.home }?.name ?? "Squad 1"
        let away = season.clubs.first { $0.id == fixture.away }?.name ?? "Squad 2"
        return "\(home) vs \(away)"
    }

}
