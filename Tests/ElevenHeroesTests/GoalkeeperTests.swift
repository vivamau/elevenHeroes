import Testing
@testable import ElevenHeroes

struct GoalkeeperTests {
    private func career() -> Season {
        Season(clubs: Array(Database.demo.prefix(2)), fixtures: [], selectedClub: 1, demo: true)
    }
    @Test func sellingRequiresThreeGoalkeepers() throws {
        var s = career()
        let keeper = s.clubs[0].players[0].id
        #expect(s.goalkeeperCount == 2)
        #expect(!s.canSellPlayer(keeper))
        #expect(throws: (any Error).self) { try s.sellPlayer(keeper) }
        s.clubs[0].players.append(Footballer(id: 999, name: "Extra keeper", role: "GK", rating: 60))
        #expect(s.canSellPlayer(keeper))
        try s.sellPlayer(keeper)
        #expect(s.goalkeeperCount == 2)
    }
    @Test func buyingCannotStripSellingClubOfKeepers() throws {
        var s = career()
        let keeper = s.clubs[1].players[0].id
        #expect(throws: (any Error).self) { try s.buyPlayer(keeper, offer: 120) }
        #expect(s.credits == 10_000)
        s.clubs[1].players.append(Footballer(id: 999, name: "Extra keeper", role: "GK", rating: 60))
        try s.buyPlayer(keeper, offer: 120)
        #expect(s.clubs[1].players.filter { $0.role == "GK" }.count == 2)
    }
    @Test func repairsComputerTeamsAndSuppliesManagerMarketWithoutFreeSigning() throws {
        var s = career()
        for index in s.clubs.indices { s.clubs[index].players.removeAll { $0.role == "GK" } }
        s.retireIneligiblePlayers()
        #expect(s.clubs[1].players.filter { $0.role == "GK" }.count == 2)
        #expect(s.goalkeepersNeeded == 2)
        #expect(s.credits == 10_000)
        let offers = s.transferMarket.filter { $0.clubID == s.youthMarketClubID && $0.player.role == "GK" }
        #expect(offers.count == 2)
        s.ensureGoalkeeperCover()
        #expect(s.transferMarket.filter { $0.clubID == s.youthMarketClubID && $0.player.role == "GK" }.count == 2)
        for offer in offers { try s.buyPlayer(offer.id, offer: 120) }
        #expect(s.goalkeepersNeeded == 0)
        #expect(s.credits == 9760)
    }
}
