import Foundation
import Testing
@testable import ElevenHeroes

struct IncomingOfferTests {
    private func career(count: Int = 18) -> Season {
        let own = Club(id: 1, name: "Home", city: "", players: (1...count).map {
            Footballer(id: $0, name: "Player \($0)", role: "MID", rating: 60, marketValue: 50)
        })
        let buyer = Club(id: 2, name: "Visitors", city: "", players: [])
        return Season(clubs: [own, buyer], fixtures: [], selectedClub: 1, demo: true)
    }

    @Test func generationIsStableAndUsesLeagueClubs() throws {
        var season = career()
        var rng = SeasonTests.Seeded(state: 42)
        season.generateIncomingOffers(using: &rng)
        #expect(season.pendingOffers.isEmpty)
        season.round = 2
        season.generateIncomingOffers(using: &rng)
        let bids = season.pendingOffers
        #expect(bids.count == 3)
        #expect(Set(bids.map(\.playerID)).count == 3)
        #expect(bids.allSatisfy { $0.buyerClubID == 2 && (50...60).contains($0.credits) })
        season.generateIncomingOffers(using: &rng)
        #expect(season.pendingOffers == bids)
        try season.rejectOffer(bids[0].id)
        season.generateIncomingOffers(using: &rng)
        #expect(season.pendingOffers.count == 2)
        season.round += 1
        season.generateIncomingOffers(using: &rng)
        #expect(season.pendingOffers.count == 5)
        let loaded = try JSONDecoder().decode(Season.self, from: JSONEncoder().encode(season))
        #expect(loaded.pendingOffers == season.pendingOffers)
        #expect(loaded.offersGeneratedRound == season.round)
    }

    @Test func listingWaitsForMatchweekAndAcceptanceUsesExactTerms() throws {
        var season = career()
        try season.listPlayerForTransfer(1)
        #expect(season.pendingOffers.isEmpty)
        season.round = 2
        var rng = SeasonTests.Seeded(state: 42)
        season.generateIncomingOffers(using: &rng)
        let bid = try #require(season.pendingOffers.first)
        try season.listPlayerForTransfer(1)
        #expect(season.pendingOffers.count == 3)
        try season.acceptOffer(bid.id)
        #expect(season.credits == 10_000 + bid.credits)
        #expect(season.squadCount == 17)
        #expect(season.clubs[1].players.contains { $0.id == 1 })
        #expect(season.pendingOffers.count == 2)
        #expect(season.listedPlayerIDs == [])
        #expect(throws: (any Error).self) { try season.acceptOffer(bid.id) }
    }

    @Test func minimumSquadBlocksAcceptanceButAllowsRejection() throws {
        var season = career(count: 16)
        try season.listPlayerForTransfer(1)
        #expect(season.pendingOffers.isEmpty)
        season.round = 2
        var rng = SeasonTests.Seeded(state: 42)
        season.generateIncomingOffers(using: &rng)
        let bid = try #require(season.pendingOffers.first)
        let offers = season.pendingOffers
        let clubs = season.clubs
        #expect(throws: (any Error).self) { try season.acceptOffer(bid.id) }
        #expect(season.clubs == clubs)
        #expect(season.credits == 10_000)
        #expect(season.pendingOffers == offers)
        try season.rejectOffer(bid.id)
        #expect(season.pendingOffers.count == 2)
        #expect(season.clubs == clubs)
    }

    @Test @MainActor func failedSavePreservesOfferAndRoster() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = GameStore(saveURL: folder)
        var season = career()
        try season.listPlayerForTransfer(1)
        season.round = 2
        var rng = SeasonTests.Seeded(state: 42)
        season.generateIncomingOffers(using: &rng)
        store.season = season
        let bid = try #require(season.pendingOffers.first)
        #expect(!store.acceptOffer(bid.id))
        #expect(store.season?.pendingOffers == season.pendingOffers)
        #expect(store.season?.clubs == season.clubs)
        #expect(store.season?.credits == 10_000)
    }
}
