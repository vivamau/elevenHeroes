import SwiftUI

struct GoalEvent: Codable {
    let clubID: Int
    let clubName: String
    let scorerID: Int?
    let scorerName: String?
    let assistID: Int?
    let assistName: String?
    var minute: Int? = nil
}

struct SeasonLeader: Identifiable {
    let id: Int
    let name: String
    var clubs: Set<String>
    var total: Int
}

extension CompletedSeason {
    func table(fallbackClubs: [Club]) -> [Standing] {
        Season(clubs: clubs ?? fallbackClubs, fixtures: fixtures, selectedClub: -1, demo: false).standings
    }
    var hasCompletePlayerStats: Bool { fixtures.allSatisfy { $0.goalEvents != nil } }
    func leaders(assists: Bool) -> [SeasonLeader] {
        var totals: [Int: SeasonLeader] = [:]
        for event in fixtures.flatMap({ $0.goalEvents ?? [] }) {
            guard let id = assists ? event.assistID : event.scorerID,
                  let name = assists ? event.assistName : event.scorerName else { continue }
            var row = totals[id] ?? SeasonLeader(id: id, name: name, clubs: [], total: 0)
            row.total += 1
            row.clubs.insert(event.clubName)
            totals[id] = row
        }
        return totals.values.sorted {
            if $0.total != $1.total { return $0.total > $1.total }
            if $0.name != $1.name { return $0.name < $1.name }
            return $0.id < $1.id
        }
    }
}

struct SeasonHistoryView: View {
    let season: CompletedSeason
    let fallbackClubs: [Club]
    var career: Season? = nil
    let onBack: () -> Void
    @State private var section = "League table"
    private let sections = ["League table", "Top scorers", "Top assists"]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Button(action: onBack) { Label("Back to overview", systemImage: "chevron.left") }
                .buttonStyle(.plain).foregroundStyle(AppTheme.accent)
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Season \(String(season.year))").font(.largeTitle.bold())
                    Label("\(season.champion) · Champions", systemImage: "trophy.fill")
                        .foregroundStyle(AppTheme.accent)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(season.fixtures.count) matches").fontWeight(.semibold)
                    Text("\(season.fixtures.reduce(0) { $0 + ($1.homeGoals ?? 0) + ($1.awayGoals ?? 0) }) goals").foregroundStyle(.secondary)
                    if let price = season.ticketPrice {
                        Text("Home tickets · \(price) credits").font(.caption).foregroundStyle(.secondary)
                    }
                }.monospacedDigit()
            }
            Picker("Season statistics", selection: $section) {
                ForEach(sections, id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented).frame(maxWidth: 480)
            if section == "League table" {
                leagueTable
                SeasonPositionsView(season: season, fallbackClubs: fallbackClubs)
                SeasonMatchesView(season: season, fallbackClubs: fallbackClubs, career: career)
            } else {
                leaders
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var leagueTable: some View {
        let rows = season.table(fallbackClubs: fallbackClubs)
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("#").frame(width: 34, alignment: .center)
                Text("CLUB").frame(maxWidth: .infinity, alignment: .leading)
                ForEach(["P", "W", "D", "L", "GF", "GA", "GD", "PTS"], id: \.self) { key in
                    Text(key).frame(width: 34, alignment: .trailing)
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.panel.opacity(0.6))

            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                VStack(spacing: 0) {
                    if index > 0 { Divider().opacity(0.25).padding(.leading, 12) }
                    HStack(spacing: 0) {
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: index < 3 ? .bold : .medium, design: .rounded))
                            .foregroundStyle(index == 0 ? AppTheme.accent : (index < 3 ? Color.primary : Color.secondary))
                            .monospacedDigit()
                            .frame(width: 34, alignment: .center)
                        Text(row.club.name)
                            .font(.system(size: 13, weight: index == 0 ? .bold : .semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                        Group {
                            Text("\(row.played)").frame(width: 34, alignment: .trailing)
                            Text("\(row.won)").frame(width: 34, alignment: .trailing)
                            Text("\(row.drawn)").frame(width: 34, alignment: .trailing)
                            Text("\(row.lost)").frame(width: 34, alignment: .trailing)
                            Text("\(row.scored)").frame(width: 34, alignment: .trailing)
                            Text("\(row.conceded)").frame(width: 34, alignment: .trailing)
                            Text(row.difference >= 0 ? "+\(row.difference)" : "\(row.difference)")
                                .foregroundStyle(row.difference > 0 ? .green : row.difference < 0 ? .red : .secondary)
                                .frame(width: 34, alignment: .trailing)
                            Text("\(row.points)")
                                .fontWeight(.bold)
                                .foregroundStyle(index == 0 ? AppTheme.accent : Color.primary)
                                .frame(width: 34, alignment: .trailing)
                        }
                        .font(.system(size: 13, design: .rounded))
                        .monospacedDigit()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(index.isMultiple(of: 2) ? AppTheme.panel.opacity(0.35) : Color.clear)
                }
            }
        }
        .background(AppTheme.panel.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.08)))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var leaders: some View {
        let assists = section == "Top assists"
        let rows = season.leaders(assists: assists)
        return VStack(alignment: .leading, spacing: 16) {
            if !season.hasCompletePlayerStats {
                Label("Incomplete records: goals and assists were not tracked for some matches in this season.", systemImage: "info.circle")
                    .font(.callout).foregroundStyle(.secondary)
            }
            if rows.isEmpty {
                ContentUnavailableView("No \(assists ? "assists" : "goals") recorded", systemImage: "chart.bar", description: Text("Player statistics are saved for matches played with this version of the app."))
            } else {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    HStack(spacing: 16) {
                        Text("\(index + 1)").foregroundStyle(.secondary).frame(width: 25)
                        VStack(alignment: .leading, spacing: 4) {
                            PlayerNameLink(id: row.id, name: row.name, career: career, teamName: row.clubs.sorted().joined(separator: ", ")).fontWeight(.semibold)
                            Text(row.clubs.sorted().joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(row.total) \(assists ? "assists" : "goals")").fontWeight(.semibold).foregroundStyle(AppTheme.accent)
                    }.monospacedDigit().padding(.vertical, 5)
                    if index < rows.count - 1 { Divider() }
                }
            }
        }.padding(22).frame(maxWidth: .infinity).background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 14))
    }
}
