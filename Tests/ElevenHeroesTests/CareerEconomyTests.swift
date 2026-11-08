import Foundation
import Testing
@testable import ElevenHeroes

struct CareerEconomyTests {
    @Test func startingPricesScaleWithStadiumAndOverall() throws {
        var clubs = Array(Database.demo.prefix(2))
        clubs[0].stadiumCapacity = 30_000
        var s = Season(clubs: clubs, fixtures: Season.schedule(clubs), selectedClub: clubs[0].id, demo: true)
        s.ticketPrice = 10
        s.marketPlayers = [MarketPlayer(player: Footballer(id: 9999, name: "Outside", role: "MID", rating: 70), clubID: 99, clubName: "Outside")]
        var rng = SeasonTests.Seeded(state: 42)
        s.initializeEconomy(using: &rng)
        #expect(s.economyStadiumIncome == 300_000)
        #expect(s.transferMarket.first { $0.id == 9999 }?.player.creditsValue == 13_636)
        for listing in s.transferMarket {
            let p = listing.player
            #expect(p.creditsValue == Int((300_000.0 / 22 * Double(p.rating) / 70).rounded()))
            #expect(p.currentSalary * 10 >= p.creditsValue)
            #expect(p.currentSalary * 5 <= p.creditsValue)
            #expect(p.valueHistory?.last?.credits == p.creditsValue)
            #expect(p.valueHistory?.last?.salary == p.currentSalary)
        }
        let restored = try JSONDecoder().decode(Season.self, from: JSONEncoder().encode(s))
        #expect(restored.clubs == s.clubs)
        #expect(restored.economyStadiumIncome == 300_000)
        var cheap = Footballer(id: 1, name: "Minimum", role: "GK", rating: 1)
        cheap.initializeEconomy(stadiumIncome: 0, using: &rng)
        #expect(cheap.creditsValue == 100)
        #expect((10...20).contains(cheap.currentSalary))
    }
}
