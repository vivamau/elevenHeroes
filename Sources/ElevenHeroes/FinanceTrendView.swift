import SwiftUI
import Charts

struct FinanceTrendView: View {
    let season: Season
    let clubID: Int
    @State private var metric: Metric = .all
    @State private var selectedRound: Int?

    enum Metric: String, CaseIterable, Identifiable {
        case all = "All"
        case total = "Total"
        case income = "Stadium income"
        case wages = "Wages"
        var id: String { rawValue }
    }

    private struct Point: Identifiable {
        let id: Int
        let round: Int
        let income: Int?
        let wages: Int?
        var net: Int? {
            guard let wages else { return nil }
            return (income ?? 0) - wages
        }
    }

    private var points: [Point] {
        season.fixtures
            .filter { ($0.home == clubID || $0.away == clubID) && $0.homeGoals != nil }
            .sorted { $0.round < $1.round }
            .map { fixture in
                Point(
                    id: fixture.id,
                    round: fixture.round,
                    income: fixture.home == clubID ? fixture.ticketRevenue : 0,
                    wages: fixture.home == clubID ? fixture.homeWages : fixture.awayWages
                )
            }
    }

    private var selected: Point? {
        guard let selectedRound else { return points.last }
        return points.min { abs($0.round - selectedRound) < abs($1.round - selectedRound) }
    }

    private var missingFinance: Bool {
        points.contains { $0.income == nil && $0.wages == nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Finance trend").font(.headline)
                    Text("Season \(season.yearLabel) · Income, wages and net").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Picker("View", selection: $metric) {
                    ForEach(Metric.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).frame(maxWidth: 300)
            }
            if points.isEmpty {
                Label("Play a match to start your finance trend.", systemImage: "creditcard")
                    .font(.callout).foregroundStyle(.secondary).padding(.vertical, 12)
            } else {
                financeChart
                HStack {
                    if let selected {
                        Text("Matchweek \(selected.round)")
                        if let value = selectedValue(selected) {
                            Text("· \(value >= 0 ? "+" : "")\(value.formatted()) cr")
                                .foregroundStyle(value >= 0 ? AppTheme.accent : .orange)
                        }
                    }
                    Spacer()
                    if let average = averageValue {
                        Text("Average \(average >= 0 ? "+" : "")\(average.formatted())")
                            .monospacedDigit()
                    }
                }.font(.caption).foregroundStyle(.secondary).monospacedDigit()
                if missingFinance {
                    Text("Only recorded finance values are shown.").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }.padding(18).background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 14))
            .onChange(of: season.year) { _, _ in selectedRound = nil }
            .onChange(of: clubID) { _, _ in selectedRound = nil }
    }

    private func selectedValue(_ point: Point) -> Int? {
        switch metric {
        case .total: return point.net
        case .income: return point.income
        case .wages: return point.wages
        case .all: return point.net
        }
    }

    private var averageValue: Int? {
        let values = points.compactMap { selectedValue($0) }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / values.count
    }

    private var financeChart: some View {
        Chart {
            if metric == .all {
                ForEach(points) { point in
                    if let value = point.income {
                        LineMark(x: .value("Matchweek", point.round), y: .value("Credits", value), series: .value("Series", "Stadium income"))
                            .foregroundStyle(.green).lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.linear)
                    }
                    if let value = point.wages {
                        LineMark(x: .value("Matchweek", point.round), y: .value("Credits", value), series: .value("Series", "Wages"))
                            .foregroundStyle(.orange).lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.linear)
                    }
                    if let value = point.net {
                        LineMark(x: .value("Matchweek", point.round), y: .value("Credits", value), series: .value("Series", "Net"))
                            .foregroundStyle(AppTheme.accent).lineStyle(StrokeStyle(lineWidth: 2.5))
                            .interpolationMethod(.linear)
                    }
                }
            } else {
                ForEach(points) { point in
                    if let value = selectedValue(point) {
                        LineMark(x: .value("Matchweek", point.round), y: .value("Credits", value))
                            .foregroundStyle(seriesColor).lineStyle(StrokeStyle(lineWidth: 2.5))
                            .interpolationMethod(.linear)
                        PointMark(x: .value("Matchweek", point.round), y: .value("Credits", value))
                            .foregroundStyle(seriesColor).symbolSize(selected?.id == point.id ? 55 : 25)
                    }
                }
            }
        }
        .chartXScale(domain: max(0, (points.first?.round ?? 1) - 1)...((points.last?.round ?? 1) + 1))
        .chartXAxis {
            AxisMarks(values: points.map(\.round)) { value in
                AxisTick()
                AxisValueLabel { if let round = value.as(Int.self) { Text("\(round)") } }
            }
        }
        .chartXAxisLabel("Matchweek")
        .chartXSelection(value: $selectedRound)
        .chartLegend(metric == .all ? .visible : .hidden)
        .frame(height: 150)
    }

    private var seriesColor: Color {
        switch metric {
        case .total: return AppTheme.accent
        case .income: return .green
        case .wages: return .orange
        case .all: return AppTheme.accent
        }
    }
}