import Foundation

struct CompletedSeason: Codable {
    let year: Int
    let fixtures: [Fixture]
    let champion: String
    var clubs: [Club]? = nil
    var ticketPrice: Int? = nil
}

extension Footballer {
    func age(in year: Int) -> Int {
        if let careerAge { return careerAge }
        if let raw = profile?.values["player_dob"],
           let birth = RecordDraft.dateFormatter.date(from: raw),
           let reference = Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: 7, day: 1)) {
            return max(0, Calendar(identifier: .gregorian).dateComponents([.year], from: birth, to: reference).year ?? 24)
        }
        // Fictional and legacy players without a birth date start at 24.
        return 24
    }
}

extension Season {
    var year: Int { seasonYear ?? 2026 }
    var yearLabel: String { String(year) }

    mutating func prepareCalendar() {
        seasonYear = year
        for c in clubs.indices {
            for p in clubs[c].players.indices {
                clubs[c].players[p].careerAge = clubs[c].players[p].age(in: year)
            }
        }
        marketPlayers = marketPlayers?.map { entry in
            var player = entry.player
            player.careerAge = player.age(in: year)
            return MarketPlayer(player: player, clubID: entry.clubID, clubName: entry.clubName)
        }
    }

    mutating func startNextSeason(ticketPrice newPrice: Int? = nil, matchParameters newParameters: MatchSimulationParameters? = nil) throws {
        let price = newPrice ?? homeTicketPrice
        guard (1...100).contains(price) else { throw DatabaseIssue(message: "Ticket price must be between 1 and 100 credits.") }
        guard finished, !fixtures.isEmpty, clubs.count > 1 else {
            throw DatabaseIssue(message: "Finish the current season before starting the next one.")
        }
        prepareCalendar()
        if completedSeasons == nil { completedSeasons = [] }
        let completed = CompletedSeason(year: year, fixtures: fixtures, champion: standings.first?.club.name ?? "",
                                        clubs: clubs.map { Club(id: $0.id, name: $0.name, city: $0.city, players: []) }, ticketPrice: ticketPrice)
        completedSeasons?.append(completed)
        ticketPrice = price
        if let newParameters { matchParameters = newParameters }
        seasonYear = year + 1
        for c in clubs.indices {
            for p in clubs[c].players.indices {
                clubs[c].players[p].careerAge = (clubs[c].players[p].careerAge ?? 24) + 1
            }
        }
        marketPlayers = marketPlayers?.map { entry in
            var player = entry.player
            player.careerAge = (player.careerAge ?? 24) + 1
            return MarketPlayer(player: player, clubID: entry.clubID, clubName: entry.clubName)
        }
        retireIneligiblePlayers()
        fixtures = Self.schedule(clubs)
        round = 1
        commentary = []
        incomingOffers = []
        offersGeneratedRound = nil
    }
}
