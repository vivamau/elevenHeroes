import SwiftUI

struct ChampionshipDetailView: View {
    let championship: DatabaseRecord
    let teams: [Club]
    let country: String
    var backLabel = "Back to leagues"
    let onBack: () -> Void
    @State private var selectedTeam: Club?

    var body: some View {
        if let team = selectedTeam {
            TeamDetailView(club: team, context: championship.title, backLabel: "Back to league") { selectedTeam = nil }
        } else {
            VStack(alignment: .leading, spacing: 24) {
                Button(action: onBack) { Label(backLabel, systemImage: "chevron.left") }
                    .buttonStyle(.plain).foregroundStyle(AppTheme.accent)
                HStack(spacing: 18) {
                    Image(systemName: "trophy.fill").font(.system(size: 36)).foregroundStyle(AppTheme.accent)
                        .frame(width: 76, height: 76).background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 16))
                    VStack(alignment: .leading, spacing: 8) {
                        Text(championship.title).font(.system(size: 30, weight: .bold, design: .rounded))
                        if !country.isEmpty { Text(country).foregroundStyle(.secondary) }
                        Text("\(teams.count) assigned teams · \(championship.values["championship_teams_number"] ?? "—") configured")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }
                if teams.isEmpty {
                    ContentUnavailableView("No teams assigned", systemImage: "shield", description: Text("Open Teams and edit a team to assign it to this league."))
                } else {
                    VStack(spacing: 0) {
                        ForEach(teams) { team in
                            Button { selectedTeam = team } label: {
                                HStack(spacing: 16) {
                                    Image(systemName: "shield.lefthalf.filled").foregroundStyle(AppTheme.accent)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(team.name).fontWeight(.semibold).foregroundStyle(AppTheme.accent)
                                        if !team.city.isEmpty { Text(team.city).font(.caption).foregroundStyle(.secondary) }
                                    }
                                    Spacer()
                                    Text("\(team.players.count) players").foregroundStyle(.secondary)
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                                }.padding(16).contentShape(Rectangle())
                            }.buttonStyle(.plain).help("View \(team.name)")
                            Divider()
                        }
                    }.background(AppTheme.panel, in: RoundedRectangle(cornerRadius: AppTheme.panelRadius))
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
