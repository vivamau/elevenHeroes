import Foundation
import Testing
@testable import ElevenHeroes

struct TeamKitTests {
    @Test func generatedColoursAreValidAndStronglyDifferent() throws {
        var rng = SeasonTests.Seeded(state: 42)
        for _ in 0..<100 {
            let pair = TeamKits.generated(using: &rng)
            #expect(TeamKits.rgb(pair.0) != nil && TeamKits.rgb(pair.1) != nil)
            #expect(TeamKits.difference(pair.0, pair.1) > 0.8)
        }
        let clubs = try Database.generateFictionalLeague(using: &rng)
        #expect(clubs.allSatisfy { $0.teamColorPrimary != nil && $0.teamColorSecondary != nil })
    }

    @Test func awayUsesAlternateWhenPrimaryShirtsClash() throws {
        let home = Club(id: 1, name: "Home", city: "", players: [], teamColorPrimary: "#1565C0", teamColorSecondary: "#FFFFFF")
        let away = Club(id: 2, name: "Away", city: "", players: [], teamColorPrimary: "#1565C0", teamColorSecondary: "#FFD54F")
        let selection = TeamKits.select(home: home, away: away)
        #expect(selection.0 == home.teamColorPrimary)
        #expect(selection.1 == away.teamColorSecondary)
        let restored = try JSONDecoder().decode(Club.self, from: JSONEncoder().encode(away))
        #expect(restored.teamColorSecondary == away.teamColorSecondary)
        let legacy = try JSONDecoder().decode(Club.self, from: Data(#"{"id":1,"name":"Old","city":"","players":[]}"#.utf8))
        #expect(TeamKits.difference(legacy.kitColors.0, legacy.kitColors.1) > 0.8)
    }

    @Test func generatedDatabaseTeamsStoreAndLoadBothColours() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "db.sqlite")
        try FootballDatabase.copy(from: Database.seedURL(), to: url)
        let db = try FootballDatabase(url: url, writable: true)
        _ = try db.generate(.team, count: 3, includeSquads: false, replaceAll: true)
        let teams = try Database.load(url)
        #expect(teams.count == 3)
        #expect(teams.allSatisfy { $0.teamColorPrimary != nil && $0.teamColorSecondary != nil })
        #expect(teams.allSatisfy { TeamKits.difference($0.kitColors.0, $0.kitColors.1) > 0.8 })
    }
}
