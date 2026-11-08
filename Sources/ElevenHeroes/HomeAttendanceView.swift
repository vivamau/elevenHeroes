import SwiftUI

struct HomeAttendanceView: View {
    let season: Season
    private var homeMatches: [Fixture] {
        season.fixtures.filter { $0.home == season.selectedClub && $0.homeGoals != nil }
            .sorted { $0.round < $1.round }
    }
    private var recorded: [Int] { homeMatches.compactMap(\.attendance) }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Label("Last home crowd", systemImage: "person.3").font(.caption).foregroundStyle(.secondary)
                Text(homeMatches.last?.attendance.map { $0.formatted() } ?? "—")
                    .font(.title3.weight(.semibold)).monospacedDigit().foregroundStyle(AppTheme.accent)
                Text(homeMatches.last.map { "Matchweek \($0.round)\($0.attendance == nil ? " · Not recorded" : "")" } ?? "No home matches yet")
                    .font(.caption2).foregroundStyle(.secondary)
                if let revenue = homeMatches.last?.ticketRevenue {
                    Text("+\(revenue.formatted()) credits earned").font(.caption2).foregroundStyle(AppTheme.accent)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 5) {
                Text("Home average · \(season.homeTicketPrice) cr / ticket").font(.caption).foregroundStyle(.secondary)
                Text(recorded.isEmpty ? "—" : (recorded.reduce(0, +) / recorded.count).formatted())
                    .font(.title3.weight(.semibold)).monospacedDigit()
                Text("\(recorded.count) recorded home matches").font(.caption2).foregroundStyle(.secondary)
                if let club = season.clubs.first(where: { $0.id == season.selectedClub }) {
                    Text("Weekly wages · \(club.weeklyWages.formatted()) cr").font(.caption2).foregroundStyle(.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .trailing)
        }.accessibilityElement(children: .combine)
    }
}
