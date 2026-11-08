import Testing
@testable import ElevenHeroes

struct PlayerSeasonTotalsTests {
    @Test func totalsFollowPlayerAcrossClubsAndSeparateSeasons() {
        let events = [GoalEvent(clubID: 1, clubName: "One", scorerID: 7, scorerName: "Player", assistID: 8, assistName: "Other"),
                      GoalEvent(clubID: 2, clubName: "Two", scorerID: 8, scorerName: "Other", assistID: 7, assistName: "Player"),
                      GoalEvent(clubID: 2, clubName: "Two", scorerID: 7, scorerName: "Player", assistID: nil, assistName: nil)]
        let past = Fixture(id: 1, round: 1, home: 1, away: 2, homeGoals: 1, awayGoals: 2, goalEvents: events)
        var season = Season(clubs: [], fixtures: [Fixture(id: 2, round: 1, home: 1, away: 2, homeGoals: 0, awayGoals: 0, goalEvents: [])], selectedClub: 1, demo: true)
        season.seasonYear = 2027
        season.completedSeasons = [CompletedSeason(year: 2026, fixtures: [past], champion: "Two")]
        let totals = season.playerSeasonTotals(7)
        #expect(totals.map(\.year) == [2026, 2027])
        #expect(totals.map(\.goals) == [2, 0])
        #expect(totals.map(\.assists) == [1, 0])
        #expect(totals.allSatisfy { $0.complete })
        #expect(totals.map(\.current) == [false, true])
        season.fixtures[0].goalEvents = nil
        #expect(season.playerSeasonTotals(7).last?.complete == false)
    }
}
