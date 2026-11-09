import Foundation

struct Tactic: Identifiable, Codable, Equatable {
    let id: Int
    var name: String
    var attack: Double
    var defense: Double
}

extension FootballDatabase {
    func tactics() throws -> [Tactic] {
        try rows("SELECT id, tactic_name, tactic_attack, tactic_defense FROM tactic ORDER BY id").map { row in
            Tactic(
                id: Int(row["id"] ?? "0") ?? 0,
                name: row["tactic_name"] ?? "",
                attack: Double(row["tactic_attack"] ?? "0") ?? 0,
                defense: Double(row["tactic_defense"] ?? "0") ?? 0
            )
        }
    }

    @discardableResult
    func saveTactic(id: Int? = nil, name: String, attack: Double, defense: Double) throws -> Int {
        if let id {
            try execute("UPDATE tactic SET tactic_name=?, tactic_attack=?, tactic_defense=? WHERE id=?", [name, String(attack), String(defense), String(id)])
            return id
        }
        try execute("INSERT INTO tactic (tactic_name, tactic_attack, tactic_defense) VALUES (?,?,?)", [name, String(attack), String(defense)])
        let rows = try rows("SELECT last_insert_rowid() AS id")
        return Int(rows.first?["id"] ?? "0") ?? 0
    }

    func deleteTactic(id: Int) throws {
        try execute("DELETE FROM tactic WHERE id=?", [String(id)])
    }
}