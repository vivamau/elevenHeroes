import Foundation
import Testing
@testable import ElevenHeroes

struct CityGenerationTests {
    @Test func preservesCountriesAndExistingWorldAndCoversEveryCountry() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "db.sqlite")
        try FootballDatabase.install(from: Database.seedURL(), to: url)
        let db = try FootballDatabase(url: url, writable: true)
        _ = try db.generate(.team, count: 2, includeSquads: false)
        let countries = try db.records(.country).map(\.values)
        let teams = try db.records(.team).map(\.values)
        let originalCities = try db.records(.city)
        _ = try db.generate(.city, count: 1, replaceAll: true)
        #expect(try db.records(.country).map(\.values) == countries)
        #expect(try db.records(.team).map(\.values) == teams)
        let cities = try db.records(.city)
        #expect(originalCities.allSatisfy { old in cities.contains { $0.id == old.id && $0.values == old.values } })
        let covered = Set(cities.compactMap { $0.values["country_id"] })
        #expect(try db.records(.country).allSatisfy { covered.contains(String($0.id)) })
        try db.clearWorld()
        _ = try db.generate(.city, count: 1, replaceAll: true)
        let allCountries = try db.records(.country)
        let catalog = try CountryCatalog.load()
        #expect(allCountries.count == catalog.count)
        #expect(try db.records(.city).count == allCountries.count)
    }
}
