import Foundation
import Testing
import CSQLite
@testable import ElevenHeroes

struct DatabaseStartupTests {
    @Test @MainActor func upgradesMissingPositionsWithIntegerFootIDs() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "db.sqlite")
        try FootballDatabase.copy(from: Database.seedURL(), to: url)
        var handle: OpaquePointer?
        #expect(sqlite3_open(url.path, &handle) == SQLITE_OK)
        defer { sqlite3_close(handle) }
        #expect(sqlite3_exec(handle, "DROP TABLE player_position; DROP TABLE position; DELETE FROM player_foot WHERE id != 1; INSERT INTO country (id,country_name,country_iso3) VALUES (500,'Preserved','PRS');", nil, nil, nil) == SQLITE_OK)
        let store = GameStore(saveURL: folder.appending(path: "season.json"))
        #expect(store.error == nil)
        let db = try FootballDatabase(url: url, writable: true)
        #expect(try db.records(.country).first(where: { $0.id == 500 })?.title == "Preserved")
        #expect(try db.attributeChoices()["player_foot_id"]?.count == 3)
        _ = try db.generate(.team, count: 2)
        #expect(try db.records(.player).count == 44)
        var statement: OpaquePointer?
        #expect(sqlite3_prepare_v2(handle, "PRAGMA foreign_key_check", -1, &statement, nil) == SQLITE_OK)
        #expect(sqlite3_step(statement) == SQLITE_DONE)
        sqlite3_finalize(statement)
        #expect(GameStore(saveURL: store.saveURL).error == nil)
    }

    @Test func testBundledDatabaseCreatesWritableCopyAndPersistsRecords() async throws {
        try await MainActor.run {
            let seed = try Database.seedURL()
            #expect(seed.lastPathComponent == "db.sqlite")
            #expect(FileManager.default.fileExists(atPath: seed.path))
            let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: folder) }
            let save = folder.appending(path: "season.json")
            let store = GameStore(saveURL: save)
            #expect(store.error == nil)
            #expect(store.databaseURL.lastPathComponent == "db.sqlite")
            store.openDatabaseManager()
            #expect(store.managingDatabase)
            var country = RecordDraft(kind: .country)
            country.values = ["country_name": "Startup Test", "country_iso3": "TST"]
            try FootballDatabase(url: store.databaseURL, writable: true).save(country)
            let reopened = GameStore(saveURL: save)
            #expect(reopened.error == nil)
            #expect(try FootballDatabase(url: reopened.databaseURL).records(.country).contains(where: { $0.title == "Startup Test" }) == true)
        }
    }
    @Test func testLegacyDatabaseIsMigratedWithoutLosingRecords() async throws {
        try await MainActor.run {
            let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: folder) }
            let legacy = folder.appending(path: "football.sqlite")
            try FootballDatabase.install(from: Database.seedURL(), to: legacy)
            var country = RecordDraft(kind: .country)
            country.values = ["country_name": "Existing Data", "country_iso3": "OLD"]
            try FootballDatabase(url: legacy, writable: true).save(country)
            let store = GameStore(saveURL: folder.appending(path: "season.json"))
            #expect(store.error == nil)
            #expect(try FootballDatabase(url: store.databaseURL).records(.country).contains(where: { $0.title == "Existing Data" }) == true)
            #expect(FileManager.default.fileExists(atPath: legacy.path))
            // A later launch must not replace db.sqlite with the old data.
            var newCountry = RecordDraft(kind: .country)
            newCountry.values = ["country_name": "New Data", "country_iso3": "NEW"]
            try FootballDatabase(url: store.databaseURL, writable: true).save(newCountry)
            let reopened = GameStore(saveURL: store.saveURL)
            #expect(try FootballDatabase(url: reopened.databaseURL).records(.country).count == 251)
        }
    }
    @Test func testFailedSetupDoesNotOpenEditorAndCanBeRetried() async throws {
        try await MainActor.run {
            let blocker = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            try Data("not a directory".utf8).write(to: blocker)
            defer { try? FileManager.default.removeItem(at: blocker) }
            let store = GameStore(saveURL: blocker.appending(path: "season.json"))
            #expect(store.error != nil)
            store.openDatabaseManager()
            #expect(!store.managingDatabase)
            try FileManager.default.removeItem(at: blocker)
            store.error = nil
            store.openDatabaseManager()
            #expect(store.error == nil)
            #expect(store.managingDatabase)
        }
    }
}
