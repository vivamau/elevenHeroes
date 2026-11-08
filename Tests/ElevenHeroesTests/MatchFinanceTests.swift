import Testing
@testable import ElevenHeroes

struct MatchFinanceTests {
    @Test func financesUseTheCorrectClubAndPreserveUnknownAmounts() {
        var fixture = Fixture(id: 1, round: 1, home: 1, away: 2, homeGoals: 1, awayGoals: 0)
        #expect(MatchFinance(fixture: fixture, clubID: 1).net == nil)
        #expect(MatchFinance(fixture: fixture, clubID: 2).income == 0)
        #expect(MatchFinance(fixture: fixture, clubID: 2).net == nil)
        fixture.ticketRevenue = 30_000
        fixture.homeWages = 4_000
        fixture.awayWages = 5_000
        #expect(MatchFinance(fixture: fixture, clubID: 1).net == 26_000)
        #expect(MatchFinance(fixture: fixture, clubID: 2).net == -5_000)
    }
}
