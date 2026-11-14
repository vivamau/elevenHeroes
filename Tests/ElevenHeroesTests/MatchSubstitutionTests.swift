import Foundation
import Testing
@testable import ElevenHeroes

struct MatchSubstitutionTests {
    @Test func substitutionPreservesPastAndChangesOnlyMatchLineup() throws {
        let clubs = Array(Database.demo.prefix(4))
        var season = Season(clubs: clubs, fixtures: Season.schedule(clubs), selectedClub: clubs[0].id, demo: true)
        let squad = clubs[0].players
        season.lineup = [squad[0].id] + Array(squad.filter { $0.role != "GK" }.prefix(10).map(\.id))
        season.substitutes = Array(squad.filter { !season.lineup.contains($0.id) }.prefix(5).map(\.id))
        let savedLineup = season.lineup
        var rng = SeasonTests.Seeded(state: 42)
        season.simulate(using: &rng)
        let original = try #require(season.fixtures.first { $0.round == 1 && ($0.home == season.selectedClub || $0.away == season.selectedClub) })
        let off = try #require(squad.first { original.activeLineup(for: season.selectedClub).contains($0.id) && $0.role != "GK" })
        let on = try #require(squad.first { original.availableBench(for: season.selectedClub).contains($0.id) && $0.role != "GK" })
        let result = try season.substitute(fixtureID: original.id, outgoing: off.id, incoming: on.id,
            minute: 30, parameters: .default, rng: &rng)
        let stage = try #require(result.scoreCalculations?.last)
        let impact = try #require(stage.substitutionImpact)
        let strengthChange = Double(on.rating - off.rating) / 11
        #expect(abs(impact.strengthAfter - impact.strengthBefore - strengthChange) < 0.000001)
        let expectedHomeChange = strengthChange * MatchSimulationParameters.default.powerWeight * (original.home == season.selectedClub ? 1 : -1)
        #expect(abs(stage.home.strength - impact.homeBefore.strength - expectedHomeChange) < 0.000001)
        #expect(abs(stage.away.strength - impact.awayBefore.strength + expectedHomeChange) < 0.000001)
        #expect(impact.change.outgoingID == off.id && impact.change.incomingID == on.id)
        #expect(result.activeLineup(for: season.selectedClub).count == 11)
        #expect(result.activeLineup(for: season.selectedClub).contains(on.id))
        #expect(!result.activeLineup(for: season.selectedClub).contains(off.id))
        #expect(!result.availableBench(for: season.selectedClub).contains(on.id))
        #expect(season.lineup == savedLineup)
        #expect(result.homeLineup == original.homeLineup && result.awayLineup == original.awayLineup)
        #expect((result.goalEvents ?? []).filter { ($0.minute ?? 90) <= 30 }.map(\.scorerID) == (original.goalEvents ?? []).filter { ($0.minute ?? 90) <= 30 }.map(\.scorerID))
        #expect((result.goalEvents ?? []).filter { ($0.minute ?? 90) > 30 }.allSatisfy { $0.scorerID != off.id && $0.assistID != off.id })
        #expect(throws: (any Error).self) {
            try season.substitute(fixtureID: original.id, outgoing: on.id, incoming: off.id, minute: 31, parameters: .default, rng: &rng)
        }
        let decoded = try JSONDecoder().decode(Fixture.self, from: JSONEncoder().encode(result))
        #expect(decoded.scoreCalculations?.last?.substitutionImpact?.strengthAfter == impact.strengthAfter)
        #expect(decoded.scoreCalculations?.last?.substitutionImpact?.homeBefore.expected == impact.homeBefore.expected)
        #expect(decoded.substitutions?.first?.incomingID == on.id)
        #expect(decoded.activeLineup(for: season.selectedClub) == result.activeLineup(for: season.selectedClub))
    }
}
