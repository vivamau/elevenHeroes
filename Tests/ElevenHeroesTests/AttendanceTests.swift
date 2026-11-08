import Foundation
import Testing
@testable import ElevenHeroes

struct AttendanceTests {
    @Test func fullSquadWagesArePaidOncePerMatchAndPersist() throws {
        var clubs = Array(Database.demo.prefix(2))
        for c in clubs.indices {
            clubs[c].stadiumCapacity = 0
            for p in clubs[c].players.indices { clubs[c].players[p].salary = 12 }
        }
        var s = Season(clubs: clubs, fixtures: Season.schedule(clubs), selectedClub: clubs[0].id, demo: true)
        s.lineup = Array(clubs[0].players.prefix(11).map(\.id))
        s.creditBalance = 1
        let wages = clubs[0].players.count * 12
        #expect(wages > s.lineup.count * 12)
        var rng = SeasonTests.Seeded(state: 42)
        s.simulate(using: &rng)
        #expect(s.credits == 1 - wages)
        s = try JSONDecoder().decode(Season.self, from: JSONEncoder().encode(s))
        s.round = 1
        s.simulate(using: &rng)
        #expect(s.credits == 1 - wages)
        // The next match uses the current contracts, including a substitute's raise.
        s.clubs[0].players[s.clubs[0].players.count - 1].salary = 20
        s.simulate(using: &rng)
        #expect(s.credits == 1 - wages * 2 - 8)
        #expect(s.fixtures.allSatisfy { $0.homeWages != nil && $0.awayWages != nil })
        let balance = s.credits
        try s.startNextSeason()
        #expect(s.credits == balance)
        #expect(s.fixtures.allSatisfy { $0.homeWages == nil && $0.awayWages == nil })
        #expect(s.completedSeasons?.first?.fixtures.first?.homeWages == clubs[0].weeklyWages)
    }

    @Test func attendanceUsesHomeCapacityAndSurvivesArchive() throws {
        var clubs = Array(Database.demo.prefix(2))
        clubs[0].stadiumName = "Small Ground"
        clubs[0].stadiumCapacity = 1000
        clubs[1].stadiumName = "Closed Ground"
        clubs[1].stadiumCapacity = 0
        var s = Season(clubs: clubs, fixtures: Season.schedule(clubs), selectedClub: 1, demo: true)
        s.lineup = Array(clubs[0].players.prefix(11).map(\.id))
        s.ticketPrice = 17
        let startingCredits = s.credits
        var rng = SeasonTests.Seeded(state: 42)
        while !s.finished { s.simulate(using: &rng) }
        for f in s.fixtures {
            let attendance = try #require(f.attendance)
            #expect(f.stadiumCapacity == (f.home == 1 ? 1000 : 0))
            #expect(f.home == 1 ? (550...1000).contains(attendance) : attendance == 0)
        }
        let earned = s.fixtures.filter { $0.home == s.selectedClub }.reduce(0) { $0 + ($1.attendance ?? 0) * 17 }
        #expect(s.credits == startingCredits + earned - clubs[0].weeklyWages * 2)
        #expect(s.fixtures.allSatisfy { $0.ticketRevenue == ($0.attendance ?? 0) * ($0.home == s.selectedClub ? 17 : 10) })
        let budget = s.credits
        s.simulate(using: &rng)
        #expect(s.credits == budget)
        // Revisited rounds must not credit already played fixtures again.
        s.round = 1
        s.simulate(using: &rng)
        #expect(s.credits == budget)
        s.round = 3
        let revenues = s.fixtures.map(\.ticketRevenue)
        let original = s.fixtures.map(\.attendance)
        try s.startNextSeason()
        #expect(s.fixtures.allSatisfy { $0.attendance == nil })
        let loaded = try JSONDecoder().decode(Season.self, from: JSONEncoder().encode(s))
        #expect(loaded.credits == budget)
        #expect(loaded.completedSeasons?.first?.fixtures.map(\.ticketRevenue) == revenues)
        #expect(loaded.completedSeasons?.first?.fixtures.map(\.attendance) == original)
    }
}
