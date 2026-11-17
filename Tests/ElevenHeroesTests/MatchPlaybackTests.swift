import Testing
@testable import ElevenHeroes

struct MatchPlaybackTests {
    @Test func halfTimeStopsAt45EvenWhenClockOvershoots() {
        #expect(MatchPlayback.playbackTime(proposed: 28.4, halfTimeTaken: false) == 28.4)
        #expect(MatchPlayback.playbackTime(proposed: 30, halfTimeTaken: false) == 28.5)
        #expect(MatchPlayback.playbackTime(proposed: 65, halfTimeTaken: false) == 28.5)
        #expect(MatchPlayback.playbackTime(proposed: 30, halfTimeTaken: true) == 30)
        #expect(MatchPlayback.playbackTime(proposed: 65, halfTimeTaken: true) == 60)
    }

    @Test func revealsGoalsAtTheirScheduledTimesAndEndsWithinOneMinute() {
        var fixture = Fixture(id: 1, round: 1, home: 10, away: 20, homeGoals: 2, awayGoals: 1)
        fixture.goalEvents = [
            GoalEvent(clubID: 10, clubName: "Home", scorerID: 1, scorerName: "A", assistID: nil, assistName: nil, minute: 30),
            GoalEvent(clubID: 20, clubName: "Away", scorerID: 2, scorerName: "B", assistID: nil, assistName: nil, minute: 30),
            GoalEvent(clubID: 10, clubName: "Home", scorerID: 1, scorerName: "A", assistID: nil, assistName: nil, minute: 90)
        ]
        let match = MatchPlayback(fixture: fixture, home: "Home", away: "Away")
        #expect(MatchPlayback.duration == 60)
        #expect(match.score(at: 0).home == 0 && match.score(at: 0).away == 0)
        #expect(match.score(at: 18).home == 0)
        #expect(match.score(at: 19).home == 1 && match.score(at: 19).away == 1)
        #expect(match.score(at: 60).home == 2 && match.score(at: 60).away == 1)
        #expect(match.actions.allSatisfy { $0.time <= 57 })
        #expect(Set(match.actions.map(\.id)).count == match.actions.count)
        #expect(match.actions.compactMap(\.goal).count == 3)
    }

    @Test func goallessMatchStillHasActionCommentary() {
        let fixture = Fixture(id: 1, round: 1, home: 10, away: 20, homeGoals: 0, awayGoals: 0, goalEvents: [])
        let match = MatchPlayback(fixture: fixture, home: "Home", away: "Away")
        #expect(match.actions.count > 5)
        #expect(match.actions.first?.minute == 0)
        #expect(match.score(at: 60).home == 0 && match.score(at: 60).away == 0)
    }
}
