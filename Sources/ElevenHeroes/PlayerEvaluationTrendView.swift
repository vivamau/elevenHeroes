import SwiftUI
import Charts

struct PlayerEvaluationTrendView: View {
    let playerID: Int
    let season: Season?
    @State private var selectedRound: Int?

    private var seasonValue: Season? { season }

    private var matches: [Fixture] {
        guard let season = seasonValue else { return [] }
        return season.fixtures.filter { fixture in
            fixture.homeGoals != nil && (
                (fixture.homeLineup ?? []).contains(playerID) ||
                (fixture.homeSubstitutes ?? []).contains(playerID) ||
                (fixture.awayLineup ?? []).contains(playerID) ||
                (fixture.awaySubstitutes ?? []).contains(playerID)
            )
        }.sorted { $0.round < $1.round }
    }

    private var points: [RatingPoint] {
        matches.map { RatingPoint(round: $0.round, rating: evaluation(for: $0)) }
    }

    private var selected: Fixture? {
        guard let selectedRound else { return matches.last }
        return matches.min { abs($0.round - selectedRound) < abs($1.round - selectedRound) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Match evaluation").font(.headline)
                    if let season = seasonValue {
                        Text("Season \(season.yearLabel) · Player trend").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let selected {
                    Text("\(evaluation(for: selected))").font(.title3.weight(.semibold)).monospacedDigit().foregroundStyle(AppTheme.accent)
                    Text("/10").font(.caption).foregroundStyle(.secondary)
                }
            }
            if matches.isEmpty {
                Label("Play a match to start the evaluation trend.", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.callout).foregroundStyle(.secondary).padding(.vertical, 12)
            } else {
                evaluationChart
                HStack {
                    if let selected {
                        Text("Matchweek \(selected.round)")
                        Text("· \(evaluation(for: selected))/10")
                    }
                    Spacer()
                    if !points.isEmpty {
                        Text("Average \(points.map(\.rating).reduce(0, +) / points.count)")
                    }
                }.font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
        }.padding(18).background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 14))
            .onChange(of: seasonValue?.year) { _, _ in selectedRound = nil }
    }

    private var evaluationChart: some View {
        Chart(points) { point in
            LineMark(x: .value("Matchweek", point.round), y: .value("Rating", point.rating))
                .foregroundStyle(AppTheme.accent).lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.linear)
            PointMark(x: .value("Matchweek", point.round), y: .value("Rating", point.rating))
                .foregroundStyle(AppTheme.accent).symbolSize(selected?.round == point.round ? 55 : 25)
        }
        .chartXScale(domain: max(0, (points.first?.round ?? 1) - 1)...((points.last?.round ?? 1) + 1))
        .chartYScale(domain: 1...10)
        .chartXAxis {
            AxisMarks(values: points.map(\.round)) { value in
                AxisTick()
                AxisValueLabel { if let round = value.as(Int.self) { Text("\(round)") } }
            }
        }
        .chartXAxisLabel("Matchweek")
        .chartXSelection(value: $selectedRound)
        .frame(height: 120)
    }

    private func isHome(_ fixture: Fixture) -> Bool {
        (fixture.homeLineup ?? []).contains(playerID) || (fixture.homeSubstitutes ?? []).contains(playerID)
    }

    private func evaluation(for fixture: Fixture) -> Int {
        let home = isHome(fixture)
        let clubID = home ? fixture.home : fixture.away
        let passes = home ? (fixture.homePasses?[playerID] ?? 0) : (fixture.awayPasses?[playerID] ?? 0)
        let goals = (fixture.goalEvents ?? []).filter { $0.clubID == clubID && $0.scorerID == playerID }.count
        let assists = (fixture.goalEvents ?? []).filter { $0.clubID == clubID && $0.assistID == playerID }.count
        var score = 5.0
        score += Double(goals) * 1.5
        score += Double(assists) * 1.0
        score += Double(passes) / 20.0
        return min(10, max(1, Int(score.rounded())))
    }

    private struct RatingPoint: Identifiable {
        let id = UUID()
        let round: Int
        let rating: Int
    }
}
