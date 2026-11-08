import Foundation
import Testing
import CSQLite
@testable import ElevenHeroes

struct PlayerAttributeTests {
    private func withDatabase(_ work: (FootballDatabase, URL) throws -> Void) throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "db.sqlite")
        try FootballDatabase.install(from: Database.seedURL(), to: url)
        try work(FootballDatabase(url: url, writable: true), url)
    }
    private func scalar(_ sql: String, at url: URL) throws -> Int {
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK else { throw DatabaseIssue(message: "Test connection failed") }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw DatabaseIssue(message: "Test query failed") }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { throw DatabaseIssue(message: "Missing test result") }
        return Int(sqlite3_column_int(stmt, 0))
    }
    @Test func generationCreatesBothCompleteSkillTables() throws {
        try withDatabase { db, url throws in
            _ = try db.generate(.team, count: 2)
            _ = try db.generate(.player, count: 4)
            let players = try db.records(.player)
            #expect(players.count == 48)
            #expect(try scalar("SELECT count(*) FROM player_position", at: url) == 48)
            #expect(try scalar("SELECT count(*) FROM player_position pp JOIN position p ON p.id=pp.position_id", at: url) == 48)
            #expect(try scalar("SELECT count(*) FROM player_position WHERE player_position_strong=1 AND player_position_acquired=0 AND player_position_date_from IS NOT NULL", at: url) == 48)
            #expect(try scalar("SELECT count(*) FROM player_skills_mental", at: url) == 48)
            #expect(try scalar("SELECT count(*) FROM player_skills_physical", at: url) == 48)
            for player in players {
                #expect(PlayerAttributes.validation(player.values) == nil)
                for attribute in PlayerAttributes.physical + PlayerAttributes.mental {
                    #expect(player.values[attribute.id] != nil)
                }
                #expect(!(player.values["player_foot_id"] ?? "").hasPrefix("new:"))
                #expect(!(player.values["player_morale_id"] ?? "").hasPrefix("new:"))
            }
            #expect(try scalar("SELECT count(*) FROM pragma_foreign_key_check", at: url) == 0)
        }
    }
    @Test func manualSkillsRoundTripAndProfileEditsPreserveThem() throws {
        try withDatabase { db, url throws in
            _ = try db.generate(.city, count: 1)
            let city = try #require(db.records(.city).first)
            var draft = RecordDraft(kind: .player)
            draft.values.merge(["player_name": "Test", "player_lastname": "Player", "city_id": String(city.id)]) { _, new in new }
            for (index, attribute) in (PlayerAttributes.physical + PlayerAttributes.mental).enumerated() {
                draft.values[attribute.id] = String(attribute.range.upperBound == 100 ? 73 : index % 20 + 1)
            }
            draft.values["player_foot_id"] = try #require(db.attributeChoices()["player_foot_id"]?.last?.id)
            draft.values["player_morale_id"] = try #require(db.attributeChoices()["player_morale_id"]?.last?.id)
            let id = try db.save(draft)
            let player = try #require(db.records(.player).first)
            for attribute in PlayerAttributes.physical + PlayerAttributes.mental {
                #expect(player.values[attribute.id] == draft.values[attribute.id])
            }
            var update = RecordDraft(kind: .player, record: player)
            update.values["player_name"] = "Renamed"
            try db.save(update)
            try db.save(update)
            let reopened = try FootballDatabase(url: url)
            let saved = try #require(reopened.records(.player).first)
            #expect(saved.id == id)
            #expect(saved.values["player_name"] == "Renamed")
            #expect(saved.values["player_foot_id"] == player.values["player_foot_id"])
            #expect(saved.values["player_morale_id"] == player.values["player_morale_id"])
            for attribute in PlayerAttributes.physical + PlayerAttributes.mental {
                #expect(saved.values[attribute.id] == draft.values[attribute.id])
            }
            #expect(try scalar("SELECT count(*) FROM player_skills_mental", at: url) == 1)
            #expect(try scalar("SELECT count(*) FROM player_skills_physical", at: url) == 1)
            update.values["p_skill_mental_teamwork"] = "21"
            update.values["player_name"] = "Must not save"
            #expect(throws: (any Error).self) { try db.save(update) }
            #expect(try db.records(.player).first?.values["player_name"] == "Renamed")
        }
    }
    @Test func invalidReferencesRollBackPlayerAndSkillWrites() throws {
        try withDatabase { db, url throws in
            _ = try db.generate(.city, count: 1)
            let city = try #require(db.records(.city).first)
            let originalFootCount = try scalar("SELECT count(*) FROM player_foot", at: url)
            var draft = RecordDraft(kind: .player)
            draft.values.merge(["player_name": "Test", "player_lastname": "Player", "city_id": String(city.id), "player_morale_id": "999999"]) { _, new in new }
            #expect(throws: (any Error).self) { try db.save(draft) }
            #expect(try db.records(.player).isEmpty)
            #expect(try scalar("SELECT count(*) FROM player_skills_physical", at: url) == 0)
            #expect(try scalar("SELECT count(*) FROM player_foot", at: url) == originalFootCount)
        }
    }
    @Test func lookupTablesAreTheOnlySourceForGenerationAndEditing() throws {
        try withDatabase { db, url throws in
            var connection: OpaquePointer?
            #expect(sqlite3_open(url.path, &connection) == SQLITE_OK)
            defer { sqlite3_close(connection) }
            #expect(sqlite3_exec(connection, "DELETE FROM player_foot; DELETE FROM player_morale; INSERT INTO player_foot (id,player_foot_name) VALUES (42,'Custom foot'); UPDATE position SET player_foot_id=42; INSERT INTO player_morale (id,player_morale_name) VALUES (81,'Custom morale');", nil, nil, nil) == SQLITE_OK)
            let choices = try db.attributeChoices()
            #expect(choices["player_foot_id"]?.map(\.id) == ["42"])
            #expect(choices["player_foot_id"]?.map(\.name) == ["Custom foot"])
            #expect(choices["player_morale_id"]?.map(\.id) == ["81"])
            #expect(choices["player_morale_id"]?.map(\.name) == ["Custom morale"])
            _ = try db.generate(.player, count: 5)
            for player in try db.records(.player) {
                #expect(player.values["player_foot_id"] == "42")
                #expect(player.values["player_morale_id"] == "81")
            }
            #expect(try scalar("SELECT count(*) FROM player_foot", at: url) == 1)
            #expect(try scalar("SELECT count(*) FROM player_morale", at: url) == 1)
        }
    }
    @Test(arguments: ["player_foot", "player_morale"])
    func emptyLookupTablesBlockGenerationWithoutInventingOptions(table: String) throws {
        try withDatabase { db, url throws in
            var connection: OpaquePointer?
            #expect(sqlite3_open(url.path, &connection) == SQLITE_OK)
            defer { sqlite3_close(connection) }
            #expect(sqlite3_exec(connection, "DELETE FROM \(table)", nil, nil, nil) == SQLITE_OK)
            #expect(try db.attributeChoices()["\(table)_id"]?.isEmpty == true)
            #expect(throws: (any Error).self) { try db.generate(.team, count: 2) }
            #expect(try db.records(.player).isEmpty)
            #expect(try db.records(.team).isEmpty)
            #expect(try scalar("SELECT count(*) FROM \(table)", at: url) == 0)
        }
    }

}
