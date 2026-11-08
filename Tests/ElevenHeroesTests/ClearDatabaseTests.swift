import Foundation
import Testing
import CSQLite
@testable import ElevenHeroes

struct ClearDatabaseTests {
    @Test @MainActor func clearPreservesLookupsAndStaysEmptyAfterReopening() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = GameStore(saveURL: folder.appending(path: "season.json"))
        store.generateCareerData(); store.start(1)
        let saved = try Data(contentsOf: store.saveURL)
        let db = try FootballDatabase(url: store.databaseURL, writable: true)
        _ = try db.generate(.team, count: 2)
        let before = try db.attributeChoices().mapValues { $0.map(\.name) }
        try db.clearWorld()
        for kind in RecordKind.allCases { #expect(try db.records(kind).isEmpty) }
        #expect(try db.attributeChoices().mapValues { $0.map(\.name) } == before)
        #expect(store.prepareDatabase())
        #expect(try db.records(.country).isEmpty)
        #expect(try Data(contentsOf: store.saveURL) == saved)
        // Generating again verifies position definitions and foreign keys survived the clear.
        _ = try db.generate(.team, count: 2)
        #expect(try db.records(.player).count == 44)
        let catalog = try CountryCatalog.load()
        let teams = try CSVTeam.load()
        for country in try db.records(.country) {
            #expect(catalog.contains { $0.name == country.title && $0.iso3 == country.values["country_iso3"] })
        }
        let cities = try db.records(.city)
        let countries = try db.records(.country)
        for team in try db.records(.team) {
            let source = try #require(teams.first { $0.name == team.title })
            let city = try #require(cities.first { String($0.id) == team.values["city_id"] })
            let country = try #require(countries.first { String($0.id) == city.values["country_id"] })
            #expect(country.values["country_iso3"] == source.country)
        }
    }
}
