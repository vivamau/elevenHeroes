import Foundation
import Testing
import CSQLite
@testable import ElevenHeroes

struct CountryCatalogTests {
    @Test @MainActor func existingISO2DatabaseReceivesCatalogWithoutLosingLinks() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "db.sqlite")
        try FootballDatabase.copy(from: Database.seedURL(), to: url)
        var handle: OpaquePointer?
        #expect(sqlite3_open(url.path, &handle) == SQLITE_OK)
        defer { sqlite3_close(handle) }
        #expect(sqlite3_exec(handle, "DELETE FROM country; ALTER TABLE country RENAME COLUMN country_iso3 TO country_iso2; INSERT INTO country VALUES (700,'Italy','IT'); INSERT INTO country VALUES (701,'Custom Country','ZZZ'); INSERT INTO city VALUES (800,700,'Rome');", nil, nil, nil) == SQLITE_OK)
        let store = GameStore(saveURL: folder.appending(path: "season.json"))
        #expect(store.error == nil)
        let db = try FootballDatabase(url: url)
        let countries = try db.records(.country)
        #expect(countries.count == 250)
        #expect(countries.first { $0.id == 700 }?.values["country_iso3"] == "ITA")
        #expect(countries.contains { $0.id == 701 })
        #expect(try db.records(.city).first?.values["country_id"] == "700")
        #expect(store.prepareDatabase())
        #expect(try db.records(.country).count == 250)
    }
}
