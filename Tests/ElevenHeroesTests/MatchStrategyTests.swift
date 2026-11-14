import Testing
@testable import ElevenHeroes

struct MatchStrategyTests {
    @Test func changesOnlyFutureGoalsAndPreservesSeasonSettingsAndFinances() throws {
        let clubs = Array(Database.demo.prefix(4))
        var season = Season(clubs: clubs, fixtures: Season.schedule(clubs), selectedClub: clubs[0].id, demo: true)
        season.lineup = Array(clubs[0].players.prefix(11).map(\.id))
        var rng = SeasonTests.Seeded(state: 42)
        season.simulate(using: &rng)
        let fixture = try #require(season.fixtures.first { $0.round == 1 && ($0.home == season.selectedClub || $0.away == season.selectedClub) })
        let credits = season.credits
        let tactic = season.tactic
        let originalParameters = season.matchParameters
        var parameters = MatchSimulationParameters.default
        parameters.setStrategyShare("Attacking", to: 1)
        let result = try #require(season.changeStrategy(fixtureID: fixture.id, after: 45, tactic: "Attacking", parameters: parameters, rng: &rng))
        let oldGoals = (fixture.goalEvents ?? []).filter { ($0.minute ?? 90) <= 45 }
        let preserved = (result.goalEvents ?? []).filter { ($0.minute ?? 90) <= 45 }
        #expect(oldGoals.map(\.scorerID) == preserved.map(\.scorerID))
        #expect(oldGoals.map(\.minute) == preserved.map(\.minute))
        #expect(season.credits == credits)
        #expect(result.ticketRevenue == fixture.ticketRevenue)
        #expect(result.homeWages == fixture.homeWages)
        #expect(result.awayWages == fixture.awayWages)
        #expect(season.tactic == tactic)
        #expect(season.matchParameters?.tactics["Attacking"]?.attack == originalParameters?.tactics["Attacking"]?.attack)
        #expect(result.homeGoals == result.goalEvents?.filter { $0.clubID == fixture.home }.count)
        #expect(result.awayGoals == result.goalEvents?.filter { $0.clubID == fixture.away }.count)
        #expect(season.changeStrategy(fixtureID: fixture.id, after: 90, tactic: "Defensive", parameters: parameters, rng: &rng) == nil)
    }

    @Test func strategyBoostAppliesToTheSelectedTeam() {
        let clubs = Array(Database.demo.prefix(2))
        func rates(_ tactic: String) -> (Double, Double) {
            var parameters = MatchSimulationParameters.default
            parameters.setStrategyShare(tactic, to: 1)
            let simulator = MatchSimulator(parameters: parameters)
            return simulator.expectedGoals(context: MatchSimulationContext(home: clubs[0], away: clubs[1], selectedClub: clubs[1].id,
                lineup: [], tactic: tactic, round: 1, fixtures: [], year: 2026))
        }
        let balanced = rates("Balanced")
        let attacking = rates("Attacking")
        let defensive = rates("Defensive")
        #expect(attacking.1 >= balanced.1)
        #expect(defensive.0 <= balanced.0)
        #expect(defensive.1 <= balanced.1)
    }
}
