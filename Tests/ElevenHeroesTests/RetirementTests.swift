import Foundation
import Testing
@testable import ElevenHeroes

struct RetirementTests {
    @Test func retirementRemovesPlayersAndRequiresManagerPurchase() throws {
        var clubs = Array(Database.demo.prefix(2))
        clubs[0].players[0].careerAge = 40
        clubs[1].players[0].careerAge = 40
        let ownRetired = clubs[0].players[0].id
        let otherRetired = clubs[1].players[0].id
        var s = Season(clubs: clubs, fixtures: Season.schedule(clubs), selectedClub: 1, demo: true)
        s.lineup = Array(clubs[0].players.prefix(11).map(\.id))
        s.listedPlayerIDs = [ownRetired]
        var rng = SeasonTests.Seeded(state: 42)
        while !s.finished { s.simulate(using: &rng) }
        try s.startNextSeason()
        #expect(s.clubs[0].players.count == 19)
        #expect(s.clubs[1].players.count == 20)
        #expect(s.replacementsNeeded == 1)
        #expect(!s.lineup.contains(ownRetired))
        #expect(s.listedPlayerIDs == [])
        #expect(!s.transferMarket.contains { $0.id == ownRetired || $0.id == otherRetired })
        #expect(s.retiredPlayers?.count == 2)
        #expect(s.replacementTransfers?.count == 1)
        #expect(s.clubs.flatMap(\.players).allSatisfy { $0.age(in: s.year) < 41 })
        s.simulate(using: &rng)
        #expect(s.round == 1)
        let replacement = try #require(s.transferMarket.first { $0.clubID == s.youthMarketClubID })
        let price = (replacement.player.creditsValue * 120 + 99) / 100
        let budgetBeforePurchase = s.credits
        try s.buyPlayer(replacement.id, offer: price)
        #expect(s.replacementsNeeded == 0)
        #expect(s.credits == budgetBeforePurchase - price)
        #expect(s.squadCount == 20)
        let loaded = try JSONDecoder().decode(Season.self, from: JSONEncoder().encode(s))
        #expect(loaded.retiredPlayers?.count == 2)
        #expect(loaded.replacementsNeeded == 0)
    }

    @Test func retirementIsIdempotentAndIncludesOlderMarketPlayers() {
        var clubs = Array(Database.demo.prefix(2))
        clubs[0].players[0].careerAge = 45
        var s = Season(clubs: clubs, fixtures: [], selectedClub: 1, demo: true)
        s.marketPlayers = [MarketPlayer(player: Footballer(id: 9999, name: "Older", role: "MID", rating: 70, careerAge: 41), clubID: 99, clubName: "Outside")]
        s.retireIneligiblePlayers()
        s.retireIneligiblePlayers()
        #expect(s.replacementsNeeded == 1)
        #expect(s.retiredPlayers?.count == 2)
        #expect(!s.transferMarket.contains { $0.id == 9999 })
    }
}
