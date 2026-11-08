import SwiftUI
import Charts

struct SeasonPosition: Identifiable {
    var id: String { "\(clubID)-\(round)" }
    let clubID: Int
    let clubName: String
    let round: Int
    let position: Int
}

extension CompletedSeason {
    func positions(fallbackClubs: [Club]) -> [SeasonPosition] {
        let teams = clubs ?? fallbackClubs
        let rounds = Set(fixtures.filter { $0.homeGoals != nil && $0.awayGoals != nil }.map(\.round)).sorted()
        return rounds.flatMap { round in
            let snapshot = Season(clubs: teams, fixtures: fixtures.filter { $0.round <= round }, selectedClub: -1, demo: false)
            return snapshot.standings.enumerated().map { index, row in
                SeasonPosition(clubID: row.id, clubName: row.club.name, round: round, position: index + 1)
            }
        }
    }
}

struct SeasonPositionsView: View {
    let season: CompletedSeason
    let fallbackClubs: [Club]
    @State private var focusedTeam: Int?
    private var teams: [Club] { (season.clubs ?? fallbackClubs).sorted { $0.name < $1.name } }
    private let palette: [Color] = [.cyan, .orange, .pink, .green, .purple, .yellow, .blue, .mint, .red, .indigo]
    private func color(_ id: Int) -> Color { palette[(teams.firstIndex { $0.id == id } ?? 0) % palette.count] }

    @ChartContentBuilder
    private func marks(_ point: SeasonPosition) -> some ChartContent {
        let visible = focusedTeam == nil || focusedTeam == point.clubID
        let tint = color(point.clubID).opacity(visible ? 1 : 0.12)
                    LineMark(x: .value("Matchweek", point.round), y: .value("Position", point.position), series: .value("Team", String(point.clubID)))
                        .foregroundStyle(tint)
                        .lineStyle(StrokeStyle(lineWidth: focusedTeam == point.clubID ? 3.5 : 2))
                        .interpolationMethod(.linear)
                    PointMark(x: .value("Matchweek", point.round), y: .value("Position", point.position))
                        .foregroundStyle(tint)
                        .symbolSize(focusedTeam == point.clubID ? 40 : 15)
                        .accessibilityLabel("\(point.clubName), matchweek \(point.round)")
                        .accessibilityValue("Position \(point.position)")
    }

    private func positionChart(_ points: [SeasonPosition]) -> some View {
                Chart(points) { point in
                    marks(point)
                }
                .chartLegend(.hidden)
                .chartYScale(domain: .automatic(includesZero: false, reversed: true))
                .chartXScale(domain: 1...max(2, points.map(\.round).max() ?? 1))
                .chartYAxis {
                    AxisMarks(position: .leading, values: Array(1...max(1, teams.count))) { _ in
                        AxisGridLine(); AxisTick(); AxisValueLabel()
                    }
                }
                .chartYAxisLabel("Position")
                .chartXAxisLabel("Matchweek")
                .frame(height: max(280, CGFloat(teams.count) * 22))
    }

    var body: some View {
        let points = season.positions(fallbackClubs: fallbackClubs)
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("League positions").font(.title2.weight(.semibold))
                Spacer()
                if focusedTeam != nil {
                    Button("Show all teams") { focusedTeam = nil }.buttonStyle(.bordered)
                }
            }
            Text("Position after each matchweek · Select a team below to follow its season.")
                .font(.callout).foregroundStyle(.secondary)
            if points.isEmpty {
                ContentUnavailableView("No results recorded", systemImage: "chart.xyaxis.line")
            } else {
                positionChart(points)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), alignment: .leading)], alignment: .leading, spacing: 10) {
                    ForEach(teams) { team in
                        Button { focusedTeam = focusedTeam == team.id ? nil : team.id } label: {
                            HStack(spacing: 8) {
                                Circle().fill(color(team.id)).frame(width: 9, height: 9)
                                Text(team.name).font(.callout).multilineTextAlignment(.leading)
                                if focusedTeam == team.id { Image(systemName: "checkmark").font(.caption.bold()) }
                            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                                .background(focusedTeam == team.id ? Color.primary.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 8))
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityAddTraits(focusedTeam == team.id ? .isSelected : [])
                    }
                }
            }
        }.padding(22).background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 14))
            .onChange(of: season.year) { _, _ in focusedTeam = nil }
    }
}
