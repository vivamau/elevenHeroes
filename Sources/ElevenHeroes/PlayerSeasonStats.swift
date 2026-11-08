import SwiftUI
import Charts

struct PlayerSeasonTotal: Identifiable {
    var id: Int { year }
    let year: Int
    let goals: Int
    let assists: Int
    let complete: Bool
    let current: Bool
}

extension Season {
    func playerSeasonTotals(_ playerID: Int) -> [PlayerSeasonTotal] {
        func total(_ year: Int, _ fixtures: [Fixture], current: Bool) -> PlayerSeasonTotal {
            let played = fixtures.filter { $0.homeGoals != nil && $0.awayGoals != nil }
            let events = played.flatMap { $0.goalEvents ?? [] }
            return PlayerSeasonTotal(year: year, goals: events.filter { $0.scorerID == playerID }.count,
                                     assists: events.filter { $0.assistID == playerID }.count,
                                     complete: played.allSatisfy { $0.goalEvents != nil }, current: current)
        }
        return ((completedSeasons ?? []).map { total($0.year, $0.fixtures, current: false) }
                + [total(year, fixtures, current: true)]).sorted { $0.year < $1.year }
    }
}

struct PlayerSeasonTrendView: View {
    let totals: [PlayerSeasonTotal]
    let assists: Bool
    @State private var selectedYear: Int?
    private var selected: PlayerSeasonTotal? { totals.first { $0.year == selectedYear } ?? totals.last }
    private func value(_ total: PlayerSeasonTotal) -> Int { assists ? total.assists : total.goals }
    private var title: String { assists ? "Assists" : "Goals" }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("League season totals").font(.subheadline.weight(.medium))
                Spacer()
                if let selected {
                    Text(selected.complete ? "\(value(selected)) \(title.lowercased())" : "\(value(selected)) recorded")
                        .font(.title2.weight(.semibold)).monospacedDigit().foregroundStyle(AppTheme.accent)
                }
            }
            if totals.isEmpty {
                Text("Open a player in your career to see seasonal goals and assists.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                Chart(totals) { total in
                    BarMark(x: .value("Season", total.year), y: .value(title, value(total)), width: .fixed(18))
                        .foregroundStyle(total.complete ? AppTheme.accent : Color.secondary)
                        .opacity(selectedYear == nil || selectedYear == total.year ? 1 : 0.4)
                        .accessibilityLabel("Season \(String(total.year))\(total.current ? ", current" : "")")
                        .accessibilityValue("\(value(total)) \(title.lowercased())\(total.complete ? "" : ", incomplete records")")
                }
                .chartXScale(domain: Double(totals.first!.year) - 0.5...Double(totals.last!.year) + 0.5)
                .chartYScale(domain: 0...max(1, totals.map { value($0) }.max() ?? 1))
                .chartXAxis {
                    AxisMarks(values: totals.map(\.year)) { axis in
                        AxisValueLabel { if let year = axis.as(Int.self) { Text(String(year)) } }
                    }
                }
                .chartXSelection(value: $selectedYear)
                .frame(height: 100)
                if let selected {
                    Text("\(String(selected.year))\(selected.current ? " · Current season" : " · Final total")\(selected.complete ? "" : " · Incomplete records")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("Select a season to view its total.").font(.caption2).foregroundStyle(.secondary)
            }
        }.padding(16).frame(maxWidth: .infinity, minHeight: 222, alignment: .topLeading)
            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: AppTheme.panelRadius))
            .onChange(of: assists) { _, _ in selectedYear = nil }
    }
}
