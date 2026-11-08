import SwiftUI

extension ContentView {
    func matches(_ s: Season) -> some View {
        let latestFixture = s.fixtures.first { $0.round == s.round - 1 && $0.homeGoals != nil && ($0.home == s.selectedClub || $0.away == s.selectedClub) }
        let upcomingFixture = s.fixtures.first { $0.round == s.round && ($0.home == s.selectedClub || $0.away == s.selectedClub) }
        let squadFixture = latestFixture ?? upcomingFixture
        return VStack(spacing: 22) {
            if !s.commentary.isEmpty {
                card("Latest match report") { LatestMatchReportView(season: s) }
            }
            if let fixture = squadFixture {
                card("Match squads · \(teamName(s, fixture.home)) vs \(teamName(s, fixture.away))") {
                    HStack(alignment: .top, spacing: 24) {
                        squadColumn(club: s.clubs.first { $0.id == fixture.home }, fixture: fixture, isHome: true)
                        squadColumn(club: s.clubs.first { $0.id == fixture.away }, fixture: fixture, isHome: false)
                    }
                }
            }
            card("Season fixtures") {
                ForEach(1...(s.fixtures.map(\.round).max() ?? 1), id: \.self) { round in
                    Text("MATCHWEEK \(round)").font(.caption.bold()).foregroundStyle(AppTheme.accent).padding(.top, 10)
                    ForEach(s.fixtures.filter { $0.round == round }) { f in
                        HStack {
                            teamLink(f.home).frame(maxWidth: .infinity, alignment: .trailing)
                            Text(f.homeGoals.map { "\($0)  –  \(f.awayGoals ?? 0)" } ?? "vs").font(.system(.title3, design: .monospaced).bold()).frame(width: 85).padding(.vertical, 8).background(AppTheme.background, in: RoundedRectangle(cornerRadius: 6))
                            teamLink(f.away).frame(maxWidth: .infinity, alignment: .leading)
                        }.foregroundStyle(f.home == s.selectedClub || f.away == s.selectedClub ? AppTheme.accent : .primary)
                        MatchAttendanceView(fixture: f, showRevenue: false)
                        FixtureFinanceView(fixture: f)
                    }
                }
            }
        }
    }

    private func teamName(_ s: Season, _ id: Int) -> String {
        s.clubs.first { $0.id == id }?.name ?? "Unknown club"
    }

    private func squadColumn(club: Club?, fixture: Fixture, isHome: Bool) -> some View {
        let starters = isHome ? (fixture.homeLineup ?? []) : (fixture.awayLineup ?? [])
        let subs = isHome ? (fixture.homeSubstitutes ?? []) : (fixture.awaySubstitutes ?? [])
        let passes = isHome ? (fixture.homePasses ?? [:]) : (fixture.awayPasses ?? [:])
        let matchdayIDs = starters + subs
        return VStack(alignment: .leading, spacing: 8) {
            Text(club?.name ?? "Unknown club").font(.headline).foregroundStyle(AppTheme.accent)
            if let club {
                ForEach(club.players.sorted { a, b in
                    let aPlaying = matchdayIDs.contains(a.id)
                    let bPlaying = matchdayIDs.contains(b.id)
                    if aPlaying != bPlaying { return aPlaying }
                    let aStarter = starters.contains(a.id)
                    let bStarter = starters.contains(b.id)
                    if aStarter != bStarter { return aStarter }
                    let order = ["GK": 0, "DEF": 1, "MID": 2, "FWD": 3]
                    if (order[a.role] ?? 4) != (order[b.role] ?? 4) { return (order[a.role] ?? 4) < (order[b.role] ?? 4) }
                    return a.rating > b.rating
                }) { player in
                    let playing = matchdayIDs.contains(player.id)
                    let goals = playing ? (fixture.goalEvents ?? []).filter { $0.clubID == club.id && $0.scorerID == player.id }.count : 0
                    let assists = playing ? (fixture.goalEvents ?? []).filter { $0.clubID == club.id && $0.assistID == player.id }.count : 0
                    let starter = starters.contains(player.id)
                    let passCount = playing ? (passes[player.id] ?? 0) : 0
                    HStack(spacing: 8) {
                        Button(player.name) { viewedPlayer = player }.buttonStyle(.plain).foregroundStyle(.white).fontWeight(.medium).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        Text(player.profile?.values["position_name"] ?? player.role)
                            .font(.caption).foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
                        Text(!playing ? "—" : (starter ? "XI" : "Sub"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(!playing ? .secondary : (starter ? AppTheme.accent : .secondary))
                            .frame(width: 32, alignment: .trailing)
                        Text(goals > 0 ? "G\(goals)" : "·")
                            .font(.caption.monospacedDigit()).frame(width: 28, alignment: .trailing)
                        Text(assists > 0 ? "A\(assists)" : "·")
                            .font(.caption.monospacedDigit()).frame(width: 28, alignment: .trailing)
                        Text(passCount > 0 ? "P\(passCount)" : "·")
                            .font(.caption.monospacedDigit()).frame(width: 32, alignment: .trailing)
                        Text(playing ? "\(matchRating(goals: goals, assists: assists, passes: passCount))" : "—").font(.caption.monospacedDigit()).frame(width: 32, alignment: .trailing)
                    }
                }
            } else {
                Text("No squad data.").font(.caption).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func matchRating(goals: Int, assists: Int, passes: Int) -> Int {
        var score = 5.0
        score += Double(goals) * 1.5
        score += Double(assists) * 1.0
        score += Double(passes) / 20.0
        return min(10, max(1, Int(score.rounded())))
    }

}
