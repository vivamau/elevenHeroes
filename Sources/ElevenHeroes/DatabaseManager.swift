import Foundation
import CSQLite

struct DatabaseIssue: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum RecordKind: String, CaseIterable, Identifiable {
    case country, city, championship, team, stadium, player
    var id: String { rawValue }
    var title: String {
        switch self {
        case .country: "Countries"
        case .city: "Cities"
        case .championship: "Leagues"
        case .team: "Teams"
        case .stadium: "Stadiums"
        case .player: "Players"
        }
    }
    var singular: String { self == .championship ? "League" : rawValue.capitalized }
    var icon: String {
        switch self {
        case .country: "globe"
        case .city: "building.2"
        case .championship: "trophy"
        case .team: "shield"
        case .stadium: "sportscourt"
        case .player: "person"
        }
    }
    var nameColumn: String { self == .player ? "player_lastname" : "\(rawValue)_name" }
    var fields: [RecordField] {
        switch self {
        case .country: [RecordField("country_name", "Name"), RecordField("country_iso3", "ISO code", type: .iso)]
        case .city: [RecordField("city_name", "Name"), RecordField("country_id", "Country", type: .relation(.country))]
        case .championship: [RecordField("championship_name", "Name"), RecordField("country_id", "Country", type: .relation(.country)), RecordField("championship_teams_number", "Number of teams", type: .number(2...128), initial: "8")]
        case .team: [RecordField("team_name", "Name"), RecordField("city_id", "City", type: .relation(.city)), RecordField("team_foundation_date", "Founded (year)", type: .number(1800...2100), initial: "1900")]
        case .stadium: [RecordField("stadium_name", "Name"), RecordField("city_id", "City", type: .relation(.city)), RecordField("stadium_foundation", "Opened (year)", type: .number(1800...2100), initial: "2000"), RecordField("stadium_seats", "Number of seats", type: .number(0...1_000_000), initial: "0")]
        case .player: [RecordField("player_name", "First name"), RecordField("player_lastname", "Last name"), RecordField("player_dob", "Date of birth", type: .date, initial: "20000101"), RecordField("city_id", "Birth city", type: .relation(.city))]
        }
    }
    var assignment: RecordKind? {
        switch self { case .player: .team; case .team: .championship; default: nil }
    }
}
struct RecordField: Identifiable {
    enum FieldType { case text, iso, number(ClosedRange<Int>), date, relation(RecordKind) }
    let id: String
    let label: String
    var type: FieldType = .text
    var initial = ""
    init(_ id: String, _ label: String, type: FieldType = .text, initial: String = "") {
        self.id = id; self.label = label; self.type = type; self.initial = initial
    }
}
struct DatabaseRecord: Identifiable {
    let id: Int
    let title: String
    let values: [String: String]
}
struct RecordDraft {
    let kind: RecordKind
    var id: Int?
    var values: [String: String]
    var assignment = ""
    init(kind: RecordKind, record: DatabaseRecord? = nil) {
        self.kind = kind
        id = record?.id
        values = kind == .player ? PlayerAttributes.defaults : [:]
        values.merge(record?.values ?? Dictionary(uniqueKeysWithValues: kind.fields.map { ($0.id, $0.initial) })) { _, supplied in supplied }
    }
    var validation: String? {
        for field in kind.fields {
            let value = (values[field.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if kind == .player && field.id == "player_lastname" && value.isEmpty { continue }
            if value.isEmpty { return "Enter \(field.label.lowercased())." }
            switch field.type {
            case .text:
                if value.count > 120 { return "\(field.label) must be 120 characters or fewer." }
            case .iso:
                if value.count != 3 || !value.uppercased().utf8.allSatisfy({ (65...90).contains($0) }) { return "Enter a three-letter country code, such as ITA." }
            case .number(let range):
                guard let number = Int(value), range.contains(number) else { return "\(field.label) must be between \(range.lowerBound) and \(range.upperBound)." }
            case .date:
                guard Self.dateFormatter.date(from: value) != nil, value.count == 8 else { return "Choose a valid date of birth." }
                if let date = Self.dateFormatter.date(from: value), date > Date() { return "Date of birth cannot be in the future." }
            case .relation:
                guard let id = Int(value), id > 0 else { return "Choose \(field.label.lowercased())." }
            }
        }
        return kind == .player ? PlayerAttributes.validation(values) : nil
    }
    static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd"
        formatter.isLenient = false
        return formatter
    }
}

/// Short-lived SQLite connections keep backup, reading and atomic writes independent of view lifetime.
final class FootballDatabase {
    private var handle: OpaquePointer?
    init(url: URL, writable: Bool = false) throws {
        let flags = writable ? SQLITE_OPEN_READWRITE : SQLITE_OPEN_READONLY
        guard sqlite3_open_v2(url.path, &handle, flags, nil) == SQLITE_OK else {
            let detail = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "SQLite could not create a connection."
            if let handle { sqlite3_close(handle) }; handle = nil
            throw DatabaseIssue(message: "Cannot open \(url.path). \(detail)")
        }
        sqlite3_busy_timeout(handle, 3000)
        try execute("PRAGMA foreign_keys = ON")
        if writable {
            let countryColumns = try rows("PRAGMA table_info(country)")
            if countryColumns.contains(where: { $0["name"] == "country_iso2" }), !countryColumns.contains(where: { $0["name"] == "country_iso3" }) {
                try execute("ALTER TABLE country RENAME COLUMN country_iso2 TO country_iso3")
            }
            try migratePositions()
            try migratePlayerValues()
            try execute("CREATE TABLE IF NOT EXISTS stadium_team (id INTEGER PRIMARY KEY AUTOINCREMENT UNIQUE NOT NULL, team_id INTEGER REFERENCES team(id), stadium_id INTEGER REFERENCES stadium(id))")
            try execute("CREATE TABLE IF NOT EXISTS stadium_improvement (id INTEGER PRIMARY KEY UNIQUE NOT NULL, stadium_id INTEGER REFERENCES stadium(id), stadium_impr_add_seats INTEGER, stadium_impr_date INTEGER)")
            let columns = try rows("PRAGMA table_info(stadium)")
            if !columns.isEmpty, !columns.contains(where: { $0["name"] == "stadium_seats" }) {
                try execute("ALTER TABLE stadium ADD COLUMN stadium_seats INTEGER NOT NULL DEFAULT 0 CHECK(stadium_seats >= 0)")
            }
        }
    }
    private func migratePlayerValues() throws {
        try execute("SAVEPOINT player_values")
        do {
            try execute("CREATE TABLE IF NOT EXISTS player_value (id INTEGER PRIMARY KEY AUTOINCREMENT UNIQUE NOT NULL, player_id INTEGER REFERENCES player(id), player_value_date INTEGER NOT NULL, player_value_cost INTEGER CHECK(player_value_cost BETWEEN 1 AND 100))")
            if !(try rows("PRAGMA table_info(player_value)")).contains(where: { $0["name"] == "player_value_cost" }) {
                try execute("ALTER TABLE player_value ADD COLUMN player_value_cost INTEGER CHECK(player_value_cost BETWEEN 1 AND 100)")
            }
            if !(try rows("PRAGMA table_info(player_value)")).contains(where: { $0["name"] == "player_value_team_id" }) {
                try execute("ALTER TABLE player_value ADD COLUMN player_value_team_id INTEGER REFERENCES team(id)")
            }
            if !(try rows("PRAGMA table_info(player)")).contains(where: { $0["name"] == "player_initial_salary" }) {
                try execute("ALTER TABLE player ADD COLUMN player_initial_salary INTEGER")
            }
            if !(try rows("PRAGMA table_info(player_value)")).contains(where: { $0["name"] == "player_value_salary" }) {
                try execute("ALTER TABLE player_value ADD COLUMN player_value_salary INTEGER")
            }
            try execute("UPDATE player SET player_initial_salary=10+abs(random()%91) WHERE player_initial_salary IS NULL")
            try execute("UPDATE player_value SET player_value_salary=(SELECT player_initial_salary FROM player WHERE id=player_value.player_id) WHERE player_value_salary IS NULL")
            try execute("UPDATE player_value SET player_value_cost=1+abs(random()%100) WHERE player_value_cost IS NULL")
            try execute("INSERT INTO player_value (player_id,player_value_date,player_value_cost,player_value_team_id,player_value_salary) SELECT p.id,?,1+abs(random()%100),(SELECT team_id FROM team_players WHERE player_id=p.id ORDER BY id DESC LIMIT 1),p.player_initial_salary FROM player p WHERE NOT EXISTS (SELECT 1 FROM player_value v WHERE v.player_id=p.id)", [RecordDraft.dateFormatter.string(from: Date())])
            try execute("RELEASE player_values")
        } catch {
            try? execute("ROLLBACK TO player_values"); try? execute("RELEASE player_values"); throw error
        }
    }
    private func ensurePlayerValue(_ id: Int, recordTeamChange: Bool = false) throws {
        try execute("INSERT INTO player_value (player_id,player_value_date,player_value_cost,player_value_team_id,player_value_salary) SELECT ?,?,COALESCE((SELECT player_value_cost FROM player_value WHERE player_id=? ORDER BY player_value_date DESC,id DESC LIMIT 1),?),(SELECT team_id FROM team_players WHERE player_id=? ORDER BY id DESC LIMIT 1),COALESCE((SELECT player_value_salary FROM player_value WHERE player_id=? AND player_value_salary IS NOT NULL ORDER BY player_value_date DESC,id DESC LIMIT 1),(SELECT player_initial_salary FROM player WHERE id=?)) WHERE ?='1' OR NOT EXISTS (SELECT 1 FROM player_value WHERE player_id=?)", [String(id), RecordDraft.dateFormatter.string(from: Date()), String(id), String(Int.random(in: 1...100)), String(id), String(id), String(id), recordTeamChange ? "1" : "0", String(id)])
    }
    func playerValueHistories() throws -> [Int: [PlayerValueRecord]] {
        let columns = try rows("PRAGMA table_info(player_value)")
        guard columns.contains(where: { $0["name"] == "player_value_cost" }) else { return [:] }
        let salaryColumn = columns.contains { $0["name"] == "player_value_salary" } ? "v.player_value_salary" : "NULL AS player_value_salary"
        let hasTeam = columns.contains { $0["name"] == "player_value_team_id" }
        let teamColumns = hasTeam ? "v.player_value_team_id,t.team_name" : "NULL AS player_value_team_id,NULL AS team_name"
        let join = hasTeam ? "LEFT JOIN team t ON t.id=v.player_value_team_id" : ""
        var histories: [Int: [PlayerValueRecord]] = [:]
        for row in try rows("SELECT v.id,v.player_id,v.player_value_date,v.player_value_cost,\(salaryColumn),\(teamColumns) FROM player_value v \(join) ORDER BY v.player_value_date,v.id") {
            guard let playerID = Int(row["player_id"] ?? ""), let credits = Int(row["player_value_cost"] ?? "") else { continue }
            histories[playerID, default: []].append(PlayerValueRecord(id: "database-\(row["id"] ?? "")",
                date: row["player_value_date"] ?? "", credits: credits,
                teamID: Int(row["player_value_team_id"] ?? ""),
                teamName: row["team_name"].flatMap { $0.isEmpty ? nil : $0 }, event: "Database valuation", salary: Int(row["player_value_salary"] ?? "")))
        }
        return histories
    }
    func playerValues() throws -> [Int: Int] {
        guard (try rows("PRAGMA table_info(player_value)")).contains(where: { $0["name"] == "player_value_cost" }) else { return [:] }
        var values: [Int: Int] = [:]
        for row in try rows("SELECT player_id,player_value_cost FROM player_value ORDER BY player_value_date DESC,id DESC") {
            if let id = Int(row["player_id"] ?? ""), let value = Int(row["player_value_cost"] ?? ""), values[id] == nil { values[id] = value }
        }
        return values
    }
    func marketSnapshot() throws -> [MarketPlayer] {
        let profiles = try playerProfiles()
        let values = try playerValues()
        let histories = try playerValueHistories()
        return try rows("SELECT p.id,p.player_name || ' ' || p.player_lastname AS name,t.id AS club_id,t.team_name FROM player p LEFT JOIN team_players tp ON tp.id=(SELECT MAX(id) FROM team_players WHERE player_id=p.id) LEFT JOIN team t ON t.id=tp.team_id").map { row in
            let id = Int(row["id"] ?? "") ?? 0
            let profile = profiles[id]
            let position = profile?.values["position_name"] ?? "MID"
            let role = position.hasPrefix("D") ? "DEF" : position.hasPrefix("M") ? "MID" : position.hasPrefix("A") ? "FWD" : position
            let skills = ["player_skills_phys_pace", "player_skills_phys_stamina", "player_skills_phys_strength"]
            let rating = Int(skills.reduce(0.0) { $0 + (Double(profile?.values[$1] ?? "") ?? 10) } / 3 * 5)
            let player = Footballer(id: id, name: row["name"] ?? "", role: role, rating: min(99, max(1, rating)), profile: profile, marketValue: values[id], valueHistory: histories[id])
            return MarketPlayer(player: player, clubID: Int(row["club_id"] ?? ""), clubName: row["team_name"].flatMap { $0.isEmpty ? nil : $0 } ?? "No club")
        }
    }
    func clearWorld() throws {
        try execute("SAVEPOINT clear_world")
        do {
            for table in ["stadium_team", "stadium_improvement", "player_value", "player_position", "player_stats", "player_skills_physical", "player_skills_mental", "team_players", "championship_teams", "player", "team", "stadium", "manager", "championship", "city", "country"] {
                try execute("DELETE FROM \(table)")
            }
            // Remember the explicit clear so startup does not silently restore countries.
            try execute("CREATE TABLE IF NOT EXISTS app_metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
            try execute("INSERT OR REPLACE INTO app_metadata (key,value) VALUES ('countries_cleared','1')")
            try execute("RELEASE clear_world")
        } catch {
            try? execute("ROLLBACK TO clear_world"); try? execute("RELEASE clear_world"); throw error
        }
    }
    func synchronizeCountries() throws {
        if !(try rows("SELECT name FROM sqlite_master WHERE name='app_metadata'")).isEmpty,
           !(try rows("SELECT value FROM app_metadata WHERE key='countries_cleared' AND value='1'")).isEmpty { return }
        let catalog = try CountryCatalog.load()
        try execute("SAVEPOINT country_catalog")
        do {
            for country in catalog {
                let matches = try rows("SELECT id,country_name FROM country WHERE UPPER(country_iso3) IN (?,?) OR country_name=? ORDER BY id", [country.iso2, country.iso3, country.name])
                if let first = matches.first, let id = first["id"] {
                    for duplicate in matches.dropFirst() {
                        guard let duplicateID = duplicate["id"] else { continue }
                        for table in ["city", "championship"] {
                            try execute("UPDATE \(table) SET country_id=? WHERE country_id=?", [id, duplicateID])
                        }
                        try execute("DELETE FROM country WHERE id=?", [duplicateID])
                    }
                    try execute("UPDATE country SET country_name=?,country_iso3=? WHERE id=?", [country.name, country.iso3, id])
                } else {
                    try execute("INSERT INTO country (country_name,country_iso3) VALUES (?,?)", [country.name, country.iso3])
                }
            }
            try execute("RELEASE country_catalog")
        } catch {
            try? execute("ROLLBACK TO country_catalog"); try? execute("RELEASE country_catalog"); throw error
        }
    }
    private func migratePositions() throws {
        let existing = try rows("SELECT name FROM sqlite_master WHERE type='table' AND name IN ('position','player_position')")
        guard existing.count < 2 else { return }
        let seed = try FootballDatabase(url: Database.seedURL())
        try execute("SAVEPOINT position_schema")
        do {
            for table in ["position", "player_position"] where !existing.contains(where: { $0["name"] == table }) {
                guard let sql = try seed.rows("SELECT sql FROM sqlite_master WHERE name=?", [table]).first?["sql"] else {
                    throw DatabaseIssue(message: "The bundled database is missing \(table).")
                }
                try execute(sql)
                if table == "position" {
                    let seedFeet = try seed.rows("SELECT * FROM player_foot")
                    for position in try seed.rows("SELECT * FROM position ORDER BY id") {
                        var foot = ""
                        if let name = seedFeet.first(where: { $0["id"] == position["player_foot_id"] })?["player_foot_name"] {
                            if let match = try rows("SELECT id FROM player_foot WHERE player_foot_name=?", [name]).first?["id"] { foot = match }
                            else {
                                let next = try rows("SELECT COALESCE(MAX(CAST(id AS INTEGER)),0)+1 AS id FROM player_foot").first?["id"] ?? "1"
                                try execute("INSERT INTO player_foot (id,player_foot_name) VALUES (CAST(? AS INTEGER),?)", [next, name]); foot = next
                            }
                        }
                        try execute("INSERT INTO position (id,position_name,position_description,player_foot_id) VALUES (?,?,?,NULLIF(?,''))", [position["id"] ?? "", position["position_name"] ?? "", position["position_description"] ?? "", foot])
                    }
                }
            }
            try execute("RELEASE position_schema")
        } catch {
            try? execute("ROLLBACK TO position_schema"); try? execute("RELEASE position_schema"); throw error
        }
    }
    deinit { sqlite3_close(handle) }
    private func issue() -> DatabaseIssue {
        DatabaseIssue(message: String(cString: sqlite3_errmsg(handle)))
    }
    private func statement(_ sql: String, _ values: [String]) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { throw issue() }
        for (index, value) in values.enumerated() {
            let result = value.withCString { sqlite3_bind_text(stmt, Int32(index + 1), $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
            guard result == SQLITE_OK else { sqlite3_finalize(stmt); throw issue() }
        }
        return stmt
    }
    private func execute(_ sql: String, _ values: [String] = []) throws {
        let stmt = try statement(sql, values); defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw issue() }
    }
    private func rows(_ sql: String, _ values: [String] = []) throws -> [[String: String]] {
        let stmt = try statement(sql, values); defer { sqlite3_finalize(stmt) }
        var result: [[String: String]] = []
        while true {
            let code = sqlite3_step(stmt)
            if code == SQLITE_DONE { return result }
            guard code == SQLITE_ROW else { throw issue() }
            var row: [String: String] = [:]
            for index in 0..<sqlite3_column_count(stmt) {
                row[String(cString: sqlite3_column_name(stmt, index))] = sqlite3_column_text(stmt, index).map { String(cString: $0) } ?? ""
            }
            result.append(row)
        }
    }
    func primaryPositions() throws -> [Int: String] {
        guard !(try rows("SELECT name FROM sqlite_master WHERE name='player_position'")).isEmpty else { return [:] }
        var result: [Int: String] = [:]
        for row in try rows("SELECT pp.player_id,p.position_name FROM player_position pp JOIN position p ON p.id=pp.position_id ORDER BY pp.player_position_strong DESC,pp.id DESC") {
            if let id = Int(row["player_id"] ?? ""), result[id] == nil { result[id] = row["position_name"] }
        }
        return result
    }
    func records(_ kind: RecordKind) throws -> [DatabaseRecord] {
        try rows("SELECT * FROM \(kind.rawValue) ORDER BY \(kind.nameColumn) COLLATE NOCASE, id").map { row in
            var row = row
            if kind == .player {
                for (table, columns) in [("player_skills_physical", PlayerAttributes.physical.map(\.id) + ["player_foot_id", "player_morale_id"]), ("player_skills_mental", PlayerAttributes.mental.map(\.id))] {
                    if let skills = try rows("SELECT \(columns.joined(separator: ",")) FROM \(table) WHERE player_id=? ORDER BY id DESC LIMIT 1", [row["id"] ?? ""]).first {
                        row.merge(skills) { _, saved in saved }
                    }
                }
            }
            return DatabaseRecord(id: Int(row["id"] ?? "") ?? 0,
                           title: kind == .player ? "\(row["player_name"] ?? "") \(row["player_lastname"] ?? "")" : row[kind.nameColumn] ?? "",
                           values: row)
        }
    }
    func delete(_ kind: RecordKind, id: Int) throws {
        try execute("SAVEPOINT record_delete")
        do {
            let references: [(String, String)]
            switch kind {
            case .country: references = [("city", "country_id"), ("championship", "country_id")]
            case .city: references = [("team", "city_id"), ("player", "city_id"), ("stadium", "city_id"), ("manager", "city_id")]
            default: references = []
            }
            for (table, column) in references {
                if !(try rows("SELECT id FROM \(table) WHERE \(column)=? LIMIT 1", [String(id)])).isEmpty {
                    throw DatabaseIssue(message: "This \(kind.rawValue) is still used by \(RecordKind(rawValue: table)?.title.lowercased() ?? table) records. Reassign or delete those records first.")
                }
            }
            let dependents: [(String, String)]
            switch kind {
            case .player: dependents = [("player_value", "player_id"), ("player_position", "player_id"), ("team_players", "player_id"), ("player_skills_physical", "player_id"), ("player_skills_mental", "player_id"), ("player_stats", "player_id")]
            case .stadium: dependents = [("stadium_team", "stadium_id"), ("stadium_improvement", "stadium_id")]
            case .team: dependents = [("stadium_team", "team_id"), ("team_players", "team_id"), ("championship_teams", "team_id")]
            case .championship: dependents = [("championship_teams", "championship_id")]
            default: dependents = []
            }
            for (table, column) in dependents {
                try execute("DELETE FROM \(table) WHERE \(column)=?", [String(id)])
            }
            if kind == .team {
                try execute("UPDATE player_value SET player_value_team_id=NULL WHERE player_value_team_id=?", [String(id)])
            }
            try execute("DELETE FROM \(kind.rawValue) WHERE id=?", [String(id)])
            try execute("RELEASE record_delete")
        } catch {
            try? execute("ROLLBACK TO record_delete")
            try? execute("RELEASE record_delete")
            throw error
        }
    }
    func teamIDs(inChampionship id: Int) throws -> Set<Int> {
        Set(try rows("SELECT DISTINCT team_id FROM championship_teams WHERE championship_id=?", [String(id)]).compactMap { Int($0["team_id"] ?? "") })
    }
    func assignment(for record: DatabaseRecord, kind: RecordKind) throws -> String {
        switch kind {
        case .player: return try rows("SELECT team_id AS target FROM team_players WHERE player_id=? ORDER BY id DESC LIMIT 1", [String(record.id)]).first?["target"] ?? ""
        case .team: return try rows("SELECT championship_id AS target FROM championship_teams WHERE team_id=? ORDER BY id DESC LIMIT 1", [String(record.id)]).first?["target"] ?? ""
        default: return ""
        }
    }
    @discardableResult func save(_ supplied: RecordDraft) throws -> Int {
        var draft = supplied
        if draft.kind == .player {
            let choices = try attributeChoices()
            for key in ["player_foot_id", "player_morale_id"] {
                if draft.values[key, default: ""].isEmpty { draft.values[key] = choices[key]?.first?.id ?? "" }
                guard choices[key]?.contains(where: { $0.id == draft.values[key] }) == true else {
                    throw DatabaseIssue(message: "Select an existing option from the \(key == "player_foot_id" ? "player_foot" : "player_morale") table.")
                }
            }
        }
        if let message = draft.validation { throw DatabaseIssue(message: message) }
        let kind = draft.kind
        var columns = kind.fields.map(\.id)
        var values = kind.fields.map { field in
            let value = (draft.values[field.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return field.id == "country_iso3" ? value.uppercased() : value
        }
        if kind == .player, draft.id == nil {
            columns.append("player_initial_salary")
            values.append(String(Int.random(in: Footballer.minimumSalary...100)))
        }
        try execute("SAVEPOINT record_write")
        do {
            let id: Int
            if let existing = draft.id {
                guard !(try rows("SELECT id FROM \(kind.rawValue) WHERE id=?", [String(existing)])).isEmpty else { throw DatabaseIssue(message: "This record no longer exists. Close the form and refresh the list.") }
                try execute("UPDATE \(kind.rawValue) SET \(columns.map { "\($0)=?" }.joined(separator: ",")) WHERE id=?", values + [String(existing)])
                id = existing
            } else {
                try execute("INSERT INTO \(kind.rawValue) (\(columns.joined(separator: ","))) VALUES (\(columns.map { _ in "?" }.joined(separator: ",")))", values)
                id = Int(sqlite3_last_insert_rowid(handle))
            }
            let previousAssignment: String
            if let existing = draft.id {
                previousAssignment = try assignment(for: DatabaseRecord(id: existing, title: "", values: [:]), kind: kind)
            } else { previousAssignment = "" }
            if kind == .player, previousAssignment != draft.assignment {
                try execute("DELETE FROM team_players WHERE player_id=?", [String(id)])
                if !draft.assignment.isEmpty {
                    try execute("INSERT INTO team_players (team_id,player_id,team_player_start_date,team_player_end_date,team_player_transfer_value) VALUES (?,?,?,20991231,0)", [draft.assignment,String(id),RecordDraft.dateFormatter.string(from: Date())])
                }
            } else if kind == .team, previousAssignment != draft.assignment {
                try execute("DELETE FROM championship_teams WHERE team_id=?", [String(id)])
                if !draft.assignment.isEmpty {
                    try execute("INSERT INTO championship_teams (championship_id,team_id,championship_start_date,championship_end_date) VALUES (?,?,?,20991231)", [draft.assignment,String(id),RecordDraft.dateFormatter.string(from: Date())])
                }
            }
            if kind == .player {
                try savePlayerAttributes(draft.values, playerID: id)
                try ensurePlayerValue(id, recordTeamChange: draft.id != nil && previousAssignment != draft.assignment)
            }
            try execute("RELEASE SAVEPOINT record_write")
            return id
        } catch {
            try? execute("ROLLBACK TO SAVEPOINT record_write")
            try? execute("RELEASE SAVEPOINT record_write")
            if error.localizedDescription.contains("UNIQUE constraint") {
                throw DatabaseIssue(message: "A record with that name or code already exists. Choose a different value.")
            }
            throw error
        }
    }
    func attributeChoices() throws -> [String: [AttributeChoice]] {
        var result: [String: [AttributeChoice]] = [:]
        for table in ["player_foot", "player_morale"] {
            let existing = try rows("SELECT id, \(table)_name AS name FROM \(table) ORDER BY id")
            result["\(table)_id"] = existing.map { AttributeChoice(id: $0["id"] ?? "", name: $0["name"] ?? "") }
        }
        return result
    }
    private func savePlayerAttributes(_ values: [String: String], playerID: Int) throws {
        let foot = values["player_foot_id"] ?? "", morale = values["player_morale_id"] ?? ""
        for (table, attributes, extraColumns, extraValues) in [
            ("player_skills_physical", PlayerAttributes.physical, ["player_foot_id", "player_morale_id"], [foot, morale]),
            ("player_skills_mental", PlayerAttributes.mental, [], [])
        ] {
            let columns = attributes.map(\.id) + extraColumns
            let data = attributes.map { values[$0.id] ?? String($0.initial) } + extraValues
            if try rows("SELECT id FROM \(table) WHERE player_id=? LIMIT 1", [String(playerID)]).isEmpty {
                try execute("INSERT INTO \(table) (player_id,\(columns.joined(separator: ","))) VALUES (?,\(columns.map { _ in "?" }.joined(separator: ",")))", [String(playerID)] + data)
            } else {
                try execute("UPDATE \(table) SET \(columns.map { "\($0)=?" }.joined(separator: ",")) WHERE player_id=?", data + [String(playerID)])
            }
        }
    }
    /// The SQLite backup API includes committed WAL content, unlike a raw file copy.
    static func copy(from source: URL, to destination: URL) throws {
        let input = try FootballDatabase(url: source)
        var output: OpaquePointer?
        guard sqlite3_open(destination.path, &output) == SQLITE_OK else {
            if let output { sqlite3_close(output) }
            throw DatabaseIssue(message: "Cannot create the working database.")
        }
        defer { sqlite3_close(output) }
        guard let backup = sqlite3_backup_init(output, "main", input.handle, "main") else { throw DatabaseIssue(message: "Cannot copy the selected database.") }
        let result = sqlite3_backup_step(backup, -1)
        let finish = sqlite3_backup_finish(backup)
        guard result == SQLITE_DONE, finish == SQLITE_OK else { throw DatabaseIssue(message: "The database is busy or could not be copied. Try again.") }
    }
    static func install(from source: URL, to destination: URL) throws {
        if source.standardizedFileURL == destination.standardizedFileURL { return }
        let folder = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let temporary = folder.appending(path: "import-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try copy(from: source, to: temporary)
        // Validate the tables and columns used by the editor before replacing the working copy.
        let candidate = try FootballDatabase(url: temporary, writable: true)
        for kind in RecordKind.allCases {
            _ = try candidate.rows("SELECT id,\(kind.fields.map(\.id).joined(separator: ",")) FROM \(kind.rawValue) LIMIT 0")
        }
        _ = try Database.load(temporary)
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporary)
        } else { try FileManager.default.moveItem(at: temporary, to: destination) }
    }
}

struct GenerationReport {
    var counts: [RecordKind: Int] = [:]
    var summary: String {
        "Added " + RecordKind.allCases.compactMap { kind in
            guard let count = counts[kind], count > 0 else { return nil }
            return "\(count) \(count == 1 ? kind.singular.lowercased() : kind.title.lowercased())"
        }.joined(separator: ", ")
    }
}

extension FootballDatabase {
    /// One transaction includes generated records, attributes, memberships and missing dependencies.
    func generate(_ kind: RecordKind, count: Int, includeSquads: Bool = true, replaceAll: Bool = false, nationalities: [String] = [], realSquads: Bool = true) throws -> GenerationReport {
        guard (1...100).contains(count) else { throw DatabaseIssue(message: "Choose between 1 and 100 records.") }
        let choices = try attributeChoices()
        let profiles = (kind == .player || kind == .team) ? try CSVPlayerProfiles.loaded.get() : []
        let groupedProfiles = Dictionary(grouping: profiles, by: \.club)
        let profilesByClubID = Dictionary(grouping: profiles, by: \.clubID)
        let csvTeams = (kind == .player || kind == .team) ? try CSVTeam.load() : []
        let csvCountries = try CountryCatalog.load()
        var teamSources: [Int: String] = [:]
        var usedProfiles = Set<String>()
        func profileKey(_ profile: CSVPlayerProfile) -> String { "\(profile.first)|\(profile.last)|\(profile.dob)" }
        var report = GenerationReport()
        var cache: [RecordKind: [DatabaseRecord]] = [:]
        for type in RecordKind.allCases { cache[type] = try records(type) }
        func create(_ type: RecordKind, _ values: [String: String], assignment: String = "") throws -> Int {
            var draft = RecordDraft(kind: type)
            if type == .player { draft.values.merge(try PlayerAttributes.randomized(choices: choices)) { _, new in new } }
            draft.values.merge(values) { _, new in new }; draft.assignment = assignment
            let id = try save(draft)
            cache[type, default: []].append(DatabaseRecord(id: id, title: "", values: draft.values))
            report.counts[type, default: 0] += 1
            return id
        }
        func uniqueName(_ type: RecordKind, _ base: String) -> String {
            let existing = Set((cache[type] ?? []).map { ($0.values[type.nameColumn] ?? "").lowercased() })
            var index = (cache[type] ?? []).map(\.id).max().map { $0 + 1 } ?? 1
            while existing.contains("\(base) \(index)".lowercased()) { index += 1 }
            return "\(base) \(index)"
        }
        func country() throws -> Int {
            if let id = cache[.country]?.randomElement()?.id { return id }
            return try newCountry()
        }
        func newCountry() throws -> Int {
            let used = Set(cache[.country, default: []].compactMap { $0.values["country_iso3"] })
            guard let source = csvCountries.filter({ !used.contains($0.iso3) }).randomElement() else {
                throw DatabaseIssue(message: "All CSV countries are already in the database.")
            }
            return try create(.country, ["country_name": source.name, "country_iso3": source.iso3])
        }
        func newCity() throws -> Int {
            let parent = try country()
            return try create(.city, ["city_name": uniqueName(.city, "Sample " + ["Oakbridge", "Westhaven", "Riverton", "Ashford"].randomElement()!), "country_id": "\(parent)"])
        }
        func city() throws -> Int {
            if let id = cache[.city]?.randomElement()?.id { return id }
            return try newCity()
        }
        func newChampionship() throws -> Int {
            let parent = try country()
            return try create(.championship, ["championship_name": uniqueName(.championship, "Sample League"), "country_id": "\(parent)", "championship_teams_number": "\(min(128, max(2, count)))"])
        }
        func newTeam() throws -> Int {
            let usedNames = Set(cache[.team, default: []].map { $0.values["team_name", default: ""].lowercased() })
            guard let source = csvTeams.filter({ (nationalities.isEmpty || nationalities.contains($0.country)) && !usedNames.contains($0.name.lowercased()) && (includeSquads == false || realSquads == false || profilesByClubID[$0.id, default: []].count >= 22) }).randomElement(),
                  let sourceCountry = csvCountries.first(where: { $0.iso3 == source.country }) else {
                throw DatabaseIssue(message: "No unused CSV teams with matching country and sufficient player profiles remain.")
            }
            let countryID: Int
            if let existing = cache[.country]?.first(where: { $0.values["country_iso3"] == source.country }) { countryID = existing.id }
            else { countryID = try create(.country, ["country_name": sourceCountry.name, "country_iso3": sourceCountry.iso3]) }
            // No club city/foundation is supplied by team_details.csv; label the city as a placeholder.
            let home = try create(.city, ["city_name": uniqueName(.city, "Sample City"), "country_id": String(countryID)])
            let leagueName = source.league.isEmpty ? "Sample League – \(sourceCountry.name)" : source.league
            let competition: Int
            if let existing = cache[.championship]?.first(where: { $0.values["country_id"] == String(countryID) && $0.values["championship_name"] == leagueName }) { competition = existing.id }
            else { competition = try create(.championship, ["championship_name": leagueName, "country_id": String(countryID), "championship_teams_number": "\(min(128, max(2, count)))"]) }
            let team = try create(.team, ["team_name": source.name, "city_id": String(home), "team_foundation_date": "\(Int.random(in: 1880...2020))"], assignment: String(competition))
            let stadium = try create(.stadium, ["stadium_name": source.name + " Stadium", "city_id": String(home), "stadium_foundation": "\(Int.random(in: 1900...2020))", "stadium_seats": "\(Int.random(in: 50...300) * 100)"])
            try execute("INSERT INTO stadium_team (team_id,stadium_id) VALUES (?,?)", [String(team), String(stadium)])
            teamSources[team] = source.id
            return team
        }
        func newPlayer(team: Int) throws {
            let birthplace = try city()
            let teamName = cache[.team]?.first { $0.id == team }?.values["team_name"] ?? ""
            let realPool = teamSources[team].flatMap { profilesByClubID[$0] } ?? groupedProfiles[teamName] ?? []
            let pool = realSquads ? realPool : profiles
            let existing = Set(cache[.player, default: []].map { "\($0.values["player_name", default: ""])|\($0.values["player_lastname", default: ""])|\($0.values["player_dob", default: ""])" })
            let unused = pool.filter { !usedProfiles.contains(profileKey($0)) && !existing.contains(profileKey($0)) }
            let candidates = unused.isEmpty
                ? profiles.filter { !usedProfiles.contains(profileKey($0)) && !existing.contains(profileKey($0)) }
                : unused
            guard let profile = candidates.randomElement() else {
                throw DatabaseIssue(message: "No unused CSV profiles remain for \(teamName).")
            }
            usedProfiles.insert(profileKey(profile))
            let first = profile.first, surname = profile.last, dob = profile.dob
            let positions = try rows("SELECT p.* FROM position p LEFT JOIN player_position pp ON pp.position_id=p.id LEFT JOIN team_players tp ON tp.player_id=pp.player_id AND tp.team_id=? GROUP BY p.id ORDER BY COUNT(tp.id),p.id", [String(team)])
            guard let position = positions.first(where: { $0["position_name"] == profile.position }), let positionID = position["id"] else {
                throw DatabaseIssue(message: "The CSV position is missing from the position table. Add the required position before generating players.")
            }
            var values = ["player_name": first, "player_lastname": surname, "player_dob": dob, "city_id": "\(birthplace)"]
            if let foot = choices["player_foot_id"]?.first(where: { $0.name.lowercased() == profile.foot }) {
                values["player_foot_id"] = foot.id
            }
            let player = try create(.player, values, assignment: "\(team)")
            try execute("INSERT INTO player_position (player_id,position_id,player_position_strong,player_position_acquired,player_position_date_from) VALUES (?,?,1,0,?)", [String(player), positionID, RecordDraft.dateFormatter.string(from: Date())])

        }
        try execute("BEGIN IMMEDIATE")
        do {
            if replaceAll && kind != .city {
                // Preserve lookup definitions; remove the world in foreign-key order.
                for table in ["stadium_team", "stadium_improvement", "player_value", "player_position", "player_stats", "player_skills_physical", "player_skills_mental", "team_players", "championship_teams", "player", "team", "stadium", "manager", "championship", "city", "country"] {
                    try execute("DELETE FROM \(table)")
                }
                for type in RecordKind.allCases { cache[type] = [] }
            }
            if kind == .city {
                // Cities extend the existing world; deleting countries here also destroys their dependents.
                if cache[.country, default: []].isEmpty {
                    for source in csvCountries {
                        _ = try create(.country, ["country_name": source.name, "country_iso3": source.iso3])
                    }
                }
                let countries = cache[.country, default: []].sorted { $0.id < $1.id }
                var cityCounts = Dictionary(grouping: cache[.city, default: []], by: { $0.values["country_id"] ?? "" }).mapValues(\.count)
                func addCity(_ country: DatabaseRecord) throws {
                    _ = try create(.city, ["city_name": uniqueName(.city, "Sample " + (country.values["country_name"] ?? "City")), "country_id": String(country.id)])
                    cityCounts[String(country.id), default: 0] += 1
                }
                for country in countries where cityCounts[String(country.id), default: 0] == 0 { try addCity(country) }
                while report.counts[.city, default: 0] < count {
                    guard let target = countries.min(by: {
                        let left = cityCounts[String($0.id), default: 0], right = cityCounts[String($1.id), default: 0]
                        return left == right ? $0.id < $1.id : left < right
                    }) else { break }
                    try addCity(target)
                }
            }
            for _ in 0..<(kind == .city ? 0 : count) {
                switch kind {
                case .country: _ = try newCountry()
                case .city: _ = try newCity()
                case .championship: _ = try newChampionship()
                case .stadium:
                    let home = try city()
                    _ = try create(.stadium, ["stadium_name": uniqueName(.stadium, "Sample Stadium"), "city_id": "\(home)", "stadium_foundation": "\(Int.random(in: 1900...2020))", "stadium_seats": "\(Int.random(in: 50...300) * 100)"])
                case .team:
                    let team = try newTeam()
                    if includeSquads { for _ in 0..<22 { try newPlayer(team: team) } }
                case .player:
                    if cache[.team, default: []].isEmpty { _ = try newTeam() }
                    // Fill the smallest squad first, counting existing memberships too.
                    let target = try rows("SELECT t.id FROM team t LEFT JOIN team_players tp ON tp.team_id=t.id GROUP BY t.id ORDER BY COUNT(tp.id),t.id LIMIT 1").first?["id"]
                    guard let target, let team = Int(target) else { throw DatabaseIssue(message: "Create a team before generating players.") }
                    try newPlayer(team: team)
                }
            }
            try execute("COMMIT")
            return report
        } catch { try? execute("ROLLBACK"); throw error }
    }
}
