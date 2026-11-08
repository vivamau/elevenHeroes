import Foundation

struct CSVPlayerProfile: Decodable {
    let first: String
    let last: String
    let dob: String
    let club: String
    let clubID: String
    let position: String
    let foot: String
    let image: String?
}

enum CSVPlayerProfiles {
    static let loaded: Result<[CSVPlayerProfile], Error> = Result {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: "player_profiles", withExtension: "json") else {
            throw DatabaseIssue(message: "Player profiles are missing. Rebuild the app with player_profiles.csv.")
        }
        return try JSONDecoder().decode([CSVPlayerProfile].self, from: Data(contentsOf: url))
    }
    static func image(for first: String, last: String) -> String? {
        (try? loaded.get())?.first { $0.first == first && $0.last == last }?.image
    }
}

struct CSVTeam: Decodable {
    let id: String
    let name: String
    let country: String
    let league: String
    let logo: String?
    static func load() throws -> [CSVTeam] {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: "team_details", withExtension: "json") else {
            throw DatabaseIssue(message: "Team data is missing. Rebuild with team_details.csv.")
        }
        return try JSONDecoder().decode([CSVTeam].self, from: Data(contentsOf: url))
    }
    static func logo(for teamName: String) -> String? {
        (try? load())?.first { $0.name == teamName }?.logo
    }
}
