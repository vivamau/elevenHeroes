import Foundation
import Testing
@testable import ElevenHeroes

struct DeletionTests {
    @Test func deletionPreservesRelatedEntitiesAndProtectsPlaces() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "db.sqlite")
        try FootballDatabase.install(from: Database.seedURL(), to: url)
        let db = try FootballDatabase(url: url, writable: true)
        _ = try db.generate(.team, count: 2)
        _ = try db.generate(.stadium, count: 1)
        let city = try #require(db.records(.city).first)
        let country = try #require(db.records(.country).first { String($0.id) == city.values["country_id"] })
        #expect(throws: (any Error).self) { try db.delete(.country, id: country.id) }
        #expect(throws: (any Error).self) { try db.delete(.city, id: city.id) }
        #expect(try db.records(.team).count == 2)
        let player = try #require(db.records(.player).first)
        try db.delete(.player, id: player.id)
        #expect(try db.records(.player).count == 43)
        #expect(try db.playerProfiles()[player.id] == nil)
        let team = try #require(db.records(.team).first)
        try db.delete(.team, id: team.id)
        #expect(try db.records(.team).count == 1)
        #expect(try db.records(.player).count == 43)
        for league in try db.records(.championship) { try db.delete(.championship, id: league.id) }
        #expect(try db.records(.team).count == 1)
        for record in try db.records(.player) { try db.delete(.player, id: record.id) }
        for record in try db.records(.team) { try db.delete(.team, id: record.id) }
        for record in try db.records(.stadium) { try db.delete(.stadium, id: record.id) }
        for record in try db.records(.city) { try db.delete(.city, id: record.id) }
        for record in try db.records(.country) { try db.delete(.country, id: record.id) }
        for kind in RecordKind.allCases { #expect(try db.records(kind).isEmpty) }
        // A fresh batch must still work after removing all records and their dependencies.
        _ = try db.generate(.team, count: 2)
        #expect(try Database.load(url).allSatisfy { $0.players.count == 22 })
    }
}
