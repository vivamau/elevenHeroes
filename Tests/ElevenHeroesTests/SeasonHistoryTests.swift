import Foundation
import Testing
@testable import ElevenHeroes

struct SeasonHistoryTests {
    @Test func recordsWholeLeagueAndArchivesStatistics() throws {
        let clubs = Array(Database.demo.prefix(4))
        var season = Season(clubs: clubs, fixtures: Season.schedule(clubs), selectedClub: 1, demo: true)
        season.lineup = Array(clubs[0].players.prefix(11).map(\.id))
        var rng = SeasonTests.Seeded(state: 42)
        while !season.finished { season.simulate(using: &rng) }
        for fixture in season.fixtures {
            let events = try #require(fixture.goalEvents)
            #expect(events.allSatisfy { (1...90).contains($0.minute ?? 0) })
            #expect(events.filter { $0.clubID == fixture.home }.count == fixture.homeGoals)
            #expect(events.filter { $0.clubID == fixture.away }.count == fixture.awayGoals)
            #expect(events.allSatisfy { $0.scorerID != nil && ($0.assistID == nil || $0.scorerID != $0.assistID) })
        }
        let goals = season.fixtures.reduce(0) { $0 + ($1.homeGoals ?? 0) + ($1.awayGoals ?? 0) }
        let points = season.standings.map(\.points)
        try season.startNextSeason()
        let archive = try #require(season.completedSeasons?.first)
        #expect(archive.hasCompletePlayerStats)
        #expect(archive.leaders(assists: false).reduce(0) { $0 + $1.total } == goals)
        #expect(archive.leaders(assists: true).reduce(0) { $0 + $1.total } <= goals)
        #expect(archive.table(fallbackClubs: []).map(\.points) == points)
        #expect(season.fixtures.allSatisfy { $0.goalEvents == nil })
        let decoded = try JSONDecoder().decode(Season.self, from: JSONEncoder().encode(season))
        #expect(decoded.completedSeasons?.first?.fixtures.first?.goalEvents?.map(\.minute) == archive.fixtures.first?.goalEvents?.map(\.minute))
        #expect(decoded.completedSeasons?.first?.leaders(assists: false).first?.total == archive.leaders(assists: false).first?.total)
    }

    @Test func legacyArchivesKeepTableWithoutInventingPlayerStats() throws {
        let clubs = Array(Database.demo.prefix(2))
        let fixture = Fixture(id: 0, round: 1, home: 1, away: 2, homeGoals: 2, awayGoals: 1)
        let archive = CompletedSeason(year: 2026, fixtures: [fixture], champion: clubs[0].name)
        #expect(!archive.hasCompletePlayerStats)
        #expect(archive.leaders(assists: false).isEmpty)
        #expect(archive.leaders(assists: true).isEmpty)
        #expect(archive.table(fallbackClubs: clubs).first?.points == 3)
    }
}
