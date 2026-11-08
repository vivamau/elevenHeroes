import Foundation
import Testing
@testable import ElevenHeroes

struct CareerSetupTests {
    @Test @MainActor func loadCareerRestoresProgressAndBacksUpCurrentCareer() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = GameStore(saveURL: folder.appending(path: "season.json"))
        store.generateCareerData()
        store.start(1)
        store.play()
        let copy = folder.appending(path: "previous.json")
        #expect(store.save(to: copy))
        let source = try Data(contentsOf: copy)
        store.start(2)
        store.screen = "Squad"
        #expect(store.loadCareer(copy))
        #expect(store.error == nil)
        #expect(store.season?.selectedClub == 1)
        #expect(store.season?.round == 2)
        #expect(store.screen == "Overview")
        #expect(try Data(contentsOf: copy) == source)
        let reopened = GameStore(saveURL: store.saveURL)
        #expect(reopened.season?.round == 2)
        #expect(reopened.season?.selectedClub == 1)
        let backups = try FileManager.default.contentsOfDirectory(at: folder.appending(path: "Careers"), includingPropertiesForKeys: nil)
        let backup = try #require(backups.first)
        let previous = try JSONDecoder().decode(Season.self, from: Data(contentsOf: backup))
        #expect(previous.selectedClub == 2)
    }

    @Test @MainActor func invalidCareerAndBackupFailurePreserveAutosave() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = GameStore(saveURL: folder.appending(path: "season.json"))
        store.generateCareerData()
        store.start(1)
        let saved = try Data(contentsOf: store.saveURL)
        let source = folder.appending(path: "incoming.json")
        try Data("invalid".utf8).write(to: source)
        #expect(!store.loadCareer(source))
        var invalid = try #require(store.season)
        invalid.selectedClub = -999
        try JSONEncoder().encode(invalid).write(to: source)
        #expect(!store.loadCareer(source))
        try saved.write(to: source)
        try Data().write(to: folder.appending(path: "Careers"))
        #expect(!store.loadCareer(source))
        #expect(store.error != nil)
        #expect(store.season?.selectedClub == 1)
        #expect(try Data(contentsOf: store.saveURL) == saved)
    }

    @Test @MainActor func savedCopySurvivesStartingAnotherCareer() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = GameStore(saveURL: folder.appending(path: "season.json"))
        store.generateCareerData()
        store.start(1)
        store.play()
        let original = try #require(store.season)
        let copy = folder.appending(path: "saved-career.json")
        #expect(store.save(to: copy))
        store.generateCareerData()
        store.start(2)
        let restored = try JSONDecoder().decode(Season.self, from: Data(contentsOf: copy))
        #expect(restored.selectedClub == original.selectedClub)
        #expect(restored.round == original.round)
        #expect(restored.clubs == original.clubs)
        #expect(restored.lineup == original.lineup)
        #expect(store.season?.selectedClub == 2)
    }

    @Test @MainActor func failedCopyPreservesCurrentCareer() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = GameStore(saveURL: folder.appending(path: "season.json"))
        store.generateCareerData()
        store.start(1)
        let saved = try Data(contentsOf: store.saveURL)
        #expect(!store.save(to: store.saveURL.appending(path: "copy.json")))
        #expect(store.error != nil)
        #expect(store.season?.selectedClub == 1)
        #expect(try Data(contentsOf: store.saveURL) == saved)
    }

    @Test func generatedLeagueHasPlayableSquads() {
        var rng = SeasonTests.Seeded()
        let clubs = Database.generateFictionalLeague(using: &rng)
        #expect(clubs.count == 8)
        let players = clubs.flatMap(\.players)
        #expect(players.count == 160)
        #expect(Set(players.map(\.id)).count == 160)
        #expect(players.allSatisfy { (50...89).contains($0.rating) })
        for club in clubs {
            #expect(club.players.filter { $0.role == "GK" }.count >= 1)
            #expect(club.players.filter { $0.role == "DEF" }.count >= 4)
            #expect(club.players.filter { $0.role == "MID" }.count >= 4)
            #expect(club.players.filter { $0.role == "FWD" }.count >= 2)
        }
        #expect(clubs != Database.generateFictionalLeague(using: &rng))
    }

    @Test func olderPlayerSavesRemainReadable() throws {
        let data = Data(#"{"id":1,"name":"Existing player","role":"MID","rating":65}"#.utf8)
        let player = try JSONDecoder().decode(Footballer.self, from: data)
        #expect(player.profile == nil)
        #expect(player.name == "Existing player")
    }

    @Test @MainActor func incompleteTeamDoesNotBlockReadyClubs() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = GameStore(saveURL: folder.appending(path: "season.json"))
        let db = try FootballDatabase(url: store.databaseURL, writable: true)
        _ = try db.generate(.team, count: 1, includeSquads: false)
        _ = try db.generate(.team, count: 2, includeSquads: true)
        store.useDatabase()
        #expect(store.error == nil)
        #expect(store.available.count == 2)
        #expect(store.incompleteClubs.count == 1)
        let club = try #require(store.available.first)
        store.start(club.id)
        #expect(store.season?.lineup.count == 11)
        #expect(store.season?.clubs.count == 2)
        let profile = try #require(store.season?.clubs.first?.players.first?.profile)
        #expect(!profile.foot.isEmpty)
        #expect(profile.values["player_skills_phys_pace"] != nil)
        let restored = try JSONDecoder().decode(Season.self, from: Data(contentsOf: store.saveURL))
        #expect(restored.clubs.first?.players.first?.profile == profile)
        #expect(try db.records(.team).count == 3)
        // Generated CSV squads may need goalkeeper cover or retirement replacements.
        while let season = store.season, season.goalkeepersNeeded > 0 || season.replacementsNeeded > 0 {
            let replacement = try #require(season.transferMarket.first {
                $0.clubID == season.youthMarketClubID && (season.goalkeepersNeeded == 0 || $0.player.role == "GK")
            })
            #expect(store.buyPlayer(replacement.id, offer: 120))
        }
        store.autoPick()
        store.play()
        #expect(store.error == nil)
    }

    @Test @MainActor func generationRequiresOptInAndDoesNotReplaceSavedCareer() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "season.json")
        let store = GameStore(saveURL: url)
        #expect(store.available.isEmpty)
        #expect(store.season == nil)
        store.generateCareerData()
        #expect(store.available.count == 8)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        store.start(1)
        let saved = try Data(contentsOf: url)
        store.prepareCareer()
        #expect(store.available.isEmpty)
        store.generateCareerData()
        #expect(try Data(contentsOf: url) == saved)
        store.prepareCareer() // Back or Cancel discards the draft.
        #expect(try Data(contentsOf: url) == saved)
        #expect(store.season?.selectedClub == 1)
        #expect(store.season?.lineup.count == 11)
        store.useDatabase()
        #expect(store.available.isEmpty)
        #expect(store.error != nil)
        #expect(!store.isDemo)
    }
}
