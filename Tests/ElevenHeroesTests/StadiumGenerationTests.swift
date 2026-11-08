import Foundation
import Testing
import CSQLite
@testable import ElevenHeroes

struct StadiumGenerationTests {
    @Test func generatesClubStadiumsAndResetsImprovementHistory() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "db.sqlite")
        try FootballDatabase.copy(from: Database.seedURL(), to: url)
        let db = try FootballDatabase(url: url, writable: true)
        let report = try db.generate(.team, count: 3, includeSquads: false, replaceAll: true)
        let teams = try db.records(.team)
        let stadiums = try db.records(.stadium)
        #expect(report.counts[.stadium] == 3)
        #expect(stadiums.count == teams.count)
        for team in teams {
            let stadium = try #require(stadiums.first { $0.values["city_id"] == team.values["city_id"] })
            #expect((5000...30000).contains(Int(stadium.values["stadium_seats"] ?? "") ?? 0))
            #expect(stadium.title == team.title + " Stadium")
        }
        var handle: OpaquePointer?
        #expect(sqlite3_open(url.path, &handle) == SQLITE_OK)
        defer { sqlite3_close(handle) }
        var links: OpaquePointer?
        #expect(sqlite3_prepare_v2(handle, "SELECT COUNT(*) FROM stadium_team st JOIN team t ON t.id=st.team_id JOIN stadium s ON s.id=st.stadium_id WHERE t.city_id=s.city_id", -1, &links, nil) == SQLITE_OK)
        #expect(sqlite3_step(links) == SQLITE_ROW)
        #expect(sqlite3_column_int(links, 0) == 3)
        sqlite3_finalize(links)
        let first = try #require(stadiums.first)
        #expect(sqlite3_exec(handle, "INSERT INTO stadium_improvement (stadium_id,stadium_impr_add_seats,stadium_impr_date,stadium_impr_costs) VALUES (\(first.id),1000,20270101,100000)", nil, nil, nil) == SQLITE_OK)
        _ = try db.generate(.team, count: 1, includeSquads: false, replaceAll: true)
        var statement: OpaquePointer?
        #expect(sqlite3_prepare_v2(handle, "SELECT COUNT(*) FROM stadium_improvement", -1, &statement, nil) == SQLITE_OK)
        #expect(sqlite3_step(statement) == SQLITE_ROW)
        #expect(sqlite3_column_int(statement, 0) == 0)
        sqlite3_finalize(statement)
        let regeneratedTeam = try #require(db.records(.team).first)
        try db.delete(.team, id: regeneratedTeam.id)
        #expect(sqlite3_prepare_v2(handle, "SELECT COUNT(*) FROM stadium_team", -1, &links, nil) == SQLITE_OK)
        #expect(sqlite3_step(links) == SQLITE_ROW)
        #expect(sqlite3_column_int(links, 0) == 0)
        sqlite3_finalize(links)
        try db.clearWorld()
        #expect(try db.records(.stadium).isEmpty)
    }
}
