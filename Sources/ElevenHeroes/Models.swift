import Foundation
import CSQLite

struct Footballer: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let role: String
    let rating: Int
    var careerAge: Int? = nil
    var profile: PlayerProfile? = nil
    var marketValue: Int? = nil
    var valueHistory: [PlayerValueRecord]? = nil
    var salary: Int? = nil
    static let minimumSalary = 10
    var currentSalary: Int { max(Self.minimumSalary, salary ?? valueHistory?.last?.salary ?? Self.minimumSalary) }
    var creditsValue: Int { max(1, marketValue ?? rating) }
}
struct Club: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let city: String
    var players: [Footballer]
    var stadiumName: String? = nil
    var stadiumCapacity: Int? = nil
    var weeklyWages: Int { players.reduce(0) { $0 + max(0, $1.currentSalary) } }
    var strength: Double { Double(players.sorted { $0.rating > $1.rating }.prefix(11).map(\.rating).reduce(0,+)) / Double(max(1, min(11, players.count))) }
}
struct Fixture: Identifiable, Codable {
    var id: Int
    var round: Int
    var home: Int
    var away: Int
    var homeGoals: Int?
    var awayGoals: Int?
    var attendance: Int? = nil
    var ticketRevenue: Int? = nil
    var homeWages: Int? = nil
    var awayWages: Int? = nil
    var stadiumName: String? = nil
    var stadiumCapacity: Int? = nil
    var goalEvents: [GoalEvent]? = nil
    var homeLineup: [Int]? = nil
    var awayLineup: [Int]? = nil
    var homeSubstitutes: [Int]? = nil
    var awaySubstitutes: [Int]? = nil
    var homePasses: [Int: Int]? = nil
    var awayPasses: [Int: Int]? = nil
}
struct Standing: Identifiable {
    let club: Club
    var id: Int { club.id }
    var played = 0, won = 0, drawn = 0, lost = 0, scored = 0, conceded = 0
    var points: Int { won * 3 + drawn }
    var difference: Int { scored - conceded }
    var homePlayed = 0, homeWon = 0, homeDrawn = 0, homeLost = 0, homeScored = 0, homeConceded = 0
    var homePoints: Int { homeWon * 3 + homeDrawn }
    var homeDifference: Int { homeScored - homeConceded }
    var awayPlayed = 0, awayWon = 0, awayDrawn = 0, awayLost = 0, awayScored = 0, awayConceded = 0
    var awayPoints: Int { awayWon * 3 + awayDrawn }
    var awayDifference: Int { awayScored - awayConceded }
}
struct Season: Codable {
    var clubs: [Club]
    var fixtures: [Fixture]
    var selectedClub: Int
    var round = 1
    var tactic = "Balanced"
    var lineup: [Int] = []
    var substitutes: [Int] = []
    var demo: Bool
    var commentary: [String] = []
    var creditBalance: Int? = nil
    var marketPlayers: [MarketPlayer]? = nil
    var incomingOffers: [TransferOffer]? = nil
    var offersGeneratedRound: Int? = nil
    var listedPlayerIDs: [Int]? = nil
    var retiredPlayers: [RetirementRecord]? = nil
    var retirementReplacementsNeeded: Int? = nil
    var replacementTransfers: [ReplacementTransfer]? = nil
    var youthMarketClubID: Int? = nil
    var economyStadiumIncome: Int? = nil
    var ticketPrice: Int? = nil
    var homeTicketPrice: Int { ticketPrice ?? 10 }
    var seasonYear: Int? = nil
    var completedSeasons: [CompletedSeason]? = nil
    var credits: Int { creditBalance ?? 10_000 }
    var finished: Bool { fixtures.allSatisfy { $0.homeGoals != nil } }
    var standings: [Standing] {
        clubs.map { club in
            var row = Standing(club: club)
            for f in fixtures where f.homeGoals != nil && (f.home == club.id || f.away == club.id) {
                let isHome = f.home == club.id
                let own = isHome ? (f.homeGoals ?? 0) : (f.awayGoals ?? 0)
                let other = isHome ? (f.awayGoals ?? 0) : (f.homeGoals ?? 0)
                row.played += 1; row.scored += own; row.conceded += other
                if own > other { row.won += 1 } else if own == other { row.drawn += 1 } else { row.lost += 1 }
                if isHome {
                    row.homePlayed += 1; row.homeScored += own; row.homeConceded += other
                    if own > other { row.homeWon += 1 } else if own == other { row.homeDrawn += 1 } else { row.homeLost += 1 }
                } else {
                    row.awayPlayed += 1; row.awayScored += own; row.awayConceded += other
                    if own > other { row.awayWon += 1 } else if own == other { row.awayDrawn += 1 } else { row.awayLost += 1 }
                }
            }
            return row
        }.sorted { a,b in
            if a.points != b.points { return a.points > b.points }
            if a.difference != b.difference { return a.difference > b.difference }
            if a.scored != b.scored { return a.scored > b.scored }
            return a.club.name < b.club.name
        }
    }
    static func schedule(_ clubs: [Club]) -> [Fixture] {
        guard clubs.count > 1 else { return [] }
        var ids = clubs.map(\.id)
        if ids.count % 2 != 0 { ids.append(-1) }
        var first: [Fixture] = []
        for round in 1..<ids.count {
            for i in 0..<(ids.count / 2) {
                let a = ids[i], b = ids[ids.count - 1 - i]
                if a != -1 && b != -1 { first.append(Fixture(id: first.count, round: round, home: round % 2 == 0 ? b : a, away: round % 2 == 0 ? a : b)) }
            }
            ids.insert(ids.removeLast(), at: 1)
        }
        return first + first.enumerated().map { index, f in Fixture(id: first.count + index, round: f.round + ids.count - 1, home: f.away, away: f.home) }
    }
    mutating func simulate<R: RandomNumberGenerator>(using rng: inout R) {
        guard !finished, goalkeepersNeeded == 0, replacementsNeeded == 0, !clubs.flatMap(\.players).contains(where: { $0.age(in: year) >= 41 }) else { return }
        commentary = []
        for index in fixtures.indices where fixtures[index].round == round && fixtures[index].homeGoals == nil {
            let f = fixtures[index]
            guard let home = clubs.first(where: { $0.id == f.home }), let away = clubs.first(where: { $0.id == f.away }) else { continue }
            func power(_ club: Club) -> Double {
                if club.id == selectedClub {
                    let chosen = club.players.filter { lineup.contains($0.id) }
                    return Double(chosen.map(\.rating).reduce(0,+)) / 11
                }
                return club.strength
            }
            let delta = (power(home) - power(away)) / 45
            let involved = home.id == selectedClub || away.id == selectedClub
            let volatility = involved ? (tactic == "Attacking" ? 0.35 : tactic == "Defensive" ? -0.25 : 0) : 0
            func goals(_ expected: Double, _ rng: inout R) -> Int {
                let limit = exp(-max(0.15, expected)); var product = 1.0, count = 0
                repeat { count += 1; product *= Double.random(in: 0.000001...1, using: &rng) } while product > limit && count < 12
                return count - 1
            }
            let hg = goals(1.5 + delta + volatility, &rng), ag = goals(1.15 - delta + volatility, &rng)
            fixtures[index].homeGoals = hg; fixtures[index].awayGoals = ag
            let capacity = max(0, home.stadiumCapacity ?? 20_000)
            fixtures[index].stadiumCapacity = capacity
            fixtures[index].stadiumName = home.stadiumName ?? "\(home.name) Stadium"
            fixtures[index].attendance = Int((Double(capacity) * Double.random(in: 0.55...1.0, using: &rng)).rounded())
            let revenue = (fixtures[index].attendance ?? 0) * (home.id == selectedClub ? homeTicketPrice : 10)
            fixtures[index].ticketRevenue = revenue
            if home.id == selectedClub { creditBalance = credits + revenue }
            var events: [(Int, String)] = []
            var recorded: [GoalEvent] = []
            for (club, count) in [(home,hg),(away,ag)] {
                let squad = club.id == selectedClub ? club.players.filter { lineup.contains($0.id) } : Array(club.players.sorted { $0.rating > $1.rating }.prefix(11))
                for _ in 0..<count {
                    let minute = Int.random(in: 1...90, using: &rng)
                    let scorer = squad.randomElement(using: &rng)
                    let assistant = Bool.random(using: &rng) ? squad.filter { $0.id != scorer?.id }.randomElement(using: &rng) : nil
                    recorded.append(GoalEvent(clubID: club.id, clubName: club.name, scorerID: scorer?.id, scorerName: scorer?.name,
                                              assistID: assistant?.id, assistName: assistant?.name, minute: minute))
                    events.append((minute, "\(minute)′  GOAL · \(scorer?.name ?? club.name) — \(club.name)"))
                    if let assistant { events.append((minute, "    assist · \(assistant.name)")) }
                }
            }
            fixtures[index].goalEvents = recorded
            let homeStarters = home.id == selectedClub ? lineup : Array(home.players.sorted { $0.rating > $1.rating }.prefix(11).map(\.id))
            let awayStarters = away.id == selectedClub ? lineup : Array(away.players.sorted { $0.rating > $1.rating }.prefix(11).map(\.id))
            func aiSubs(for club: Club, starters: [Int]) -> [Int] {
                var result: [Int] = []
                let remaining = club.players.filter { !starters.contains($0.id) }
                if let goalkeeper = remaining.filter({ $0.role == "GK" }).sorted(by: { $0.rating > $1.rating }).first {
                    result.append(goalkeeper.id)
                }
                result += remaining.filter { $0.role != "GK" && !result.contains($0.id) }
                    .sorted { $0.rating > $1.rating }
                    .prefix(4)
                    .map(\.id)
                if result.count < 5 {
                    result += remaining.filter { !result.contains($0.id) }
                        .sorted { $0.rating > $1.rating }
                        .prefix(5 - result.count)
                        .map(\.id)
                }
                return result
            }
            let homeSubs = home.id == selectedClub ? Array(substitutes.prefix(5)) : aiSubs(for: home, starters: homeStarters)
            let awaySubs = away.id == selectedClub ? Array(substitutes.prefix(5)) : aiSubs(for: away, starters: awayStarters)
            fixtures[index].homeLineup = homeStarters
            fixtures[index].awayLineup = awayStarters
            fixtures[index].homeSubstitutes = homeSubs
            fixtures[index].awaySubstitutes = awaySubs
            var homePassMap: [Int: Int] = [:]
            for id in homeStarters { homePassMap[id] = Int.random(in: 18...72, using: &rng) }
            for id in homeSubs { homePassMap[id] = Int.random(in: 0...14, using: &rng) }
            var awayPassMap: [Int: Int] = [:]
            for id in awayStarters { awayPassMap[id] = Int.random(in: 18...72, using: &rng) }
            for id in awaySubs { awayPassMap[id] = Int.random(in: 0...14, using: &rng) }
            fixtures[index].homePasses = homePassMap
            fixtures[index].awayPasses = awayPassMap
            fixtures[index].homeWages = home.weeklyWages
            fixtures[index].awayWages = away.weeklyWages
            if involved {
                let wages = home.id == selectedClub ? home.weeklyWages : away.weeklyWages
                creditBalance = credits - wages
                commentary = ["Kick-off · \(home.name) v \(away.name)"] + events.sorted { $0.0 < $1.0 }.map(\.1) + ["Full time · \(home.name) \(hg) – \(ag) \(away.name)", "Weekly wages · \(wages.formatted()) credits paid for the full squad"]
            }
        }
        if commentary.isEmpty { commentary = ["Your club had a bye this round. The other fixtures have been played."] }
        round += 1
    }
}

