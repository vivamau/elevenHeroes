import Foundation

struct RetirementRecord: Codable, Identifiable {
    var id: Int { player.id }
    let player: Footballer
    let clubID: Int?
    let clubName: String
    let year: Int
}

struct ReplacementTransfer: Codable {
    let playerID: Int
    let playerName: String
    let buyerID: Int
    let sellerName: String
    let credits: Int
    let year: Int
}

extension Season {
    var replacementsNeeded: Int { retirementReplacementsNeeded ?? 0 }

    /// Keeps historical identities while removing retired players from every active roster.
    mutating func retireIneligiblePlayers() {
        defer { ensureGoalkeeperCover() }
        let retirementYear = year
        let retiring = transferMarket.filter { $0.player.age(in: year) >= 41 }
        guard !retiring.isEmpty else { return }
        let ids = Set(retiring.map(\.id))
        let leagueIDs = Set(clubs.map(\.id))
        if retiredPlayers == nil { retiredPlayers = [] }
        for entry in retiring where !(retiredPlayers ?? []).contains(where: { $0.id == entry.id }) {
            retiredPlayers?.append(RetirementRecord(player: entry.player, clubID: entry.clubID, clubName: entry.clubName, year: retirementYear))
        }
        for index in clubs.indices { clubs[index].players.removeAll { ids.contains($0.id) } }
        marketPlayers?.removeAll { ids.contains($0.id) }
        substitutes.removeAll { ids.contains($0) }
        lineup.removeAll { ids.contains($0) }
        listedPlayerIDs?.removeAll { ids.contains($0) }
        incomingOffers?.removeAll { ids.contains($0.playerID) }
        retirementReplacementsNeeded = replacementsNeeded + retiring.filter { $0.clubID == selectedClub }.count

        // Buy from outside the playable league so replacement transfers cannot strip another league squad.
        for entry in retiring {
            guard let clubID = entry.clubID, clubID != selectedClub, leagueIDs.contains(clubID),
                  let buyer = clubs.firstIndex(where: { $0.id == clubID }) else { continue }
            let market = transferMarket
            let sellerCounts = Dictionary(grouping: market, by: \.clubID).mapValues(\.count)
            let available = market.filter {
                guard let seller = $0.clubID else { return false }
                return !leagueIDs.contains(seller) && $0.player.role == entry.player.role && $0.player.age(in: year) < 41
                    && (sellerCounts[seller] ?? 0) > 16
                    && ($0.player.role != "GK" || market.filter { $0.clubID == seller && $0.player.role == "GK" }.count > 2)
            }.sorted { $0.player.creditsValue == $1.player.creditsValue ? $0.id < $1.id : $0.player.creditsValue < $1.player.creditsValue }
            let purchase = available.first ?? addYoungMarketPlayer(role: entry.player.role)
            let price = (purchase.player.creditsValue * 120 + 99) / 100
            marketPlayers?.removeAll { $0.id == purchase.id }
            var player = purchase.player
            if let income = economyStadiumIncome {
            var rng = SystemRandomNumberGenerator()
            player.initializeEconomy(stadiumIncome: income, using: &rng)
        }
        player.recordValue(teamID: clubID, teamName: clubs[buyer].name, event: "Retirement replacement · \(price) credits", matchweek: 1, seasonYear: year)
            clubs[buyer].players.append(player)
            if replacementTransfers == nil { replacementTransfers = [] }
            replacementTransfers?.append(ReplacementTransfer(playerID: player.id, playerName: player.name, buyerID: clubID,
                                                             sellerName: purchase.clubName, credits: price, year: retirementYear))
        }
        // Ensure the manager can buy replacements even in fictional leagues with simultaneous retirements.
        for entry in retiring where entry.clubID == selectedClub { _ = addYoungMarketPlayer(role: entry.player.role) }
    }

    mutating func ensureGoalkeeperCover() {
        for index in clubs.indices where clubs[index].id != selectedClub {
            let missing = max(0, 2 - clubs[index].players.filter { $0.role == "GK" }.count)
            for _ in 0..<missing {
                let purchase = addYoungMarketPlayer(role: "GK")
                marketPlayers?.removeAll { $0.id == purchase.id }
                var player = purchase.player
                let buyerID = clubs[index].id
                let fee = purchase.player.creditsValue
                player.recordValue(teamID: buyerID, teamName: clubs[index].name, event: "Goalkeeper cover · \(fee) credits", matchweek: round, seasonYear: year)
                clubs[index].players.append(player)
                let transfer = ReplacementTransfer(playerID: player.id, playerName: player.name, buyerID: buyerID, sellerName: purchase.clubName, credits: fee, year: year)
                if replacementTransfers == nil { replacementTransfers = [] }
                replacementTransfers?.append(transfer)
            }
        }
        let available = (marketPlayers ?? []).filter { $0.clubID == youthMarketClubID && $0.player.role == "GK" && $0.player.age(in: year) < 41 }.count
        for _ in 0..<max(0, goalkeepersNeeded - available) { _ = addYoungMarketPlayer(role: "GK") }
    }

    @discardableResult
    private mutating func addYoungMarketPlayer(role: String) -> MarketPlayer {
        let usedIDs = transferMarket.map(\.id) + (retiredPlayers ?? []).map(\.id)
        let id = min(0, usedIDs.min() ?? 0) - 1
        let clubID = youthMarketClubID ?? (min(0, (clubs.map(\.id) + (marketPlayers ?? []).compactMap(\.clubID)).min() ?? 0) - 1)
        youthMarketClubID = clubID
        let first = ["Alex", "Luca", "Noah", "Leo", "Mateo", "Theo"].randomElement()!
        let last = ["Silva", "Morgan", "Rossi", "Clarke", "Costa", "Martin"].randomElement()!
        var player = Footballer(id: id, name: "\(first) \(last)", role: role, rating: Int.random(in: 50...75), careerAge: Int.random(in: 18...23), marketValue: Int.random(in: 1...100))
        player.recordValue(teamID: clubID, teamName: "Development FC", event: "Entered transfer market", matchweek: 1, seasonYear: year)
        let listing = MarketPlayer(player: player, clubID: clubID, clubName: "Development FC")
        if marketPlayers == nil { marketPlayers = [] }
        marketPlayers?.append(listing)
        return listing
    }
}
