import SwiftUI

extension ContentView {
    func overview(_ s: Season) -> some View {
        VStack(spacing: 22) {
            HStack(spacing: 16) {
                let row = s.standings.first { $0.id == s.selectedClub }
                metric("LEAGUE POSITION", "\((s.standings.firstIndex { $0.id == s.selectedClub } ?? 0)+1)", "of \(s.clubs.count) clubs")
                metric("POINTS", "\(row?.points ?? 0)", "\(row?.played ?? 0) matches played")
                metric("GOAL DIFFERENCE", String(format: "%+d", row?.difference ?? 0), "\(row?.scored ?? 0) scored · \(row?.conceded ?? 0) conceded")
            }
            HStack(alignment: .top, spacing: 22) {
                VStack(spacing: 22) {
                    card(s.finished ? "Season review" : "Next fixture") {
                        if let f = s.fixtures.first(where: { $0.round == s.round && ($0.home == s.selectedClub || $0.away == s.selectedClub) }) {
                            HStack {
                                Button { showTeam(f.home) } label: { crest(store.name(f.home)) }.buttonStyle(.plain); Spacer(); Text("VS").font(.title2.bold()).foregroundStyle(.secondary); Spacer(); Button { showTeam(f.away) } label: { crest(store.name(f.away)) }.buttonStyle(.plain)
                            }.padding(.vertical, 18)
                            Divider()
                            Text("MATCHWEEK \(s.round)   •   \(f.home == s.selectedClub ? "HOME" : "AWAY")").font(.caption.bold()).foregroundStyle(AppTheme.accent)
                        } else { Text(s.finished ? "\(s.standings.first?.club.name ?? "") are champions." : "A rest week for your club. Play the matchweek to continue.").font(.title2.bold()) }
                        Divider()
                        HomeAttendanceView(season: s)
                    }
                    if let history = s.completedSeasons, !history.isEmpty {
                        card("Previous seasons") {
                            ForEach(history.indices, id: \.self) { index in
                                Button { viewedSeason = history[index] } label: {
                                    HStack {
                                        Text("Season \(String(history[index].year))").fontWeight(.semibold).foregroundStyle(AppTheme.accent)
                                        Spacer()
                                        Text(history[index].champion).foregroundStyle(.secondary)
                                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                                    }.padding(.vertical, 8).contentShape(Rectangle())
                                }.buttonStyle(.plain).help("View league table, goals and assists")
                            }
                        }
                    }
                    if s.goalkeepersNeeded > 0 {
                        card("Goalkeeper cover") {
                            Text("Your squad needs \(s.goalkeepersNeeded) more goalkeeper(s). Every team must have at least two.")
                            Button("Buy a goalkeeper in Market") { store.screen = "Market" }.buttonStyle(.borderedProminent)
                        }
                    }
                    if s.replacementsNeeded > 0 {
                        card("Retirement replacements") {
                            Text("\(s.replacementsNeeded) replacements needed before playing a matchweek.")
                            ForEach((s.retiredPlayers ?? []).filter { $0.clubID == s.selectedClub && $0.year == s.year }) { record in
                                PlayerNameLink(id: record.id, name: record.player.name, career: s, player: record.player, teamName: "Retired · \(String(record.year))")
                            }
                            Button("Find replacements in Market") { store.screen = "Market" }
                                .buttonStyle(.borderedProminent).tint(AppTheme.accent).foregroundStyle(AppTheme.background)
                        }
                    }
                    let expiring = (s.clubs.first { $0.id == s.selectedClub }?.players ?? []).filter { ($0.contractEndDate ?? Int.max) <= s.year + 1 }
                    if !expiring.isEmpty {
                        card("Contract renewals") {
                            Text("\(expiring.count) player(s) have contracts expiring within 12 months.").foregroundStyle(.secondary)
                            ForEach(expiring) { player in
                                PlayerNameLink(id: player.id, name: player.name, career: s, player: player, teamName: "Contract until \(player.contractEndDate ?? s.year)")
                                    .foregroundStyle(.orange)
                            }
                            Button("Review in Squad") { store.screen = "Squad" }.buttonStyle(.borderedProminent).tint(AppTheme.accent).foregroundStyle(AppTheme.background)
                        }
                    }
                    card("Manager's notebook") {
                        Text("Build your starting XI, choose your approach, and play through a home-and-away league season.").foregroundStyle(.secondary)
                        Label("\(s.lineup.count) / 11 starters selected", systemImage: "person.crop.rectangle.stack").foregroundStyle(s.lineup.count == 11 ? AppTheme.accent : .orange)
                        Text("Player roles are assigned because the source schema has no position field. Ratings use physical attributes on an assumed 1–20 scale.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                card("Tactical board · 4–4–2") {
                    pitch(s)
                    Picker("Approach", selection: Binding(get: { store.season?.tactic ?? "Balanced" }, set: { store.season?.tactic = $0; store.save() })) {
                        Text("Defensive").tag("Defensive"); Text("Balanced").tag("Balanced"); Text("Attacking").tag("Attacking")
                    }.pickerStyle(.segmented)
                    Text("Attacking raises chances at both ends. Defensive reduces them. Your selected XI determines team strength.").font(.caption).foregroundStyle(.secondary)
                }.frame(width: 340)
            }
        }
    }

    func metric(_ title: String, _ value: String, _ note: String) -> some View {
        card(title) { Text(value).font(.system(size: 42, weight: .semibold, design: .rounded)).foregroundStyle(AppTheme.accent); Text(note).font(.caption).foregroundStyle(.secondary) }
    }

    func crest(_ name: String) -> some View {
        VStack(spacing: 14) {
            Group {
                if let logo = CSVTeam.logo(for: name), let url = URL(string: logo) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit()
                        default:
                            Image(systemName: "shield.lefthalf.filled").font(.system(size: 48)).foregroundStyle(AppTheme.accent)
                        }
                    }
                } else {
                    Image(systemName: "shield.lefthalf.filled").font(.system(size: 48)).foregroundStyle(AppTheme.accent)
                }
            }.frame(width: 48, height: 48)
            Text(name).font(.headline).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity)
    }

    func pitch(_ s: Season) -> some View {
        let players = s.clubs.first { $0.id == s.selectedClub }?.players.filter { s.lineup.contains($0.id) }.sorted { a,b in
            let order = ["GK":0,"DEF":1,"MID":2,"FWD":3]; return (order[a.role] ?? 4, a.id) < (order[b.role] ?? 4,b.id)
        } ?? []
        return ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.08, green: 0.22, blue: 0.18))
            Rectangle().stroke(.white.opacity(0.2), lineWidth: 1).padding(14)
            Circle().stroke(.white.opacity(0.15), lineWidth: 1).frame(width: 75,height: 75)
            Rectangle().fill(.white.opacity(0.15)).frame(height: 1)
            VStack(spacing: 24) {
                ForEach([Array(9..<11),Array(5..<9),Array(1..<5),[0]], id: \.self) { indices in
                    HStack(spacing: 8) {
                        ForEach(indices, id: \.self) { i in
                            VStack(spacing: 4) {
                                Text(i < players.count ? "\(players[i].rating)" : "–").font(.caption.bold()).foregroundStyle(AppTheme.background).frame(width: 29, height: 29).background(AppTheme.accent, in: Circle())
                                if i < players.count {
                                    PlayerNameLink(id: players[i].id, name: players[i].name, career: s, label: String(players[i].name.split(separator: " ").last ?? "")).font(.system(size: 9)).lineLimit(1)
                                } else { Text("Empty").font(.system(size: 9)) }
                            }.frame(maxWidth: .infinity)
                        }
                    }
                }
            }.padding(22)
        }.frame(height: 300)
    }

}
