import Foundation
import Testing
@testable import ElevenHeroes

struct CareerSeasonTests {
    private func career() -> Season {
        let clubs = Array(Database.demo.prefix(2))
        var s = Season(clubs: clubs, fixtures: Season.schedule(clubs), selectedClub: clubs[0].id, demo: true)
        s.seasonYear = 2026
        s.lineup = Array(clubs[0].players.prefix(11).map(\.id))
        s.creditBalance = 9123
        s.prepareCalendar()
        return s
    }

    @Test func continuingResetsCompetitionAndPreservesCareer() throws {
        var s = career()
        s.marketPlayers = [MarketPlayer(player: s.clubs[0].players[0], clubID: 1, clubName: "Home")]
        let player = s.clubs[0].players[0]
        let lineup = s.lineup
        var rng = SeasonTests.Seeded(state: 42)
        while !s.finished { s.simulate(using: &rng) }
        let earnedBudget = s.credits
        let fixtures = s.fixtures
        let champion = s.standings[0].club.name
        s.generateIncomingOffers(using: &rng)
        try s.startNextSeason()
        #expect(s.year == 2027)
        #expect(s.round == 1)
        #expect(!s.finished)
        #expect(s.fixtures.allSatisfy { $0.homeGoals == nil && $0.awayGoals == nil })
        #expect(s.standings.allSatisfy { $0.played == 0 && $0.points == 0 })
        #expect(s.credits == earnedBudget)
        #expect(s.lineup == lineup)
        #expect(s.clubs[0].players[0].careerAge == player.careerAge! + 1)
        #expect(s.marketPlayers?[0].player.careerAge == player.careerAge! + 1)
        #expect(s.pendingOffers.isEmpty)
        #expect(s.completedSeasons?.first?.year == 2026)
        #expect(s.completedSeasons?.first?.champion == champion)
        #expect(s.completedSeasons?.first?.fixtures.count == fixtures.count)
        let loaded = try JSONDecoder().decode(Season.self, from: JSONEncoder().encode(s))
        #expect(loaded.year == 2027)
        #expect(loaded.clubs == s.clubs)
        while !s.finished { s.simulate(using: &rng) }
        try s.startNextSeason()
        #expect(s.year == 2028)
        #expect(s.completedSeasons?.count == 2)
        #expect(s.clubs[0].players[0].careerAge == player.careerAge! + 2)
    }

    @Test func ticketPricesPersistAcrossSeasons() throws {
        var s = career()
        s.ticketPrice = 15
        var rng = SeasonTests.Seeded(state: 42)
        while !s.finished { s.simulate(using: &rng) }
        for invalid in [0, -1, 101] {
            #expect(throws: (any Error).self) { try s.startNextSeason(ticketPrice: invalid) }
            #expect(s.year == 2026)
            #expect(s.ticketPrice == 15)
            #expect(s.completedSeasons == nil)
        }
        try s.startNextSeason(ticketPrice: 25)
        let loaded = try JSONDecoder().decode(Season.self, from: JSONEncoder().encode(s))
        #expect(loaded.homeTicketPrice == 25)
        #expect(loaded.completedSeasons?.first?.ticketPrice == 15)
        while !s.finished { s.simulate(using: &rng) }
        try s.startNextSeason()
        #expect(s.homeTicketPrice == 25)
        #expect(s.completedSeasons?.last?.ticketPrice == 25)
        let legacy = try JSONDecoder().decode(Season.self, from: JSONEncoder().encode(career()))
        #expect(legacy.homeTicketPrice == 10)
    }

    @Test func cannotAdvanceUnfinishedSeason() throws {
        var s = career()
        #expect(throws: (any Error).self) { try s.startNextSeason() }
        #expect(s.year == 2026)
        #expect(s.completedSeasons == nil)
    }

    @Test func legacySaveAndBirthDateAges() throws {
        var s = career()
        s.seasonYear = nil
        s.clubs[0].players[0].careerAge = nil
        s.clubs[0].players[0].profile = PlayerProfile(values: ["player_dob": "20000101"], birthCity: "", foot: "", morale: "")
        var loaded = try JSONDecoder().decode(Season.self, from: JSONEncoder().encode(s))
        loaded.prepareCalendar()
        #expect(loaded.year == 2026)
        #expect(loaded.clubs[0].players[0].careerAge == 26)
        loaded.prepareCalendar()
        #expect(loaded.clubs[0].players[0].careerAge == 26)
    }

    @Test @MainActor func failedSaveDoesNotAdvanceYear() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = GameStore(saveURL: folder)
        var s = career()
        var rng = SeasonTests.Seeded(state: 3)
        while !s.finished { s.simulate(using: &rng) }
        store.season = s
        store.startNextSeason()
        #expect(store.season?.year == 2026)
        #expect(store.season?.clubs == s.clubs)
        #expect(store.error != nil)
    }
}
