import SwiftUI
import UniformTypeIdentifiers
import Foundation

@MainActor @Observable final class GameStore {
    var season: Season?
    var error: String?
    var screen = "Overview"
    var available: [Club] = []
    var databaseClubs: [Club] = []
    var isDemo = false
    var importing = false
    var loadingCareer = false
    var managingDatabase = false
    var databaseURL: URL { saveURL.deletingLastPathComponent().appending(path: "db.sqlite") }
    let saveURL: URL
    init(saveURL: URL = URL.applicationSupportDirectory.appending(path: "ElevenHeroes/season.json")) {
        self.saveURL = saveURL
        if FileManager.default.fileExists(atPath: saveURL.path) {
            do {
                var loaded = try JSONDecoder().decode(Season.self, from: Data(contentsOf: saveURL))
                loaded.prepareCalendar()
                loaded.migrateSchema()
                let neededGoalkeepers = loaded.clubs.contains { $0.players.filter { $0.role == "GK" }.count < 2 }
                let previousRetirements = loaded.retiredPlayers?.count ?? 0
                loaded.retireIneligiblePlayers()
                if (loaded.retiredPlayers?.count ?? 0) != previousRetirements || neededGoalkeepers {
                    try JSONEncoder().encode(loaded).write(to: saveURL, options: .atomic)
                }
                season = loaded
            }
            catch { self.error = "Your saved season could not be read. \(error.localizedDescription)" }
        }
        prepareDatabase()
        if season?.demo == false, let count = season?.clubs.count {
            for index in 0..<count where season?.clubs[index].stadiumCapacity == nil {
                if let club = databaseClubs.first(where: { $0.id == season?.clubs[index].id }) {
                    season?.clubs[index].stadiumName = club.stadiumName
                    season?.clubs[index].stadiumCapacity = club.stadiumCapacity
                }
            }
        }
    }
    @discardableResult
    func prepareDatabase() -> Bool {
        do {
            if !FileManager.default.fileExists(atPath: databaseURL.path) {
                let legacy = databaseURL.deletingLastPathComponent().appending(path: "football.sqlite")
                let source = FileManager.default.fileExists(atPath: legacy.path) ? legacy : try Database.seedURL()
                try FootballDatabase.install(from: source, to: databaseURL)
            }
            // Verify read/write access before allowing the editor to open.
            try FootballDatabase(url: databaseURL, writable: true).synchronizeCountries()
            databaseClubs = try Database.load(databaseURL)
            return true
        } catch {
            self.error = "Database setup failed. \(error.localizedDescription)"
            return false
        }
    }
    func openDatabaseManager() {
        if prepareDatabase() { managingDatabase = true }
    }
    func returnToMainPage() {
        refreshDatabase()
        screen = "Overview"
        managingDatabase = false
        if !isDemo { available = [] }
    }
    @discardableResult
    func loadDatabase(_ url: URL) -> Bool {
        do {
            // Keep the previous working database recoverable after an import.
            if FileManager.default.fileExists(atPath: databaseURL.path), url.standardizedFileURL != databaseURL.standardizedFileURL {
                let backup = databaseURL.deletingLastPathComponent().appending(path: "football-backup-\(UUID().uuidString).sqlite")
                try FootballDatabase.copy(from: databaseURL, to: backup)
            }
            try FootballDatabase.install(from: url, to: databaseURL)
            try FootballDatabase(url: databaseURL, writable: true).synchronizeCountries()
            databaseClubs = try Database.load(databaseURL)
            prepareCareer()
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func refreshDatabase() {
        do { databaseClubs = try Database.load(databaseURL) }
        catch { self.error = error.localizedDescription }
    }
    var careerReadyClubs: [Club] { databaseClubs.filter { $0.players.count >= 11 } }
    var incompleteClubs: [Club] { databaseClubs.filter { $0.players.count < 11 } }
    func prepareCareer() {
        refreshDatabase()
        available = []
        isDemo = false
    }
    func generateCareerData() {
        var rng = SystemRandomNumberGenerator()
        available = Database.generateFictionalLeague(using: &rng)
        isDemo = true
    }
    func useDatabase() {
        available = []
        do { databaseClubs = try Database.load(databaseURL) }
        catch { self.error = error.localizedDescription; return }
        guard careerReadyClubs.count >= 2 else {
            error = "A career needs at least two teams with 11 assigned players each. Only \(careerReadyClubs.count) teams are ready. Add or assign players in Manage database before starting."
            return
        }
        error = nil
        available = careerReadyClubs
        isDemo = false
    }
    @discardableResult
    func start(_ id: Int, ticketPrice: Int = 10, matchParameters: MatchSimulationParameters? = nil) -> Bool {
        guard (1...100).contains(ticketPrice) else { error = "Ticket price must be between 1 and 100 credits."; return false }
        guard available.contains(where: { $0.id == id }) else { return false }
        var next = Season(clubs: available, fixtures: Season.schedule(available), selectedClub: id, demo: isDemo)
        if !isDemo {
            do { next.marketPlayers = try FootballDatabase(url: databaseURL).marketSnapshot() }
            catch { self.error = "Could not prepare the transfer market: \(error.localizedDescription)"; return false }
        }
        next.seasonYear = Calendar.current.component(.year, from: Date())
        next.prepareCalendar()
        next.ticketPrice = ticketPrice
        next.matchParameters = matchParameters
        // Give every player a contract end date when one is not already recorded.
        let currentYear = next.year
        for clubIndex in next.clubs.indices {
            for playerIndex in next.clubs[clubIndex].players.indices where next.clubs[clubIndex].players[playerIndex].contractEndDate == nil {
                next.clubs[clubIndex].players[playerIndex].contractEndDate = currentYear + [2, 3].randomElement()!
            }
        }
        var economyRNG = SystemRandomNumberGenerator()
        next.initializeEconomy(using: &economyRNG)
        next.retireIneligiblePlayers()
        next.creditBalance = 10_000
        for clubIndex in next.clubs.indices {
            let club = next.clubs[clubIndex]
            for playerIndex in club.players.indices where club.players[playerIndex].valueHistory?.isEmpty != false {
                next.clubs[clubIndex].players[playerIndex].recordValue(teamID: club.id, teamName: club.name, event: "Career started", matchweek: 1, seasonYear: next.year)
            }
        }
        season = next
        autoPick(); save(); screen = "Overview"
        return true
    }
    func autoPick() {
        guard let s = season, let club = s.clubs.first(where: { $0.id == s.selectedClub }) else { return }
        var picked: [Int] = []
        for (role,count) in [("GK",1),("DEF",4),("MID",4),("FWD",2)] {
            picked += club.players.filter { $0.role == role }.sorted { $0.rating > $1.rating }.prefix(count).map(\.id)
        }
        if picked.count < 11 { picked += club.players.filter { !picked.contains($0.id) }.sorted { $0.rating > $1.rating }.prefix(11-picked.count).map(\.id) }
        // Pick at most 5 substitutes: one goalkeeper plus four outfield players.
        var subs: [Int] = []
        let remaining = club.players.filter { !picked.contains($0.id) }
        if let goalkeeper = remaining.filter({ $0.role == "GK" }).sorted(by: { $0.rating > $1.rating }).first {
            subs.append(goalkeeper.id)
        }
        subs += remaining.filter { $0.role != "GK" && !subs.contains($0.id) }
            .sorted { $0.rating > $1.rating }
            .prefix(4)
            .map(\.id)
        if subs.count < 5 {
            subs += remaining.filter { !picked.contains($0.id) && !subs.contains($0.id) }
                .sorted { $0.rating > $1.rating }
                .prefix(5 - subs.count)
                .map(\.id)
        }
        season?.lineup = picked
        season?.substitutes = subs
        save()
    }
    func toggle(_ id: Int) {
        guard let s = season else { return }
        if s.lineup.contains(id) { season?.lineup.removeAll { $0 == id } }
        else if s.lineup.count < 11 { season?.lineup.append(id) }
        save()
    }
    func startNextSeason(ticketPrice: Int? = nil, matchParameters: MatchSimulationParameters? = nil) {
        guard var updated = season else { return }
        do {
            try updated.startNextSeason(ticketPrice: ticketPrice, matchParameters: matchParameters)
            try JSONEncoder().encode(updated).write(to: saveURL, options: .atomic)
            season = updated
            screen = "Overview"
        } catch { self.error = "Could not start next season: \(error.localizedDescription)" }
    }
    func play() {
        guard season?.goalkeepersNeeded == 0 else { error = "Buy enough goalkeepers to have at least two in your squad before playing."; return }
        guard season?.replacementsNeeded == 0 else { error = "Buy replacements for your retired players in Market before playing."; return }
        guard !(season?.clubs.flatMap(\.players).contains { $0.age(in: season?.year ?? 2026) >= 41 } ?? false) else {
            error = "This career contains players aged 41 or older. Start the next season to retire them."; return
        }
        guard season?.lineup.count == 11 else { error = "Select exactly 11 players before playing."; return }
        let previousRound = season?.round
        var rng = SystemRandomNumberGenerator(); season?.simulate(using: &rng)
        if season?.round != previousRound { season?.generateIncomingOffers(using: &rng) }
        save(); screen = "Match Centre"
    }
    @discardableResult
    func listPlayerForTransfer(_ id: Int) -> Bool { completeTransfer { try $0.listPlayerForTransfer(id) } }
    @discardableResult
    func acceptOffer(_ id: UUID) -> Bool { completeTransfer { try $0.acceptOffer(id) } }
    @discardableResult
    func rejectOffer(_ id: UUID) -> Bool { completeTransfer { try $0.rejectOffer(id) } }
    @discardableResult
    func buyPlayer(_ id: Int, offer: Int, salary: Int? = nil) -> Bool {
        completeTransfer { try $0.buyPlayer(id, offer: offer, salary: salary) }
    }
    @discardableResult
    func sellPlayer(_ id: Int) -> Bool {
        completeTransfer { try $0.sellPlayer(id) }
    }
    @discardableResult
    private func completeTransfer(_ transfer: (inout Season) throws -> Void) -> Bool {
        guard var updated = season else { return false }
        do {
            try transfer(&updated)
            try FileManager.default.createDirectory(at: saveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(updated).write(to: saveURL, options: .atomic)
            season = updated
            error = nil
            return true
        } catch {
            self.error = "Transfer failed: \(error.localizedDescription)"
            return false
        }
    }
    func save() {
        save(to: saveURL)
    }
    @discardableResult
    func save(to url: URL) -> Bool {
        guard let season else { return false }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(season).write(to: url, options: .atomic)
            return true
        } catch {
            self.error = "Could not save your season: \(error.localizedDescription)"
            return false
        }
    }
    @discardableResult
    func loadCareer(_ url: URL) -> Bool {
        do {
            var loaded = try JSONDecoder().decode(Season.self, from: Data(contentsOf: url))
            loaded.prepareCalendar()
                loaded.migrateSchema()
            let clubIDs = Set(loaded.clubs.map(\.id))
            guard clubIDs.count == loaded.clubs.count,
                  let club = loaded.clubs.first(where: { $0.id == loaded.selectedClub }),
                  loaded.round > 0,
                  Set(loaded.lineup).count == loaded.lineup.count,
                  loaded.lineup.count <= 11,
                  loaded.lineup.allSatisfy({ id in club.players.contains { $0.id == id } }),
                  Set(loaded.fixtures.map(\.id)).count == loaded.fixtures.count,
                  loaded.fixtures.allSatisfy({ clubIDs.contains($0.home) && clubIDs.contains($0.away) && $0.home != $0.away }) else {
                throw DatabaseIssue(message: "This file contains invalid career data.")
            }
            loaded.retireIneligiblePlayers()
            // Preserve the current career before replacing its autosave.
            if season != nil {
                let backup = saveURL.deletingLastPathComponent()
                    .appending(path: "Careers/Career-\(UUID().uuidString).json")
                guard save(to: backup) else { return false }
            }
            try FileManager.default.createDirectory(at: saveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(loaded).write(to: saveURL, options: .atomic)
            season = loaded
            available = []
            isDemo = loaded.demo
            screen = "Overview"
            managingDatabase = false
            error = nil
            return true
        } catch {
            self.error = "Could not load your career: \(error.localizedDescription)"
            return false
        }
    }
    func name(_ id: Int) -> String { season?.clubs.first { $0.id == id }?.name ?? "Unknown club" }
}
