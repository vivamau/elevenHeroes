import Foundation
import Testing
@testable import ElevenHeroes

struct ScoreCalculationTests {
    @Test func recordedDrawsExplainTheScoreAndSurviveSaving() throws {
        let clubs = Array(Database.demo.prefix(4))
        var season = Season(clubs: clubs, fixtures: Season.schedule(clubs), selectedClub: clubs[0].id, demo: true)
        season.lineup = Array(clubs[0].players.prefix(11).map(\.id))
        var rng = SeasonTests.Seeded(state: 42)
        season.simulate(using: &rng)
        let fixture = try #require(season.fixtures.first { $0.round == 1 && ($0.home == season.selectedClub || $0.away == season.selectedClub) })
        let initial = try #require(fixture.scoreCalculations?.first)
        for home in [true, false] {
            let draws = initial.draws.filter { $0.home == home }
            let goals = home ? initial.homeGoals : initial.awayGoals
            #expect(min(initial.maxGoals, draws.count - 1) == goals)
            let expected = home ? initial.home.expected : initial.away.expected
            #expect(draws.reduce(1.0) { $0 * $1.value } <= exp(-expected) || goals == initial.maxGoals)
        }
        var parameters = MatchSimulationParameters.default
        parameters.setStrategyShare("Defensive", to: 1)
        let updated = try #require(season.changeStrategy(fixtureID: fixture.id, after: 45, tactic: "Defensive", parameters: parameters, rng: &rng))
        let stage = try #require(updated.scoreCalculations?.last)
        #expect(updated.scoreCalculations?.count == 2)
        #expect(stage.afterMinute == 45)
        for home in [true, false] {
            let clubID = home ? fixture.home : fixture.away
            let retained = (fixture.goalEvents ?? []).filter { $0.clubID == clubID && ($0.minute ?? 90) <= 45 }.count
            let expected = home ? stage.home.expected : stage.away.expected
            let added = stage.draws.filter { $0.home == home && $0.value < 1 - exp(-expected / 90) }.count
            #expect(retained + added == (home ? updated.homeGoals : updated.awayGoals))
        }
        let decoded = try JSONDecoder().decode(Fixture.self, from: JSONEncoder().encode(updated))
        #expect(decoded.scoreCalculations?.last?.draws.map(\.value) == stage.draws.map(\.value))
        let legacy = try JSONDecoder().decode(Fixture.self, from: Data(#"{"id":1,"round":1,"home":1,"away":2}"#.utf8))
        #expect(legacy.scoreCalculations == nil)
    }
}
