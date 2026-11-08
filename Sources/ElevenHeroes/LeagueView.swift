import SwiftUI

extension ContentView {
    func league(_ s: Season) -> some View {
        LeagueStandingsView(season: s, onTeam: showTeam)
    }
}

private enum LeagueTableMode: String, CaseIterable, Identifiable {
    case overall = "Overall"
    case home = "Home"
    case away = "Away"
    case all = "All"
    var id: String { rawValue }
}

private enum LeagueSortKey: String {
    case club
    case played, won, drawn, lost, scored, conceded, difference, points
    case homePlayed, homeWon, homeDrawn, homeLost, homeScored, homeConceded, homeDifference, homePoints
    case awayPlayed, awayWon, awayDrawn, awayLost, awayScored, awayConceded, awayDifference, awayPoints
}

private struct LeagueColumn: Identifiable {
    let id = UUID()
    let title: String
    let width: CGFloat
    let sortKey: LeagueSortKey?
    let text: (Standing) -> String
    let color: (Standing) -> Color
}

private struct LeagueStandingsView: View {
    let season: Season
    let onTeam: (Int) -> Void

    @State private var mode: LeagueTableMode = .overall
    @State private var sortKey: LeagueSortKey = .points
    @State private var ascending: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tableContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("#").frame(width: 34, alignment: .center)
                Text("CLUB").frame(maxWidth: .infinity, alignment: .leading).frame(minWidth: 150)
                ForEach(columns) { column in
                    headerCell(column)
                }
                Spacer().frame(width: 18)
                Text("FORM").frame(width: 78, alignment: .trailing)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.panel.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))

            VStack(spacing: 0) {
                ForEach(Array(sortedStandings.enumerated()), id: \.element.id) { index, row in
                    StandingRow(index: index, row: row, season: season, columns: columns, formResults: formResults(row), selected: row.id == season.selectedClub, onTeam: onTeam, sortKey: $sortKey, ascending: $ascending, reduceMotion: reduceMotion)
                    if index < sortedStandings.count - 1 {
                        Divider().opacity(0.25).padding(.leading, 12)
                    }
                }
            }
            .background(AppTheme.panel.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.08)))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var overallColumns: [LeagueColumn] {
        [
            col("P", .played, { "\($0.played)" }),
            col("W", .won, { "\($0.won)" }),
            col("D", .drawn, { "\($0.drawn)" }),
            col("L", .lost, { "\($0.lost)" }),
            col("GF", .scored, { "\($0.scored)" }),
            col("GA", .conceded, { "\($0.conceded)" }),
            col("GD", .difference, { $0.difference >= 0 ? "+\($0.difference)" : "\($0.difference)" }, color: { $0.difference > 0 ? .green : $0.difference < 0 ? .red : .secondary }),
            col("Pts", .points, { "\($0.points)" }, color: { _ in AppTheme.accent })
        ]
    }

    private var homeColumns: [LeagueColumn] {
        [
            col("P", .homePlayed, { "\($0.homePlayed)" }),
            col("W", .homeWon, { "\($0.homeWon)" }),
            col("D", .homeDrawn, { "\($0.homeDrawn)" }),
            col("L", .homeLost, { "\($0.homeLost)" }),
            col("GF", .homeScored, { "\($0.homeScored)" }),
            col("GA", .homeConceded, { "\($0.homeConceded)" }),
            col("GD", .homeDifference, { $0.homeDifference >= 0 ? "+\($0.homeDifference)" : "\($0.homeDifference)" }, color: { $0.homeDifference > 0 ? .green : $0.homeDifference < 0 ? .red : .secondary }),
            col("Pts", .homePoints, { "\($0.homePoints)" }, color: { _ in AppTheme.accent })
        ]
    }

    private var awayColumns: [LeagueColumn] {
        [
            col("P", .awayPlayed, { "\($0.awayPlayed)" }),
            col("W", .awayWon, { "\($0.awayWon)" }),
            col("D", .awayDrawn, { "\($0.awayDrawn)" }),
            col("L", .awayLost, { "\($0.awayLost)" }),
            col("GF", .awayScored, { "\($0.awayScored)" }),
            col("GA", .awayConceded, { "\($0.awayConceded)" }),
            col("GD", .awayDifference, { $0.awayDifference >= 0 ? "+\($0.awayDifference)" : "\($0.awayDifference)" }, color: { $0.awayDifference > 0 ? .green : $0.awayDifference < 0 ? .red : .secondary }),
            col("Pts", .awayPoints, { "\($0.awayPoints)" }, color: { _ in AppTheme.accent })
        ]
    }

    private var columns: [LeagueColumn] {
        switch mode {
        case .overall: return overallColumns
        case .home: return homeColumns
        case .away: return awayColumns
        case .all:
            return overallColumns.map { prefixed($0, "All ") }
                + homeColumns.map { prefixed($0, "H. ") }
                + awayColumns.map { prefixed($0, "A. ") }
        }
    }

    private func col(_ title: String, _ key: LeagueSortKey, _ text: @escaping (Standing) -> String, width: CGFloat = 38, color: @escaping (Standing) -> Color = { _ in .primary }) -> LeagueColumn {
        LeagueColumn(title: title, width: width, sortKey: key, text: text, color: color)
    }

    private func prefixed(_ column: LeagueColumn, _ prefix: String) -> LeagueColumn {
        LeagueColumn(title: prefix + column.title, width: column.width, sortKey: column.sortKey, text: column.text, color: column.color)
    }

    private var sortedStandings: [Standing] {
        season.standings.sorted { a, b in
            if sortKey == .club {
                let cmp = a.club.name.localizedStandardCompare(b.club.name)
                if cmp != .orderedSame {
                    return ascending ? cmp == .orderedAscending : cmp == .orderedDescending
                }
            } else {
                let av = numericValue(a, sortKey)
                let bv = numericValue(b, sortKey)
                if av != bv { return ascending ? av < bv : av > bv }
            }
            if a.points != b.points { return a.points > b.points }
            if a.difference != b.difference { return a.difference > b.difference }
            if a.scored != b.scored { return a.scored > b.scored }
            return a.club.name < b.club.name
        }
    }

    private func numericValue(_ row: Standing, _ key: LeagueSortKey) -> Int {
        switch key {
        case .club: return 0
        case .played: return row.played
        case .won: return row.won
        case .drawn: return row.drawn
        case .lost: return row.lost
        case .scored: return row.scored
        case .conceded: return row.conceded
        case .difference: return row.difference
        case .points: return row.points
        case .homePlayed: return row.homePlayed
        case .homeWon: return row.homeWon
        case .homeDrawn: return row.homeDrawn
        case .homeLost: return row.homeLost
        case .homeScored: return row.homeScored
        case .homeConceded: return row.homeConceded
        case .homeDifference: return row.homeDifference
        case .homePoints: return row.homePoints
        case .awayPlayed: return row.awayPlayed
        case .awayWon: return row.awayWon
        case .awayDrawn: return row.awayDrawn
        case .awayLost: return row.awayLost
        case .awayScored: return row.awayScored
        case .awayConceded: return row.awayConceded
        case .awayDifference: return row.awayDifference
        case .awayPoints: return row.awayPoints
        }
    }

    private var tableHeight: CGFloat {
        CGFloat(sortedStandings.count + 1) * 44 + 28
    }

    private var formResults: (Standing) -> [Character?] {
        { row in
            let clubID = row.id
            let played = season.fixtures
                .filter { $0.homeGoals != nil && ($0.home == clubID || $0.away == clubID) }
                .sorted { $0.round == $1.round ? $0.id < $1.id : $0.round < $1.round }
            var results: [Character?] = played.suffix(5).map { fixture in
                let own = fixture.home == clubID ? (fixture.homeGoals ?? 0) : (fixture.awayGoals ?? 0)
                let opponent = fixture.home == clubID ? (fixture.awayGoals ?? 0) : (fixture.homeGoals ?? 0)
                if own > opponent { return "W" }
                if own == opponent { return "D" }
                return "L"
            }
            while results.count < 5 { results.insert(nil, at: 0) }
            return results
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("LEAGUE STANDINGS").font(.system(size: 11, weight: .bold)).tracking(1.7).foregroundStyle(.secondary)
                HStack(spacing: 18) {
                    Label("\(season.clubs.count) clubs", systemImage: "person.3")
                    Label("Matchweek \(min(max(season.round - 1, 0), season.fixtures.map(\.round).max() ?? 0)) of \(season.fixtures.map(\.round).max() ?? 0)", systemImage: "calendar")
                    if let leader = sortedStandings.first {
                        Label("Leader: \(leader.club.name)", systemImage: "trophy")
                    }
                    Spacer()
                    Picker("View", selection: $mode) {
                        ForEach(LeagueTableMode.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented).frame(maxWidth: 260)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                GeometryReader { geometry in
                    Group {
                        if mode == .all {
                            ScrollView(.horizontal, showsIndicators: true) {
                                tableContent.frame(minWidth: geometry.size.width)
                            }
                        } else {
                            tableContent.frame(maxWidth: .infinity)
                        }
                    }
                }
                .frame(height: tableHeight)

                Text("Click a column header to sort. 3 points for a win · 1 for a draw · Ties: goal difference, goals scored, club name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 14))
            .frame(maxWidth: .infinity, alignment: .leading)
        }

    private func headerCell(_ column: LeagueColumn) -> some View {
        Group {
            if let key = column.sortKey {
                Button {
                    if sortKey == key { ascending.toggle() } else {
                        sortKey = key
                        ascending = (key == .club)
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(column.title)
                        if sortKey == key { Image(systemName: ascending ? "chevron.up" : "chevron.down").font(.system(size: 9)) }
                    }
                    .frame(width: column.width, alignment: .trailing)
                }.buttonStyle(.plain).help("Sort by \(column.title)")
            } else {
                Text(column.title).frame(width: column.width, alignment: .trailing)
            }
        }
    }

    private func toggleSort(_ key: LeagueSortKey) {
        if sortKey == key { ascending.toggle() } else {
            sortKey = key
            ascending = (key == .club)
        }
    }
}

private struct StandingRow: View {
    let index: Int
    let row: Standing
    let season: Season
    let columns: [LeagueColumn]
    let formResults: [Character?]
    let selected: Bool
    let onTeam: (Int) -> Void
    @Binding var sortKey: LeagueSortKey
    @Binding var ascending: Bool
    let reduceMotion: Bool

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            Text("\(index + 1)")
                .font(.system(size: 13, weight: index < 3 ? .bold : .medium, design: .rounded))
                .foregroundStyle(index == 0 ? AppTheme.accent : (index < 3 ? Color.primary : Color.secondary))
                .monospacedDigit()
                .contentTransition(.numericText())
                .frame(width: 34, alignment: .center)

            Button(row.club.name) { onTeam(row.id) }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: selected ? .bold : .semibold))
                .foregroundStyle(selected ? AppTheme.accent : Color.primary)
                .frame(minWidth: 150, maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .help("View team and squad")
                .accessibilityAddTraits(selected ? .isSelected : [])

            ForEach(columns) { column in
                Text(column.text(row))
                    .font(.system(size: 13, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(column.color(row))
                    .frame(width: column.width, alignment: .trailing)
            }

            Spacer().frame(width: 18)

            HStack(spacing: 3) {
                ForEach(Array(formResults.enumerated()), id: \.offset) { _, result in
                    if let result {
                        Text(String(result))
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(result == "W" ? .green : result == "D" ? .secondary : .red)
                            .frame(width: 14, height: 14)
                            .background((result == "W" ? Color.green : result == "D" ? Color.gray : Color.red).opacity(0.16), in: Circle())
                    } else {
                        Circle().fill(Color.clear).frame(width: 14, height: 14)
                    }
                }
            }
            .frame(width: 78, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            selected ? AppTheme.accent.opacity(0.12) :
            isHovered ? AppTheme.accent.opacity(0.06) :
            (index.isMultiple(of: 2) ? AppTheme.panel.opacity(0.35) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isHovered)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Position \(index + 1), \(row.club.name), played \(row.played), won \(row.won), drawn \(row.drawn), lost \(row.lost), scored \(row.scored), conceded \(row.conceded), goal difference \(row.difference), points \(row.points)")
    }
}