import SwiftUI

extension ContentView {
    func squad(_ s: Season) -> some View {
        VStack(spacing: 18) {
        StadiumCrowdTrendView(season: s, clubID: s.selectedClub)
        FinanceTrendView(season: s, clubID: s.selectedClub)
        VStack(alignment: .leading, spacing: 20) {
            Text("FIRST TEAM · \(s.lineup.count)/11 SELECTED").font(.system(size: 11, weight: .bold)).tracking(1.7).foregroundStyle(.secondary)
            HStack { Text("Deselect a starter to make room for a substitute.").foregroundStyle(.secondary); Spacer(); Button("Pick best XI", action: store.autoPick) }
            let players = s.clubs.first { $0.id == s.selectedClub }?.players ?? []
            SquadTableView(players: players, lineup: s.lineup, substitutes: s.substitutes, onToggle: store.toggle) { viewedPlayer = $0 }
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(AppTheme.panel)
    }
    }

}
