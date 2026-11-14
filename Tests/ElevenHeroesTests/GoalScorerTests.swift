import Testing
@testable import ElevenHeroes

struct GoalScorerTests {
    private let keeper = Footballer(id: 1, name: "Keeper", role: "GK", rating: 99)
    private let forward = Footballer(id: 2, name: "Forward", role: "ST", rating: 70)

    @Test func goalkeeperGoalsArePossibleButExceptionallyRare() {
        let simulator = MatchSimulator()
        let squad = [keeper, forward]
        var rng = SeasonTests.Seeded(state: 42)
        var keeperGoals = 0
        for _ in 0..<100_000 {
            let scorer = simulator.scorer(from: squad, rng: &rng)
            #expect(scorer != nil)
            if scorer?.role == "GK" { keeperGoals += 1 }
        }
        // Seeded sampling catches both accidental exclusion and equal-chance selection.
        #expect(keeperGoals > 0)
        #expect(keeperGoals < 40)
    }

    @Test func handlesSquadsWithoutOutfieldPlayersOrGoalkeepers() {
        let simulator = MatchSimulator()
        var rng = SeasonTests.Seeded(state: 7)
        #expect(simulator.scorer(from: [], rng: &rng) == nil)
        #expect(simulator.scorer(from: [keeper], rng: &rng)?.id == keeper.id)
        for _ in 0..<100 {
            #expect(simulator.scorer(from: [forward], rng: &rng)?.id == forward.id)
        }
    }
}
