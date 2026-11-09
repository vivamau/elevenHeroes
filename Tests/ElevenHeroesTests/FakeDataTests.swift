import Foundation
import Testing
import CSQLite
@testable import ElevenHeroes

struct FakeDataTests {
    @Test(arguments: RecordKind.allCases)
    func everyDatasetSupportsRepeatedGeneration(kind: RecordKind) throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "db.sqlite")
        try FootballDatabase.install(from: Database.seedURL(), to: url)
        let db = try FootballDatabase(url: url, writable: true)
        if kind == .country { try db.clearWorld() }
        var existing = RecordDraft(kind: .country)
        existing.values = ["country_name": "Keep Me", "country_iso3": "XAA"]
        let existingID = try db.save(existing)
        let first = try db.generate(kind, count: 3)
        if kind == .city { #expect((first.counts[kind] ?? 0) >= 3) }
        else { #expect(first.counts[kind] == 3) }
        let afterFirst = try db.records(kind).count
        let second = try db.generate(kind, count: 2)
        #expect(second.counts[kind] == 2)
        #expect(try db.records(kind).count == afterFirst + 2)
        #expect(try db.records(.country).first(where: { $0.id == existingID })?.title == "Keep Me")
        let countries = try db.records(.country)
        #expect(Set(countries.compactMap { $0.values["country_iso3"] }).count == countries.count)
        for type in RecordKind.allCases {
            let records = try db.records(type)
            #expect(Set(records.map(\.id)).count == records.count)
            #expect(records.allSatisfy { RecordDraft(kind: type, record: $0).validation == nil })
        }
        if kind == .team {
            let clubs = try Database.load(url)
            #expect(clubs.count == 5)
            #expect(clubs.allSatisfy { $0.players.count == 22 })
            let source = try CSVPlayerProfiles.loaded.get()
            for club in clubs {
                let profiles = source.filter { $0.club == club.name }
                for player in club.players {
                    let values = try #require(player.profile?.values)
                    let match = try #require(profiles.first { $0.first == values["player_name"] && $0.last == values["player_lastname"] && $0.dob == values["player_dob"] })
                    #expect(values["position_name"] == match.position)
                    if ["right", "left", "both"].contains(match.foot) {
                        #expect(player.profile?.foot.lowercased() == match.foot)
                    }
                }
            }
            #expect(clubs.flatMap(\.players).allSatisfy { (40...90).contains($0.rating) })
            #expect(Season.schedule(clubs).count == 20)
        }
    }

    @Test func playersFillSmallestSquadsAndTeamsCanSkipSquads() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "db.sqlite")
        try FootballDatabase.install(from: Database.seedURL(), to: url)
        let db = try FootballDatabase(url: url, writable: true)
        _ = try db.generate(.team, count: 2, includeSquads: false)
        #expect(try db.records(.player).isEmpty)
        _ = try db.generate(.player, count: 22)
        let clubs = try Database.load(url)
        #expect(clubs.allSatisfy { $0.players.count == 11 })
        #expect(throws: (any Error).self) { try db.generate(.city, count: 0) }
        #expect(throws: (any Error).self) { try db.generate(.city, count: 101) }
    }

    @Test func failedGenerationRollsBackDependenciesAndRecords() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "db.sqlite")
        try FootballDatabase.install(from: Database.seedURL(), to: url)
        var handle: OpaquePointer?
        #expect(sqlite3_open(url.path, &handle) == SQLITE_OK)
        defer { sqlite3_close(handle) }
        #expect(sqlite3_exec(handle, "CREATE TRIGGER fail_player BEFORE INSERT ON player WHEN (SELECT count(*) FROM player)>=1 BEGIN SELECT RAISE(ABORT,'Injected failure'); END;", nil, nil, nil) == SQLITE_OK)
        let db = try FootballDatabase(url: url, writable: true)
        #expect(throws: (any Error).self) { try db.generate(.team, count: 2) }
        for kind in RecordKind.allCases { #expect(try db.records(kind).count == (kind == .country ? 249 : kind == .tactic ? 3 : 0)) }
        #expect(sqlite3_exec(handle, "DROP TRIGGER fail_player", nil, nil, nil) == SQLITE_OK)
        _ = try db.generate(.team, count: 2)
        #expect(try db.records(.player).count == 44)
    }
}
