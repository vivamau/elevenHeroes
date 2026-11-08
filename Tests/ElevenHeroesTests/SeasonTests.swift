import XCTest
@testable import ElevenHeroes

final class SeasonTests: XCTestCase {
    struct Seeded: RandomNumberGenerator {
        var state: UInt64 = 42
        mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    }
    func testRoundRobinEvenAndOdd() {
        for count in [3, 4, 7, 8] {
            let clubs = Array(Database.demo.prefix(count))
            let schedule = Season.schedule(clubs)
            XCTAssertEqual(schedule.count, count * (count - 1))
            for a in clubs {
                for b in clubs where a.id != b.id {
                    XCTAssertEqual(schedule.filter { $0.home == a.id && $0.away == b.id }.count, 1)
                }
            }
            for round in Set(schedule.map(\.round)) {
                let ids = schedule.filter { $0.round == round }.flatMap { [$0.home,$0.away] }
                XCTAssertEqual(ids.count, Set(ids).count)
            }
        }
    }
    func testFullSeasonAndSaveRoundTrip() throws {
        let clubs = Database.demo
        var season = Season(clubs: clubs, fixtures: Season.schedule(clubs), selectedClub: 1, lineup: Array(clubs[0].players.prefix(11).map(\.id)), demo: true)
        var rng = Seeded()
        for _ in 0..<14 { season.simulate(using: &rng) }
        XCTAssertTrue(season.finished)
        XCTAssertEqual(season.standings.map(\.played), Array(repeating: 14, count: 8))
        XCTAssertEqual(season.standings.map(\.scored).reduce(0,+), season.standings.map(\.conceded).reduce(0,+))
        XCTAssertEqual(season.standings.map(\.won).reduce(0,+), season.standings.map(\.lost).reduce(0,+))
        let restored = try JSONDecoder().decode(Season.self, from: JSONEncoder().encode(season))
        XCTAssertEqual(restored.standings.map(\.points), season.standings.map(\.points))
        XCTAssertEqual(restored.lineup, season.lineup)
        season.simulate(using: &rng)
        XCTAssertEqual(season.round, 15)
    }
    func testProvidedDatabaseIsReadableAndEmpty() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        XCTAssertTrue(try Database.load(root.appending(path: "db/db.sqlite")).isEmpty)
    }
}
