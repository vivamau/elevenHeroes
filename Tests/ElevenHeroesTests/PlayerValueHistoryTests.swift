import Foundation
import Testing
import CSQLite
@testable import ElevenHeroes

struct PlayerValueHistoryTests {
    private func sql(_ url: URL, _ statement: String) throws {
        var handle: OpaquePointer?
        guard sqlite3_open(url.path, &handle) == SQLITE_OK else { throw DatabaseIssue(message: "Cannot open test database") }
        defer { sqlite3_close(handle) }
        guard sqlite3_exec(handle, statement, nil, nil, nil) == SQLITE_OK else {
            throw DatabaseIssue(message: String(cString: sqlite3_errmsg(handle)))
        }
    }

    @Test @MainActor func generatedSalariesMatchHistoryAndSurviveMigration() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = GameStore(saveURL: folder.appending(path: "season.json"))
        let db = try FootballDatabase(url: store.databaseURL, writable: true)
        _ = try db.generate(.team, count: 2, includeSquads: true)
        let players = try db.records(.player)
        #expect(players.count == 44)
        #expect(players.allSatisfy { (10...100).contains(Int($0.values["player_initial_salary"] ?? "") ?? 0) })
        try sql(store.databaseURL, "CREATE TEMP TABLE salary_check(ok INTEGER CHECK(ok=1)); INSERT INTO salary_check SELECT COUNT(*)=44 FROM player p JOIN player_value v ON v.player_id=p.id WHERE v.player_value_salary=p.player_initial_salary;")
        let player = try #require(players.first)
        try sql(store.databaseURL, "UPDATE player SET player_initial_salary=37 WHERE id=\(player.id); UPDATE player_value SET player_value_salary=65 WHERE player_id=\(player.id);")
        let migrated = try FootballDatabase(url: store.databaseURL, writable: true)
        var draft = RecordDraft(kind: .player, record: player)
        let assigned = try db.assignment(for: player, kind: .player)
        draft.assignment = String(try #require(db.records(.team).first { String($0.id) != assigned }).id)
        try migrated.save(draft)
        try sql(store.databaseURL, "CREATE TEMP TABLE salary_check(ok INTEGER CHECK(ok=1)); INSERT INTO salary_check SELECT player_initial_salary=37 FROM player WHERE id=\(player.id); INSERT INTO salary_check SELECT COUNT(*)=2 AND MIN(player_value_salary)=65 AND MAX(player_value_salary)=65 FROM player_value WHERE player_id=\(player.id);")
        // Older schemas receive both columns and matching initial/history salaries.
        try sql(store.databaseURL, "ALTER TABLE player DROP COLUMN player_initial_salary; ALTER TABLE player_value DROP COLUMN player_value_salary;")
        _ = try FootballDatabase(url: store.databaseURL, writable: true)
        try sql(store.databaseURL, "CREATE TEMP TABLE salary_check(ok INTEGER CHECK(ok=1)); INSERT INTO salary_check SELECT COUNT(*)=45 FROM player p JOIN player_value v ON v.player_id=p.id WHERE v.player_value_salary=p.player_initial_salary AND p.player_initial_salary BETWEEN 10 AND 100;")
    }

