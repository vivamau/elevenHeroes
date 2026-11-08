import Foundation
import Testing
@testable import ElevenHeroes

struct DatabaseManagerTests {
    private var source: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appending(path: "db/db.sqlite")
    }
    private func draft(_ kind: RecordKind, _ values: [String: String], assignment: String = "") -> RecordDraft {
        var draft = RecordDraft(kind: kind)
        draft.values.merge(values) { _, new in new }
        draft.assignment = assignment
        return draft
    }
    @Test @MainActor func createEditPersistAndStartCareer() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = GameStore(saveURL: folder.appending(path: "season.json"))
        let database = try FootballDatabase(url: store.databaseURL, writable: true)
        let country = try database.save(draft(.country, ["country_name":"Test Italy", "country_iso3":"xxy"]))
        let city = try database.save(draft(.city, ["city_name":"L'Aquila", "country_id":"\(country)"]))
        let league = try database.save(draft(.championship, ["championship_name":"Test League", "country_id":"\(country)", "championship_teams_number":"2"]))
        let stadium = try database.save(draft(.stadium, ["stadium_name":"City Ground", "city_id":"\(city)", "stadium_seats":"42000"]))
        #expect(stadium > 0)
        #expect(try database.records(.stadium).first?.values["stadium_seats"] == "42000")
        #expect(draft(.stadium, ["stadium_name":"Ground", "city_id":"\(city)", "stadium_seats":"-1"]).validation != nil)
        for number in 1...2 {
            let team = try database.save(draft(.team, ["team_name":"Club \(number)", "city_id":"\(city)"], assignment: "\(league)"))
            for player in 1...11 {
                try database.save(draft(.player, ["player_name":"Player \(player)", "player_lastname":"O'Brien", "city_id":"\(city)"], assignment: "\(team)"))
            }
        }
        #expect(try database.teamIDs(inChampionship: league).count == 2)
        #expect(try database.teamIDs(inChampionship: -1).isEmpty)
        for kind in RecordKind.allCases { #expect(try !database.records(kind).isEmpty) }
        #expect(try database.records(.country).first(where: { $0.id == country })?.values["country_iso3"] == "XXY")
        let player = try #require(database.records(.player).first)
        var edit = RecordDraft(kind: .player, record: player)
        edit.values["player_name"] = "Updated"
        edit.assignment = try database.assignment(for: player, kind: .player)
        try database.save(edit)
        #expect(try database.records(.player).count == 22)
        let reopened = GameStore(saveURL: store.saveURL)
        #expect(reopened.databaseClubs.count == 2)
        #expect(reopened.databaseClubs.flatMap(\.players).contains { $0.name == "Updated O'Brien" })
        reopened.useDatabase()
        #expect(reopened.available.count == 2)
        reopened.start(reopened.available[0].id)
        #expect(reopened.season?.lineup.count == 11)
        #expect(reopened.season?.demo == false)
        #expect(try Database.load(source).isEmpty)
    }
    @Test func validationAndTransactionsProtectRecords() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let url = folder.appending(path: "football.sqlite")
        defer { try? FileManager.default.removeItem(at: folder) }
        try FootballDatabase.install(from: source, to: url)
        let database = try FootballDatabase(url: url, writable: true)
        let country = try database.save(draft(.country, ["country_name":"Test Kenya", "country_iso3":"XXZ"]))
        #expect(throws: (any Error).self) { try database.save(draft(.country, ["country_name":"Test Kenya", "country_iso3":"XXZ"])) }
        #expect(throws: (any Error).self) { try database.save(draft(.city, ["city_name":"Invalid", "country_id":"9999"])) }
        let city = try database.save(draft(.city, ["city_name":"Nairobi", "country_id":"\(country)"]))
        #expect(throws: (any Error).self) {
            try database.save(draft(.player, ["player_name":"Test", "player_lastname":"Player", "city_id":"\(city)"], assignment: "9999"))
        }
        #expect(try database.records(.player).isEmpty) // Membership failure rolled back the player too.
        #expect(draft(.country, ["country_name":"Country", "country_iso3":"123"]).validation != nil)
        #expect(draft(.player, ["player_name":"Name", "player_lastname":"Surname", "city_id":"1", "player_dob":"20000231"]).validation != nil)
        #expect(try database.records(.country).count == 250)
        #expect(try database.records(.city).count == 1)
    }
    @Test @MainActor func partialDatabaseCanBeImportedWithoutLosingCareer() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = GameStore(saveURL: folder.appending(path: "season.json"))
        store.generateCareerData(); store.start(1)
        let saved = try Data(contentsOf: store.saveURL)
        let imported = folder.appending(path: "partial.sqlite")
        try FootballDatabase.install(from: source, to: imported)
        let database = try FootballDatabase(url: imported, writable: true)
        try database.save(draft(.country, ["country_name":"Test France", "country_iso3":"XXW"]))
        #expect(store.loadDatabase(imported))
        #expect(try FootballDatabase(url: store.databaseURL).records(.country).count == 250)
        #expect(try Data(contentsOf: store.saveURL) == saved)
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).contains { $0.hasPrefix("football-backup-") })
        #expect(!store.loadDatabase(folder.appending(path: "missing.sqlite")))
        #expect(try FootballDatabase(url: store.databaseURL).records(.country).count == 250)
    }
}
