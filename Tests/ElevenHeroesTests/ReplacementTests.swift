import Foundation
import Testing
import CSQLite
@testable import ElevenHeroes

struct ReplacementTests {
    @Test func replacesWorldAndRollsBackFailedGeneration() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "db.sqlite")
        try FootballDatabase.install(from: Database.seedURL(), to: url)
        let db = try FootballDatabase(url: url, writable: true)
        _ = try db.generate(.team, count: 2)
        _ = try db.generate(.stadium, count: 1)
        let before = try db.records(.player).map(\.values)
        let feet = try db.attributeChoices()["player_foot_id"]?.map(\.name)
        var handle: OpaquePointer?
        #expect(sqlite3_open(url.path, &handle) == SQLITE_OK)
        defer { sqlite3_close(handle) }
        #expect(sqlite3_exec(handle, "CREATE TRIGGER reject_new BEFORE INSERT ON player BEGIN SELECT RAISE(ABORT,'Injected failure'); END", nil, nil, nil) == SQLITE_OK)
        #expect(throws: (any Error).self) { try db.generate(.team, count: 3, replaceAll: true) }
        #expect(try db.records(.player).map(\.values) == before)
        #expect(try db.records(.team).count == 2)
        #expect(try db.records(.stadium).count == 3)
        #expect(sqlite3_exec(handle, "DROP TRIGGER reject_new", nil, nil, nil) == SQLITE_OK)
        _ = try db.generate(.team, count: 3, replaceAll: true)
        #expect(try db.records(.team).count == 3)
        #expect(try db.records(.player).count == 66)
        #expect(try db.records(.stadium).count == 3)
        #expect(try db.attributeChoices()["player_foot_id"]?.map(\.name) == feet)
        _ = try db.generate(.country, count: 2, replaceAll: true)
        #expect(try db.records(.country).count == 2)
        for kind in RecordKind.allCases where kind != .country { #expect(try db.records(kind).isEmpty) }
        var statement: OpaquePointer?
        #expect(sqlite3_prepare_v2(handle, "PRAGMA foreign_key_check", -1, &statement, nil) == SQLITE_OK)
        #expect(sqlite3_step(statement) == SQLITE_DONE)
        sqlite3_finalize(statement)
    }
}