enum Database {
    static func seedURL() throws -> URL {
        #if SWIFT_PACKAGE
        let resource = Bundle.module.url(forResource: "db", withExtension: "sqlite")
        #else
        let resource = Bundle.main.url(forResource: "db", withExtension: "sqlite")
        #endif
        guard let resource else {
            throw DatabaseIssue(message: "The app is missing its bundled db.sqlite. Rebuild or reinstall the application, or use Import database to select db.sqlite.")
        }
        return resource
    }

    static func load(_ url: URL) throws -> [Club] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            if let db { sqlite3_close(db) }; throw NSError(domain: "Database", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot open the football database."])
        }
        defer { sqlite3_close(db) }
        func rows(_ sql: String) throws -> [[String]] {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw NSError(domain: "Database", code: 2, userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(db))]) }
            defer { sqlite3_finalize(statement) }
            var result: [[String]] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                result.append((0..<sqlite3_column_count(statement)).map { i in sqlite3_column_text(statement,i).map { String(cString: $0) } ?? "" })
            }
            return result
        }
        let profiles = try FootballDatabase(url: url).playerProfiles()
        let values = try FootballDatabase(url: url).playerValues()
        let histories = try FootballDatabase(url: url).playerValueHistories()
        let hasStadiumLinks = !(try rows("SELECT name FROM sqlite_master WHERE type='table' AND name='stadium_team'")).isEmpty
        let stadiumRows = hasStadiumLinks ? try rows("SELECT st.team_id,s.stadium_name,s.stadium_seats + COALESCE((SELECT SUM(si.stadium_impr_add_seats) FROM stadium_improvement si WHERE si.stadium_id=s.id),0) FROM stadium_team st JOIN stadium s ON s.id=st.stadium_id ORDER BY st.id") : []
        let teams = try rows("SELECT t.id,t.team_name,COALESCE(c.city_name,'') FROM team t LEFT JOIN city c ON c.id=t.city_id ORDER BY t.id")
        return try teams.map { t in
            let id = Int(t[0]) ?? 0
            let players = try rows("SELECT DISTINCT p.id,p.player_name || ' ' || p.player_lastname,COALESCE((s.player_skills_phys_pace+s.player_skills_phys_stamina+s.player_skills_phys_strength)/3.0,10) FROM player p JOIN team_players tp ON tp.player_id=p.id LEFT JOIN player_skills_physical s ON s.player_id=p.id WHERE tp.team_id=\(id) ORDER BY p.id")
            let stadium = stadiumRows.last { $0[0] == String(id) }
            return Club(id: id, name: t[1], city: t[2], players: players.enumerated().map { i,p in
                Footballer(id: Int(p[0]) ?? i, name: p[1], role: profiles[Int(p[0]) ?? 0]?.values["position_name"].map { position in
                    if position == "GK" { return "GK" }; if position.hasPrefix("D") { return "DEF" }; if position.hasPrefix("M") { return "MID" }; if position.hasPrefix("A") { return "FWD" }; return position
                } ?? role(i), rating: min(99,max(1,Int((Double(p[2]) ?? 10) * 5))), profile: profiles[Int(p[0]) ?? 0], marketValue: values[Int(p[0]) ?? 0], valueHistory: histories[Int(p[0]) ?? 0])
            }, stadiumName: stadium?[1], stadiumCapacity: stadium.flatMap { Int($0[2]) }.map { max(0, $0) })
        }
    }
    static func role(_ index: Int) -> String { index < 2 ? "GK" : index < 8 ? "DEF" : index < 14 ? "MID" : "FWD" }
    static func generateFictionalLeague<R: RandomNumberGenerator>(using rng: inout R) -> [Club] {
        let templates = demo
        var names = templates.flatMap(\.players).map(\.name).shuffled(using: &rng)
        return templates.map { club in
            Club(id: club.id, name: club.name, city: club.city, players: club.players.map { player in
                Footballer(id: player.id, name: names.removeLast(), role: player.role,
                           rating: Int.random(in: 50...89, using: &rng), marketValue: Int.random(in: 1...100, using: &rng))
            })
        }
    }
    static var demo: [Club] {
        let names = ["Northbridge FC", "Portside Athletic", "Kingswood United", "Eastgate City", "Riverside Rovers", "Westhaven FC", "Oakfield Town", "Ironvale Athletic"]
        let first = ["Luca", "Alex", "Noah", "Leo", "Daniel", "Oliver", "Mateo", "James", "Adam", "Oscar", "Ethan", "Gabriel", "Theo", "Rafael", "Samuel", "Felix", "Marco", "Hugo", "Isaac", "Nico"]
        let last = ["Silva", "Morgan", "Rossi", "Clarke", "Costa", "Bennett", "Martin", "Santos", "Reed", "Walsh", "Meyer", "Evans", "Cole", "Rivera", "Brooks", "Moretti", "Hayes", "Dubois", "Stone", "Alves"]
        return names.enumerated().map { c,name in Club(id: c+1, name: name, city: name.components(separatedBy: " ")[0], players: (0..<20).map { p in Footballer(id: c*100+p+1, name: "\(first[p]) \(last[(p+c*3)%20])", role: role(p), rating: 55 + (p*7+c*11)%35) }) }
    }
}
