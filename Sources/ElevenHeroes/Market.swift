import Foundation

struct MarketPlayer: Codable, Identifiable {
    let player: Footballer
    let clubID: Int?
    let clubName: String
    var id: Int { player.id }
}

extension Season {
    var goalkeeperCount: Int { clubs.first { $0.id == selectedClub }?.players.filter { $0.role == "GK" }.count ?? 0 }
    var goalkeepersNeeded: Int { max(0, 2 - goalkeeperCount) }
    func canSellPlayer(_ id: Int) -> Bool {
        guard let player = clubs.first(where: { $0.id == selectedClub })?.players.first(where: { $0.id == id }) else { return false }
        return canSellPlayer && (player.role != "GK" || goalkeeperCount > 2)
    }
    var squadCount: Int { clubs.first { $0.id == selectedClub }?.players.count ?? 0 }
    var saleBuyer: Club? {
        clubs.filter { $0.id != selectedClub }.sorted {
            $0.players.count == $1.players.count ? $0.id < $1.id : $0.players.count < $1.players.count
        }.first
    }
    var canSellPlayer: Bool { squadCount > 16 && saleBuyer != nil }

    mutating func sellPlayer(_ id: Int) throws {
        guard let buyer = saleBuyer else { throw DatabaseIssue(message: "No club is available to buy this player.") }
        guard let player = clubs.first(where: { $0.id == selectedClub })?.players.first(where: { $0.id == id }) else {
            throw DatabaseIssue(message: "This player is no longer in your team.")
        }
        try sellPlayer(id, to: buyer.id, price: player.creditsValue)
    }

    mutating func sellPlayer(_ id: Int, to buyerID: Int, price: Int) throws {
        guard let seller = clubs.firstIndex(where: { $0.id == selectedClub }),
              let player = clubs[seller].players.first(where: { $0.id == id }) else {
            throw DatabaseIssue(message: "This player is no longer in your team.")
        }
        guard squadCount > 16 else {
            throw DatabaseIssue(message: "Keep at least 16 players: 11 starters and 5 substitutes.")
        }
        guard player.role != "GK" || goalkeeperCount > 2 else {
            throw DatabaseIssue(message: "Keep at least two goalkeepers in your squad.")
        }
        guard buyerID != selectedClub, price > 0, let buyer = clubs.firstIndex(where: { $0.id == buyerID }) else {
            throw DatabaseIssue(message: "No club is available to buy this player.")
        }
        creditBalance = credits + price
        clubs[seller].players.removeAll { $0.id == id }
        var transferred = player
        if transferred.valueHistory?.isEmpty != false {
            transferred.recordValue(teamID: selectedClub, teamName: clubs[seller].name, event: "Before transfer", matchweek: round, seasonYear: year)
        }
        transferred.recordValue(teamID: buyerID, teamName: clubs[buyer].name, event: "Transfer", matchweek: round, seasonYear: year)
        clubs[buyer].players.append(transferred)
        marketPlayers?.removeAll { $0.id == id }
        incomingOffers?.removeAll { $0.playerID == id }
        listedPlayerIDs?.removeAll { $0 == id }
        substitutes.removeAll { $0 == id }
        if let slot = lineup.firstIndex(of: id) {
            lineup.remove(at: slot)
            let replacement = clubs[seller].players.filter { !lineup.contains($0.id) }.sorted {
                if ($0.role == player.role) != ($1.role == player.role) { return $0.role == player.role }
                return $0.rating == $1.rating ? $0.id < $1.id : $0.rating > $1.rating
            }.first
            if let replacement { lineup.insert(replacement.id, at: slot) }
        }
    }

    var transferMarket: [MarketPlayer] {
        var seen = Set<Int>()
        let squadPlayers = clubs.flatMap { club in
            club.players.map { MarketPlayer(player: $0, clubID: club.id, clubName: club.name) }
        }
        return (squadPlayers + (marketPlayers ?? [])).filter { seen.insert($0.id).inserted }
    }

    /// Uses the same best-eleven average as the team page, including the replacement player.
    func sellingClubOverallDrop(for id: Int) -> Double {
        guard let listing = transferMarket.first(where: { $0.id == id }), let clubID = listing.clubID else { return 0 }
        var seller = clubs.first { $0.id == clubID }
            ?? Club(id: clubID, name: listing.clubName, city: "", players: transferMarket.filter { $0.clubID == clubID }.map(\.player))
        let before = seller.strength
        seller.players.removeAll { $0.id == id }
        return max(0, before - seller.strength)
    }

    mutating func buyPlayer(_ id: Int, offer: Int, salary: Int? = nil) throws {
        var rng = SystemRandomNumberGenerator()
        try buyPlayer(id, offer: offer, salary: salary, using: &rng)
    }

    mutating func buyPlayer<R: RandomNumberGenerator>(_ id: Int, offer: Int, salary: Int? = nil, using rng: inout R) throws {
        guard let buyer = clubs.firstIndex(where: { $0.id == selectedClub }),
              let listing = transferMarket.first(where: { $0.id == id }) else {
            throw DatabaseIssue(message: "This player is no longer available.")
        }
        let agreedSalary = salary ?? listing.player.currentSalary
        guard agreedSalary >= Footballer.minimumSalary else {
            throw DatabaseIssue(message: "Offer a weekly salary of at least 10 credits.")
        }
        guard listing.player.age(in: year) < 41 else {
            throw DatabaseIssue(message: "Players aged 41 or older are retired and cannot be signed.")
        }
        guard listing.clubID != selectedClub else {
            throw DatabaseIssue(message: "This player already belongs to your team.")
        }
        if listing.player.role == "GK" {
            let keeperCount = transferMarket.filter { $0.clubID == listing.clubID && $0.player.role == "GK" }.count
            guard keeperCount > 2 || listing.clubID == youthMarketClubID else {
                throw DatabaseIssue(message: "The selling club must keep at least two goalkeepers.")
            }
        }
        guard listing.clubID != nil else {
            throw DatabaseIssue(message: "This player has no club. Free-agent signings are not available yet.")
        }
        guard offer >= listing.player.creditsValue else {
            throw DatabaseIssue(message: "Offer at least \(listing.player.creditsValue) credits for this player.")
        }
        guard offer <= credits else {
            throw DatabaseIssue(message: "You do not have enough credits for this offer.")
        }
        if sellingClubOverallDrop(for: id) > 2 {
            let premium = Int.random(in: 5...20, using: &rng)
            let required = (listing.player.creditsValue * (100 + premium) + 99) / 100
            guard offer >= required else {
                throw DatabaseIssue(message: "\(listing.clubName) refused your offer. Losing \(listing.player.name) would reduce its overall by more than 2 points. The club reviews each offer with a 5–20% premium above the player's base value. Increase your offer and try again.")
            }
        }
        let remaining = credits - offer
        for index in clubs.indices { clubs[index].players.removeAll { $0.id == id } }
        marketPlayers?.removeAll { $0.id == id }
        var transferred = listing.player
        if transferred.valueHistory?.isEmpty != false {
            transferred.recordValue(teamID: listing.clubID, teamName: listing.clubName, event: "Before transfer", matchweek: round, seasonYear: year)
        }
        transferred.salary = agreedSalary
        transferred.recordValue(teamID: selectedClub, teamName: clubs[buyer].name, event: "Transfer", matchweek: round, seasonYear: year)
        clubs[buyer].players.append(transferred)
        creditBalance = remaining
        retirementReplacementsNeeded = max(0, replacementsNeeded - 1)
    }
}
