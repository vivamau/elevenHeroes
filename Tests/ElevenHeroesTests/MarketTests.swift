import Foundation
import Testing
import CSQLite
@testable import ElevenHeroes

struct MarketTests {
    @Test func salesStopAtSixteenAndReplaceSoldStarter() throws {
        var career = season()
        career.lineup = Array(career.clubs[0].players.prefix(11).map(\.id))
        let player = try #require(career.clubs[0].players.first { $0.role != "GK" })
        let buyer = try #require(career.saleBuyer?.id)
        try career.sellPlayer(player.id)
        #expect(career.credits == 10_000 + player.creditsValue)
        #expect(career.squadCount == 19)
        #expect(career.lineup.count == 11)
        #expect(!career.lineup.contains(player.id))
        #expect(Set(career.lineup).count == 11)
        let sold = try #require(career.clubs.first { $0.id == buyer }?.players.first { $0.id == player.id })
        #expect(sold.name == player.name && sold.rating == player.rating)
        #expect(sold.valueHistory?.last?.teamID == buyer)
        let balance = career.credits
        #expect(throws: (any Error).self) { try career.sellPlayer(player.id) }
        #expect(career.credits == balance)
        for _ in 0..<3 { try career.sellPlayer(career.clubs[0].players.last!.id) }
        #expect(career.squadCount == 16)
        #expect(!career.canSellPlayer)
        let remainingBalance = career.credits
        #expect(throws: (any Error).self) { try career.sellPlayer(career.clubs[0].players[0].id) }
        #expect(career.squadCount == 16)
        #expect(career.credits == remainingBalance)
        career.clubs[0].players.removeLast()
        #expect(throws: (any Error).self) { try career.sellPlayer(career.clubs[0].players[0].id) }
        #expect(career.squadCount == 15)
    }

