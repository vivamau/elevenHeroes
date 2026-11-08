import Foundation

extension Footballer {
    mutating func initializeEconomy<R: RandomNumberGenerator>(stadiumIncome: Int, using rng: inout R) {
        // A 70-overall player represents one of 22 equal shares of a full gate.
        marketValue = max(100, Int((Double(stadiumIncome) / 22 * Double(max(1, rating)) / 70).rounded()))
        let lower = max(Self.minimumSalary, (creditsValue + 9) / 10)
        let upper = max(lower, creditsValue / 5)
        salary = Int.random(in: lower...upper, using: &rng)
    }
}

extension Season {
    mutating func initializeEconomy<R: RandomNumberGenerator>(using rng: inout R) {
        let capacity = clubs.first { $0.id == selectedClub }?.stadiumCapacity ?? 20_000
        economyStadiumIncome = max(0, capacity) * homeTicketPrice
        var players: [Int: Footballer] = [:]
        for entry in transferMarket {
            var player = entry.player
            player.initializeEconomy(stadiumIncome: economyStadiumIncome ?? 0, using: &rng)
            // A new career starts its own price history, independent of seed valuations.
            player.valueHistory = []
            player.recordValue(teamID: entry.clubID, teamName: entry.clubName, event: "Career started", matchweek: 1, seasonYear: year)
            players[player.id] = player
        }
        for c in clubs.indices {
            clubs[c].players = clubs[c].players.map { players[$0.id] ?? $0 }
        }
        marketPlayers = marketPlayers?.map { MarketPlayer(player: players[$0.id] ?? $0.player, clubID: $0.clubID, clubName: $0.clubName) }
    }
}