    @Test @MainActor func valuesRetainTeamsAndReassignmentsAppendHistory() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = GameStore(saveURL: folder.appending(path: "season.json"))
        let db = try FootballDatabase(url: store.databaseURL, writable: true)
        _ = try db.generate(.team, count: 2, includeSquads: true)
        let record = try #require(db.records(.player).first)
        let teamID = try #require(Int(db.assignment(for: record, kind: .player)))
        let other = try #require(db.records(.team).first { $0.id != teamID })
        let original = try #require(db.playerValueHistories()[record.id])
        #expect(original.count == 1)
        #expect(original[0].teamID == teamID)
        #expect(original[0].teamName != nil)
        try sql(store.databaseURL, "UPDATE player_value SET player_value_date=20200101,player_value_cost=30 WHERE player_id=\(record.id); INSERT INTO player_value(player_id,player_value_date,player_value_cost,player_value_team_id) VALUES(\(record.id),20210101,75,\(other.id));")
        var edit = RecordDraft(kind: .player, record: record)
        edit.assignment = String(other.id)
        try db.save(edit)
        let history = try #require(db.playerValueHistories()[record.id])
        #expect(history.count == 3)
        #expect(history.map(\.credits) == [30, 75, 75])
        #expect(history.map(\.teamID) == [teamID, other.id, other.id])
        try db.save(edit)
        #expect(try db.playerValueHistories()[record.id]?.count == 3)
        let player = try #require(Database.load(store.databaseURL).flatMap(\.players).first { $0.id == record.id })
        #expect(player.valueHistory == history)
        #expect(player.marketValue == 75)
        #expect(try db.marketSnapshot().first { $0.id == record.id }?.player.valueHistory == history)
        try db.delete(.team, id: other.id)
        let afterDeletion = try #require(db.playerValueHistories()[record.id])
        #expect(afterDeletion.count == 3)
        #expect(afterDeletion.last?.teamID == nil)
        #expect(afterDeletion.first?.teamID == teamID)
    }

    @Test @MainActor func olderValueSchemaMigratesWithoutInventingHistoricalTeams() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = GameStore(saveURL: folder.appending(path: "season.json"))
        let db = try FootballDatabase(url: store.databaseURL, writable: true)
        _ = try db.generate(.player, count: 1)
        let id = try #require(db.records(.player).first?.id)
        try sql(store.databaseURL, "DROP TABLE player_value; CREATE TABLE player_value(id INTEGER PRIMARY KEY,player_id INTEGER,player_value_date INTEGER,player_value_cost INTEGER); INSERT INTO player_value VALUES(1,\(id),20200101,42);")
        let migrated = try FootballDatabase(url: store.databaseURL, writable: true)
        let history = try #require(migrated.playerValueHistories()[id])
        #expect(history.count == 1)
        #expect(history[0].credits == 42)
        #expect(history[0].teamID == nil)
        #expect(history[0].teamLabel == "Team not recorded")
        #expect(try FootballDatabase(url: store.databaseURL, writable: true).playerValueHistories()[id] == history)
    }

    @Test @MainActor func careerHistorySurvivesTransfersAndReloadWithoutChangingDatabase() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = GameStore(saveURL: folder.appending(path: "season.json"))
        let db = try FootballDatabase(url: store.databaseURL, writable: true)
        _ = try db.generate(.team, count: 2, includeSquads: true)
        store.useDatabase(); store.start(try #require(store.available.first).id)
        let target = try #require(store.season?.transferMarket.first { $0.clubID != store.season?.selectedClub && $0.player.role != "GK" })
        let databaseHistory = try db.playerValueHistories()[target.id]
        store.season?.creditBalance = 100_000
        let initial = try #require(target.player.valueHistory)
        #expect(store.buyPlayer(target.id, offer: (target.player.creditsValue * 120 + 99) / 100))
        let bought = try #require(store.season?.transferMarket.first { $0.id == target.id }?.player)
        #expect(bought.valueHistory?.count == initial.count + 1)
        #expect(bought.valueHistory?.last?.teamID == store.season?.selectedClub)
        #expect(store.sellPlayer(target.id))
        let history = try #require(store.season?.transferMarket.first { $0.id == target.id }?.player.valueHistory)
        #expect(history.count == initial.count + 2)
        #expect(Array(history.prefix(initial.count)) == initial)
        #expect(GameStore(saveURL: store.saveURL).season?.transferMarket.first { $0.id == target.id }?.player.valueHistory == history)
        #expect(try db.playerValueHistories()[target.id] == databaseHistory)
    }

    @Test func oldPlayersDecodeWithoutHistory() throws {
        let player = try JSONDecoder().decode(Footballer.self, from: Data(#"{"id":1,"name":"Old player","role":"MID","rating":65}"#.utf8))
        #expect(player.valueHistory == nil)
        #expect(player.creditsValue == 65)
    }
}
