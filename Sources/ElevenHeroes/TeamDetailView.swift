import SwiftUI

struct TeamDetailView: View {
    let club: Club
    var career: Season? = nil
    var context = ""
    var backLabel = "Back"
    let onBack: () -> Void
    @State private var selectedPlayer: Footballer?

    var body: some View {
        if let player = selectedPlayer {
            PlayerDetailView(player: player, career: career, teamName: club.name, backLabel: "Back to team", onTeam: { selectedPlayer = nil }) { selectedPlayer = nil }
        } else {
        VStack(alignment: .leading, spacing: 24) {
            Button(action: onBack) { Label(backLabel, systemImage: "chevron.left") }
                .buttonStyle(.plain).foregroundStyle(AppTheme.accent)
            HStack(spacing: 18) {
                Group {
                    if let logo = CSVTeam.logo(for: club.name), let url = URL(string: logo) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFit()
                            default:
                                Image(systemName: "shield.lefthalf.filled")
                                    .font(.system(size: 42)).foregroundStyle(AppTheme.accent)
                            }
                        }
                    } else {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 42)).foregroundStyle(AppTheme.accent)
                    }
                }
                .frame(width: 76, height: 76)
                .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 8) {
                    Text(club.name).font(.system(size: 30, weight: .bold, design: .rounded))
                    if !club.city.isEmpty { Label(club.city, systemImage: "mappin.and.ellipse").foregroundStyle(.secondary) }
                    if !context.isEmpty { Text(context).font(.callout).foregroundStyle(.secondary) }
                }
            }
            HStack {
                Label("\(club.players.count) players", systemImage: "person.3")
                Spacer()
                if !club.players.isEmpty { Text("\(Int(club.strength)) OVR").bold().foregroundStyle(AppTheme.accent) }
            }
            if let career {
                StadiumCrowdTrendView(season: career, clubID: club.id)
                FinanceTrendView(season: career, clubID: club.id)
            }
            if club.players.isEmpty {
                ContentUnavailableView("No players assigned", systemImage: "person.3", description: Text("Assign players to this team in the database manager."))
            } else {
                let expiring = Set(club.players.filter { ($0.contractEndDate ?? Int.max) <= (career?.year ?? 2026) + 1 }.map(\.id))
                SquadTableView(players: club.players, expiringContractIDs: expiring) { selectedPlayer = $0 }
                Text("Overall ratings use physical attributes. Players without recorded positions use provisional roles.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
