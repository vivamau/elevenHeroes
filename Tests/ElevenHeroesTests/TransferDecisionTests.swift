import Foundation
import Testing
@testable import ElevenHeroes

struct TransferDecisionTests {
    private func career(starRating: Int = 100, value: Int = 50) -> Season {
        let buyer = Club(id: 1, name: "Buyer", city: "", players: (1...16).map {
            Footballer(id: $0, name: "Buyer \($0)", role: "MID", rating: 60, marketValue: 50)
        })
        let star = Footballer(id: 100, name: "Key player", role: "MID", rating: starRating, marketValue: value)
        let seller = Club(id: 2, name: "Seller", city: "", players: [star] + (101...111).map {
            Footballer(id: $0, name: "Seller \($0)", role: "MID", rating: 60, marketValue: 50)
        })
        return Season(clubs: [buyer, seller], fixtures: [], selectedClub: 1, demo: true)
    }

    @Test func basePriceRejectedWhenOverallDropsMoreThanTwo() throws {
        var season = career()
        let clubs = season.clubs
        #expect(season.sellingClubOverallDrop(for: 100) > 2)
        #expect(throws: (any Error).self) { try season.buyPlayer(100, offer: 50) }
        #expect(season.clubs == clubs)
        #expect(season.credits == 10_000)
        #expect(season.marketPlayers == nil)
    }

    @Test(arguments: [81, 82]) func atMostTwoPointDropAcceptsBasePrice(starRating: Int) throws {
        var season = career(starRating: starRating)
        #expect(season.sellingClubOverallDrop(for: 100) <= 2)
        try season.buyPlayer(100, offer: 50)
        #expect(season.credits == 9950)
    }

    @Test(arguments: Array(UInt64(0)...31)) func randomPremiumUsesFiveToTwentyPercentAndRoundsUp(seed: UInt64) throws {
        var previewRNG = SeasonTests.Seeded(state: seed)
        let premium = Int.random(in: 5...20, using: &previewRNG)
        let minimum = (51 * (100 + premium) + 99) / 100
        #expect((54...62).contains(minimum))
        var rejected = career(value: 51)
        var rejectionRNG = SeasonTests.Seeded(state: seed)
        #expect(throws: (any Error).self) { try rejected.buyPlayer(100, offer: minimum - 1, using: &rejectionRNG) }
        #expect(rejected.credits == 10_000)
        var accepted = career(value: 51)
        var acceptanceRNG = SeasonTests.Seeded(state: seed)
        try accepted.buyPlayer(100, offer: minimum, using: &acceptanceRNG)
        #expect(accepted.credits == 10_000 - minimum)
        #expect(accepted.clubs[0].players.contains { $0.id == 100 })
    }

    @Test func outsideLeagueClubsReceiveSameProtection() throws {
        var season = career()
        let seller = season.clubs.removeLast()
        season.marketPlayers = seller.players.map { MarketPlayer(player: $0, clubID: seller.id, clubName: seller.name) }
        #expect(season.sellingClubOverallDrop(for: 100) > 2)
        #expect(throws: (any Error).self) { try season.buyPlayer(100, offer: 50) }
        try season.buyPlayer(100, offer: 60)
        #expect(season.credits == 9940)
    }

    @Test @MainActor func rejectedOfferDoesNotChangeAutosave() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = GameStore(saveURL: folder.appending(path: "season.json"))
        store.season = career()
        store.save()
        let original = try Data(contentsOf: store.saveURL)
        #expect(!store.buyPlayer(100, offer: 50))
        #expect(store.error?.contains("refused") == true)
        #expect(store.season?.credits == 10_000)
        #expect(try Data(contentsOf: store.saveURL) == original)
    }
}
