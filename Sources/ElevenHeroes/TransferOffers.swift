import Foundation

struct TransferOffer: Codable, Identifiable, Equatable {
    let id: UUID
    let playerID: Int
    let buyerClubID: Int
    let credits: Int
    let matchweek: Int
}

extension Season {
    var pendingOffers: [TransferOffer] {
        let ownIDs = Set(clubs.first { $0.id == selectedClub }?.players.map(\.id) ?? [])
        return (incomingOffers ?? []).filter { offer in
            ownIDs.contains(offer.playerID) && offer.buyerClubID != selectedClub
                && clubs.contains { $0.id == offer.buyerClubID } && offer.credits > 0
        }
    }

    mutating func generateIncomingOffers<R: RandomNumberGenerator>(using rng: inout R) {
        guard round > 1, offersGeneratedRound != round else { return }
        offersGeneratedRound = round
        incomingOffers = pendingOffers
        let listed = Set(listedPlayerIDs ?? [])
        let candidates = (clubs.first { $0.id == selectedClub }?.players ?? []).shuffled(using: &rng)
        let ordered = candidates.filter { listed.contains($0.id) } + candidates.filter { !listed.contains($0.id) }
        var count = 0
        for player in ordered where count < 3 {
            if inviteOffer(for: player, using: &rng) { count += 1 }
        }
    }

    @discardableResult
    private mutating func inviteOffer<R: RandomNumberGenerator>(for player: Footballer, using rng: inout R) -> Bool {
        guard !pendingOffers.contains(where: { $0.playerID == player.id }) else { return false }
        let buyers = clubs.filter { $0.id != selectedClub && !$0.players.contains { $0.id == player.id } }
        // Prefer clubs that can improve their depth in the player's role.
        let interested = buyers.filter { club in
            let peers = club.players.filter { $0.role == player.role }
            return peers.count < 2 || player.rating > (peers.map(\.rating).min() ?? 0)
        }
        guard let buyer = (interested.isEmpty ? buyers : interested).randomElement(using: &rng) else { return false }
        let premium = Int.random(in: 0...20, using: &rng)
        let amount = (player.creditsValue * (100 + premium) + 99) / 100
        if incomingOffers == nil { incomingOffers = [] }
        incomingOffers?.append(TransferOffer(id: UUID(), playerID: player.id, buyerClubID: buyer.id, credits: amount, matchweek: round - 1))
        return true
    }

    mutating func listPlayerForTransfer(_ id: Int) throws {
        guard clubs.first(where: { $0.id == selectedClub })?.players.contains(where: { $0.id == id }) == true else {
            throw DatabaseIssue(message: "This player is no longer in your team.")
        }
        guard !(listedPlayerIDs ?? []).contains(id) else { return }
        if listedPlayerIDs == nil { listedPlayerIDs = [] }
        listedPlayerIDs?.append(id)
    }

    mutating func acceptOffer(_ id: UUID) throws {
        guard let offer = pendingOffers.first(where: { $0.id == id }) else {
            throw DatabaseIssue(message: "This offer is no longer available.")
        }
        try sellPlayer(offer.playerID, to: offer.buyerClubID, price: offer.credits)
    }

    mutating func rejectOffer(_ id: UUID) throws {
        guard (incomingOffers ?? []).contains(where: { $0.id == id }) else {
            throw DatabaseIssue(message: "This offer is no longer available.")
        }
        incomingOffers?.removeAll { $0.id == id }
    }
}
