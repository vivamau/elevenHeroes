import SwiftUI

struct SeasonMatchesView: View {
    let season: CompletedSeason
    let fallbackClubs: [Club]
    var career: Season? = nil

    @State private var selectedTeam: Int? = nil
    private var matches: [Fixture] {
        season.fixtures.filter { selectedTeam == nil || $0.home == selectedTeam || $0.away == selectedTeam }
    }
    private var teamIDs: [Int] {
        Set(season.fixtures.flatMap { [$0.home, $0.away] }).sorted {
            let order = name($0).localizedStandardCompare(name($1))
            return order == .orderedSame ? $0 < $1 : order == .orderedAscending
        }
    }
    private var rounds: [Int] { Set(matches.map(\.round)).sorted() }
    private func name(_ id: Int) -> String {
        (season.clubs ?? fallbackClubs).first { $0.id == id }?.name ?? "Club \(id)"
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Match details").font(.title2.weight(.semibold))
                    Text("\(matches.count) matches").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 8)], alignment: .leading, spacing: 8) {
                teamFilter(nil, title: "All teams")
                ForEach(teamIDs, id: \.self) { id in
                    teamFilter(id, title: name(id))
                }
            }.accessibilityElement(children: .contain).accessibilityLabel("Filter matches by team")
            if matches.isEmpty {
                ContentUnavailableView("No matches", systemImage: "sportscourt", description: Text("No matches are recorded for this selection."))
            }
            ForEach(rounds, id: \.self) { round in
                Text("MATCHWEEK \(round)").font(.caption.weight(.semibold))
                    .tracking(1).foregroundStyle(.secondary).padding(.top, 8)
                ForEach(matches.filter { $0.round == round }.sorted { $0.id < $1.id }) { fixture in
                    match(fixture)
                }
            }
        }
        .onChange(of: season.year) { _, _ in selectedTeam = nil }
    }

    private func teamFilter(_ id: Int?, title: String) -> some View {
        let selected = selectedTeam == id
        return Button { selectedTeam = id } label: {
            HStack(spacing: 8) {
                Image(systemName: selected ? "checkmark.circle.fill" : id == nil ? "square.grid.2x2" : "shield")
                Text(title).font(.callout.weight(selected ? .semibold : .medium))
                    .lineLimit(2).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }.padding(.horizontal, 14).padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(selected ? AppTheme.background : Color.primary)
                .background(selected ? AppTheme.accent : AppTheme.panel, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.primary.opacity(selected ? 0 : 0.16)))
                .contentShape(Capsule())
        }.buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .help(id == nil ? "Show every match" : "Show home and away matches for \(title)")
    }

    private func match(_ fixture: Fixture) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                Text(name(fixture.home)).frame(maxWidth: .infinity, alignment: .trailing)
                Text("\(fixture.homeGoals.map(String.init) ?? "–") – \(fixture.awayGoals.map(String.init) ?? "–")")
                    .font(.title3.weight(.bold)).monospacedDigit().foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 8))
                Text(name(fixture.away)).frame(maxWidth: .infinity, alignment: .leading)
            }.font(.headline)
            MatchAttendanceView(fixture: fixture)
            Divider()
            if let events = fixture.goalEvents {
                if events.isEmpty {
                    Text("No goals scored.").font(.callout).foregroundStyle(.secondary)
                } else {
                    ForEach(events.indices.sorted { (events[$0].minute ?? 91) < (events[$1].minute ?? 91) }, id: \.self) { index in
                        let event = events[index]
                        HStack(alignment: .top, spacing: 12) {
                            Text(event.minute.map { "\($0)′" } ?? "—")
                                .monospacedDigit().foregroundStyle(.secondary).frame(width: 35, alignment: .leading)
                                .accessibilityLabel(event.minute.map { "Minute \($0)" } ?? "Minute not recorded")
                            Image(systemName: "soccerball").foregroundStyle(AppTheme.accent)
                            VStack(alignment: .leading, spacing: 4) {
                                if let id = event.scorerID, let name = event.scorerName {
                                    PlayerNameLink(id: id, name: name, career: career, teamName: event.clubName).fontWeight(.medium)
                                } else { Text(event.scorerName ?? "Scorer not recorded") }
                                if let id = event.assistID, let name = event.assistName {
                                    HStack(spacing: 4) {
                                        Text("Assist:").foregroundStyle(.secondary)
                                        PlayerNameLink(id: id, name: name, career: career, teamName: event.clubName)
                                    }.font(.caption)
                                } else { Text("Unassisted").font(.caption).foregroundStyle(.secondary) }
                            }
                            Spacer(minLength: 12)
                            Text(event.clubName).font(.caption).foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }.font(.callout).padding(.vertical, 3)
                    }
                }
            } else {
                Label("Scorers and assists were not recorded for this match.", systemImage: "info.circle")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }.padding(20).background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 14))
    }
}
