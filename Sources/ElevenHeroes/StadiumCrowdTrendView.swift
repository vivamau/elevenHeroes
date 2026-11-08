import SwiftUI
import Charts

struct StadiumCrowdTrendView: View {
    let season: Season
    let clubID: Int
    @State private var selectedRound: Int?
    private var matches: [Fixture] {
        season.fixtures.filter { $0.home == clubID && $0.homeGoals != nil && $0.attendance != nil }.sorted { $0.round < $1.round }
    }
    private var selected: Fixture? {
        guard let selectedRound else { return matches.last }
        return matches.min { abs($0.round - selectedRound) < abs($1.round - selectedRound) }
    }
    private var missingRecords: Bool {
        season.fixtures.contains { $0.home == clubID && $0.homeGoals != nil && $0.attendance == nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stadium crowd").font(.headline)
                    Text("Season \(season.yearLabel) · Home matches").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let selected, let attendance = selected.attendance {
                    Text("\(attendance.formatted()) fans").font(.title3.weight(.semibold)).monospacedDigit().foregroundStyle(AppTheme.accent)
                }
            }
            if matches.isEmpty {
                Label(missingRecords ? "Attendance wasn’t recorded for these matches." : "Play a home match to start your crowd trend.", systemImage: "person.3")
                    .font(.callout).foregroundStyle(.secondary).padding(.vertical, 12)
            } else {
                crowdChart
                HStack {
                    if let selected {
                        Text("Matchweek \(selected.round)")
                        if let capacity = selected.stadiumCapacity, capacity > 0, let attendance = selected.attendance {
                            Text("· \(Int((Double(attendance) / Double(capacity) * 100).rounded()))% full")
                        }
                    }
                    Spacer()
                    Text("Average \((matches.compactMap(\.attendance).reduce(0, +) / matches.count).formatted())")
                }.font(.caption).foregroundStyle(.secondary).monospacedDigit()
                if missingRecords {
                    Text("Only recorded home crowds are shown.").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }.padding(18).background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 14))
            .onChange(of: season.year) { _, _ in selectedRound = nil }
            .onChange(of: clubID) { _, _ in selectedRound = nil }
    }

    private var crowdChart: some View {
        Chart(matches) { fixture in
            LineMark(x: .value("Matchweek", fixture.round), y: .value("Fans", fixture.attendance ?? 0))
                .foregroundStyle(AppTheme.accent).lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.linear)
            PointMark(x: .value("Matchweek", fixture.round), y: .value("Fans", fixture.attendance ?? 0))
                .foregroundStyle(AppTheme.accent).symbolSize(selected?.id == fixture.id ? 55 : 25)
                .accessibilityLabel("Matchweek \(fixture.round)")
                .accessibilityValue("\((fixture.attendance ?? 0).formatted()) fans")
        }
        .chartXScale(domain: max(0, (matches.first?.round ?? 1) - 1)...((matches.last?.round ?? 1) + 1))
        .chartYScale(domain: 0...max(1, matches.compactMap(\.attendance).max() ?? 1))
        .chartXAxis {
            AxisMarks(values: matches.map(\.round)) { value in
                AxisTick()
                AxisValueLabel { if let round = value.as(Int.self) { Text("\(round)") } }
            }
        }
        .chartXAxisLabel("Matchweek")
        .chartXSelection(value: $selectedRound)
        .frame(height: 120)
    }
}
