import Foundation

struct PlayerValueRecord: Codable, Hashable, Identifiable {
    let id: String
    let date: String
    let credits: Int
    let teamID: Int?
    let teamName: String?
    var event: String? = nil
    var matchweek: Int? = nil
    var seasonYear: Int? = nil
    var salary: Int? = nil

    var dateLabel: String {
        guard let parsed = RecordDraft.dateFormatter.date(from: date) else { return "Date not recorded" }
        return parsed.formatted(.dateTime.day().month(.abbreviated).year())
    }
    var teamLabel: String { teamName ?? "Team not recorded" }
}

extension Footballer {
    mutating func recordValue(teamID: Int?, teamName: String?, event: String, matchweek: Int? = nil, seasonYear: Int? = nil) {
        let record = PlayerValueRecord(id: UUID().uuidString,
            date: RecordDraft.dateFormatter.string(from: Date()), credits: creditsValue,
            teamID: teamID, teamName: teamName, event: event, matchweek: matchweek, seasonYear: seasonYear, salary: currentSalary)
        if valueHistory == nil { valueHistory = [] }
        valueHistory?.append(record)
    }
}