    @Test @MainActor func salesPersistAndSaveFailureLeavesSquadAndCreditsUnchanged() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = GameStore(saveURL: folder.appending(path: "season.json"))
        store.generateCareerData(); store.start(1)
        let player = try #require(store.season?.clubs[0].players.first { $0.role != "GK" })
        #expect(store.sellPlayer(player.id))
        let restored = GameStore(saveURL: store.saveURL)
        #expect(restored.season?.credits == 10_000 + player.creditsValue)
        #expect(restored.season?.squadCount == 19)
        #expect(restored.season?.transferMarket.first { $0.id == player.id }?.clubID != 1)
        let next = try #require(store.season?.clubs[0].players.first { $0.role != "GK" })
        let balance = store.season?.credits
        try FileManager.default.removeItem(at: store.saveURL)
        try FileManager.default.createDirectory(at: store.saveURL, withIntermediateDirectories: true)
        #expect(!store.sellPlayer(next.id))
        #expect(store.season?.credits == balance)
        #expect(store.season?.squadCount == 19)
        #expect(store.season?.clubs[0].players.contains(next) == true)
    }

    private func season() -> Season {
        var rng = SeasonTests.Seeded()
        let clubs = Database.generateFictionalLeague(using: &rng)
        return Season(clubs: clubs, fixtures: Season.schedule(clubs), selectedClub: 1, demo: true)
    }

    @Test func transferMovesPlayerAndChargesOfferExactlyOnce() throws {
        var career = season()
        let player = try #require(career.clubs[1].players.first { $0.role != "GK" })
        let offer = (player.creditsValue * 120 + 99) / 100
        try career.buyPlayer(player.id, offer: offer)
        #expect(career.credits == 10_000 - offer)
        let bought = try #require(career.clubs[0].players.first { $0.id == player.id })
        #expect(bought.name == player.name && bought.rating == player.rating)
        #expect(bought.valueHistory?.last?.teamID == career.selectedClub)
        #expect(!career.clubs[1].players.contains { $0.id == player.id })
        #expect(career.transferMarket.filter { $0.id == player.id }.count == 1)
        #expect(throws: (any Error).self) { try career.buyPlayer(player.id, offer: offer) }
        #expect(career.credits == 10_000 - offer)
    }

    @Test func minimumWeeklySalaryAppliesToExistingPlayers() throws {
        var player = Footballer(id: 1, name: "Legacy", role: "MID", rating: 60)
        #expect(player.currentSalary == 10)
        player.salary = 5
        let restored = try JSONDecoder().decode(Footballer.self, from: JSONEncoder().encode(player))
        #expect(restored.currentSalary == 10)
        var career = season()
        let target = try #require(career.clubs[1].players.first { $0.role != "GK" })
        try career.buyPlayer(target.id, offer: (target.creditsValue * 120 + 99) / 100, salary: 10)
        #expect(career.clubs[0].players.first { $0.id == target.id }?.currentSalary == 10)
    }

    @Test func purchaseSalaryIsValidatedAndSaved() throws {
        var career = season()
        let player = try #require(career.clubs[1].players.first { $0.role != "GK" })
        let offer = (player.creditsValue * 120 + 99) / 100
        let original = career.clubs
        for invalid in [0, -10, 1, 9] {
            #expect(throws: (any Error).self) { try career.buyPlayer(player.id, offer: offer, salary: invalid) }
            #expect(career.clubs == original)
            #expect(career.credits == 10_000)
        }
        try career.buyPlayer(player.id, offer: offer, salary: 75)
        let loaded = try JSONDecoder().decode(Season.self, from: JSONEncoder().encode(career))
        let bought = try #require(loaded.clubs[0].players.first { $0.id == player.id })
        #expect(bought.currentSalary == 75)
        #expect(bought.valueHistory?.last?.salary == 75)
        #expect(bought.valueHistory?.first?.salary == player.currentSalary)
        #expect(loaded.credits == 10_000 - offer)
    }

    @Test func rejectedOffersLeaveBalanceAndSquadsIntact() throws {
        var career = season()
        let player = try #require(career.clubs[1].players.first { $0.role != "GK" })
        let squads = career.clubs
        #expect(throws: (any Error).self) { try career.buyPlayer(player.id, offer: player.creditsValue - 1) }
        #expect(throws: (any Error).self) { try career.buyPlayer(player.id, offer: 10_001) }
        #expect(throws: (any Error).self) { try career.buyPlayer(-999, offer: 100) }
        #expect(career.credits == 10_000)
        #expect(career.clubs == squads)
    }

    @Test func playersOutsideLeagueCanTransferAndLegacySavesRemainReadable() throws {
        var career = season()
        let player = Footballer(id: 99999, name: "Outside player", role: "MID", rating: 60, marketValue: 25)
        career.marketPlayers = [MarketPlayer(player: player, clubID: 999, clubName: "Outside club")]
        try career.buyPlayer(player.id, offer: 30)
        #expect(career.credits == 9970)
        #expect(career.marketPlayers?.isEmpty == true)
        #expect(career.clubs[0].players.contains { $0.id == player.id })
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(season())) as? [String: Any])
        json.removeValue(forKey: "creditBalance")
        json.removeValue(forKey: "marketPlayers")
        var clubs = try #require(json["clubs"] as? [[String: Any]])
        for index in clubs.indices {
            var players = try #require(clubs[index]["players"] as? [[String: Any]])
            for p in players.indices { players[p].removeValue(forKey: "marketValue") }
            clubs[index]["players"] = players
        }
        json["clubs"] = clubs
        let legacy = try JSONDecoder().decode(Season.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(legacy.credits == 10_000)
        #expect(legacy.transferMarket.allSatisfy { (1...100).contains($0.player.creditsValue) })
    }

    @Test @MainActor func transferPersistsAndFailedSaveDoesNotSpendCredits() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = GameStore(saveURL: folder.appending(path: "season.json"))
        store.generateCareerData(); store.start(1)
        store.season?.creditBalance = 100_000
        let player = try #require(store.season?.clubs[1].players.first { $0.role != "GK" })
        #expect(store.buyPlayer(player.id, offer: (player.creditsValue * 120 + 99) / 100))
        let restored = GameStore(saveURL: store.saveURL)
        #expect(restored.season?.credits == 100_000 - (player.creditsValue * 120 + 99) / 100)
        #expect(restored.season?.clubs[0].players.contains { $0.id == player.id } == true)
        let another = try #require(store.season?.clubs[1].players.first { $0.role != "GK" })
        let balance = store.season?.credits
        try FileManager.default.removeItem(at: store.saveURL)
        try FileManager.default.createDirectory(at: store.saveURL, withIntermediateDirectories: true)
        #expect(!store.buyPlayer(another.id, offer: (another.creditsValue * 120 + 99) / 100))
        #expect(store.season?.credits == balance)
        #expect(store.season?.clubs[1].players.contains { $0.id == another.id } == true)
    }

    @Test @MainActor func databaseValuesAreGeneratedStableAndIncludedInCareer() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = GameStore(saveURL: folder.appending(path: "season.json"))
        let db = try FootballDatabase(url: store.databaseURL, writable: true)
        _ = try db.generate(.team, count: 2, includeSquads: true)
        _ = try db.generate(.team, count: 1, includeSquads: false)
        let values = try db.playerValues()
        #expect(try values.count == db.records(.player).count)
        #expect(values.values.allSatisfy { (1...100).contains($0) })
        #expect(try FootballDatabase(url: store.databaseURL, writable: true).playerValues() == values)
        let snapshot = try db.marketSnapshot()
        #expect(snapshot.count == values.count)
        store.useDatabase()
        store.start(try #require(store.available.first).id)
        #expect(store.season?.credits == 10_000)
        let active = try #require(store.season?.transferMarket).filter { values[$0.id] != nil }
        let retired = (store.season?.retiredPlayers ?? []).filter { values[$0.id] != nil }
        #expect(active.count + retired.count == values.count)
        #expect(active.allSatisfy { $0.player.creditsValue >= 100 && $0.player.currentSalary >= ($0.player.creditsValue + 9) / 10 })
        let target = try #require(store.season?.transferMarket.first { $0.clubID != store.season?.selectedClub && $0.player.role != "GK" && values[$0.id] != nil })
        store.season?.creditBalance = 100_000
        #expect(store.buyPlayer(target.id, offer: (target.player.creditsValue * 120 + 99) / 100))
        #expect(try db.marketSnapshot().first { $0.id == target.id }?.clubID == target.clubID)
        try db.delete(.player, id: target.id)
        #expect(try db.playerValues()[target.id] == nil)
        try db.clearWorld()
        #expect(try db.playerValues().isEmpty)
    }

    @Test @MainActor func migratesOriginalValueTableWithoutChangingExistingCosts() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = GameStore(saveURL: folder.appending(path: "season.json"))
        let db = try FootballDatabase(url: store.databaseURL, writable: true)
        _ = try db.generate(.player, count: 2)
        let ids = try db.records(.player).map(\.id)
        var handle: OpaquePointer?
        #expect(sqlite3_open(store.databaseURL.path, &handle) == SQLITE_OK)
        defer { sqlite3_close(handle) }
        let sql = "DROP TABLE player_value; CREATE TABLE player_value (id INTEGER PRIMARY KEY AUTOINCREMENT UNIQUE NOT NULL, player_id INTEGER REFERENCES player(id), player_value_date INTEGER NOT NULL, player_value_cost INTEGER NOT NULL); INSERT INTO player_value (player_id,player_value_date,player_value_cost) VALUES (\(ids[0]),20261104,42);"
        #expect(sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK)
        let migrated = try FootballDatabase(url: store.databaseURL, writable: true)
        let values = try migrated.playerValues()
        #expect(values[ids[0]] == 42)
        #expect((1...100).contains(try #require(values[ids[1]])))
        _ = try migrated.generate(.player, count: 1)
        #expect(try migrated.playerValues().count == 3)
    }
}
