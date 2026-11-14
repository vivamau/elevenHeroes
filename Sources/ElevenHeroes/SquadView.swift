import SwiftUI

extension ContentView {
    func squad(_ s: Season) -> some View {
        let players = s.clubs.first { $0.id == s.selectedClub }?.players ?? []
        let expiring = Set(players.filter { ($0.contractEndDate ?? Int.max) <= s.year + 1 }.map(\.id))
        return VStack(spacing: 18) {
        VStack(alignment: .leading, spacing: 20) {
            SectionCaption("First team · \(s.lineup.count)/11 selected")
            HStack { Text("Deselect a starter to make room for a substitute.").foregroundStyle(.secondary); Spacer(); Button("Pick best XI", action: store.autoPick).gamePrimaryAction() }
            SquadTableView(players: players, lineup: s.lineup, substitutes: s.substitutes, onToggle: store.toggle, expiringContractIDs: expiring) { viewedPlayer = $0 }
            if !expiring.isEmpty {
                Label("\(expiring.count) players have contracts expiring within 12 months.", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading).gameSurface()
        DisclosureGroup("Club finances and attendance") {
            VStack(spacing: 16) {
                StadiumCrowdTrendView(season: s, clubID: s.selectedClub)
                FinanceTrendView(season: s, clubID: s.selectedClub)
            }.padding(.top, 12)
        }.padding(24).gameSurface()
    }
    }

}
