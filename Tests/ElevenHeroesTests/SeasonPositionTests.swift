import Testing
@testable import ElevenHeroes

struct SeasonPositionTests {
    @Test func ranksUseCumulativeResultsIncludingByesAndLegacyArchives() {
        let clubs = [Club(id: 1, name: "Alpha", city: "", players: []), Club(id: 2, name: "Beta", city: "", players: []), Club(id: 3, name: "Gamma", city: "", players: [])]
        let fixtures = [Fixture(id: 0, round: 1, home: 1, away: 2, homeGoals: 1, awayGoals: 0),
                        Fixture(id: 1, round: 2, home: 2, away: 3, homeGoals: 3, awayGoals: 0),
                        Fixture(id: 2, round: 3, home: 3, away: 1, homeGoals: 0, awayGoals: 2)]
        let archive = CompletedSeason(year: 2026, fixtures: fixtures, champion: "Alpha")
        let points = archive.positions(fallbackClubs: clubs)
        #expect(points.count == 9)
        #expect(points.filter { $0.round == 1 }.map(\.clubID) == [1, 3, 2])
        #expect(points.filter { $0.round == 2 }.map(\.clubID) == [2, 1, 3])
        #expect(points.filter { $0.round == 3 }.map(\.clubID) == archive.table(fallbackClubs: clubs).map(\.id))
        #expect(points.filter { $0.clubID == 1 }.map(\.position) == [1, 2, 1])
    }
}
