import SwiftUI
import Charts

/// Value is the first statistic; additional trends can be added as separate sections here.
struct PlayerStatsView: View {
    let player: Footballer
    var career: Season? = nil
    @State private var metric = "Goals"
    @State private var selectedIndex: Int?
    @State private var showingHistory = false

    private var records: [PlayerValueRecord] { player.valueHistory ?? [] }
    private var selected: PlayerValueRecord? {
        guard let selectedIndex, records.indices.contains(selectedIndex) else { return records.last }
        return records[selectedIndex]
    }

    var body: some View {
        VStack(spacing: 8) {
            Picker("Player statistics", selection: $metric) {
                Text("Goals").tag("Goals")
                Text("Assists").tag("Assists")
                Text("Value").tag("Value")
            }.pickerStyle(.segmented)
            if metric == "Value" { valuePanel }
            else { PlayerSeasonTrendView(totals: career?.playerSeasonTotals(player.id) ?? [], assists: metric == "Assists") }
        }
    }

    private var valuePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionCaption("Stats · Value")
                Spacer()
                Button("History…") { showingHistory = true }.buttonStyle(.plain).font(.caption).foregroundStyle(AppTheme.accent).disabled(records.isEmpty)
            }
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Player value").font(.subheadline.weight(.medium))
                }
                Spacer()
                Text("\(records.last?.credits ?? player.creditsValue) credits").font(.title2.weight(.semibold)).monospacedDigit().foregroundStyle(AppTheme.accent)
            }
            if records.isEmpty {
                Label("No value history saved yet", systemImage: "chart.xyaxis.line").font(.headline)
                Text("This save does not contain past valuations. Future transfers will record the player's value and team here.")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                Chart {
                    ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                        if records.count > 1 {
                            LineMark(x: .value("Record", index), y: .value("Credits", record.credits))
                                .foregroundStyle(AppTheme.accent).lineStyle(StrokeStyle(lineWidth: 2))
                        }
                        PointMark(x: .value("Record", index), y: .value("Credits", record.credits))
                            .foregroundStyle(AppTheme.accent).symbolSize(selectedIndex == index ? 90 : 40)
                            .accessibilityLabel("\(record.dateLabel), \(record.teamLabel)")
                            .accessibilityValue("\(record.credits) credits")
                    }
                    if let selectedIndex, records.indices.contains(selectedIndex) {
                        RuleMark(x: .value("Record", selectedIndex)).foregroundStyle(.secondary.opacity(0.4))
                    }
                }
                .chartXScale(domain: records.count == 1 ? -1...1 : 0...(records.count - 1))
                .chartYScale(domain: 0...max(100, (records.map(\.credits).max() ?? 100)))
                .chartYAxisLabel("Credits")
                .chartXAxis {
                    AxisMarks(values: axisIndices) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let index = value.as(Int.self), records.indices.contains(index) {
                                Text(records[index].dateLabel).font(.caption2)
                            }
                        }
                    }
                }
                .chartXSelection(value: $selectedIndex)
                .frame(height: 100)
                if let selected {
                    HStack(spacing: 6) {
                        Text(selected.teamLabel).lineLimit(1)
                        Spacer(minLength: 4)
                        Text("\(selected.credits) cr").monospacedDigit()
                    }.font(.caption).foregroundStyle(.secondary).help(recordCaption(selected))
                }

            }
        }.padding(16).frame(maxWidth: .infinity, minHeight: 222, alignment: .topLeading)
            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: AppTheme.panelRadius))
            .sheet(isPresented: $showingHistory) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Value history").font(.title2.weight(.semibold))
                        Spacer()
                        Button("Done") { showingHistory = false }.keyboardShortcut(.cancelAction)
                    }
                    Text(player.name).foregroundStyle(.secondary)
                    Text("Valuations in recording order. Multiple records can share a date.").font(.caption).foregroundStyle(.secondary)
                    historyTable
                    if let selected { Text(recordCaption(selected)).font(.caption).foregroundStyle(.secondary) }
                }.padding(24).frame(width: 560).background(AppTheme.background)
            }
    }

    private var axisIndices: [Int] {
        guard records.count > 1 else { return [0] }
        let step = max(1, (records.count - 1 + 1) / 2)
        return Array(Set(Array(stride(from: 0, to: records.count, by: step)) + [records.count - 1])).sorted()
    }
    private func recordCaption(_ record: PlayerValueRecord) -> String {
        ([record.dateLabel, record.seasonYear.map { "Season \(String($0))" }, record.event] + [record.matchweek.map { "Matchweek \($0)" }]).compactMap { $0 }.joined(separator: " · ")
    }
    private var historyTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Date").frame(width: 135, alignment: .leading)
                Text("Team").frame(maxWidth: .infinity, alignment: .leading)
                Text("Credits").frame(width: 80, alignment: .trailing)
            }.font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.vertical, 10).padding(.horizontal, 12)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(records.enumerated().reversed()), id: \.element.id) { index, record in
                        Button { selectedIndex = index } label: {
                            HStack {
                                Text(record.dateLabel).frame(width: 135, alignment: .leading)
                                Text(record.teamLabel).frame(maxWidth: .infinity, alignment: .leading)
                                Text(record.credits.formatted()).monospacedDigit().frame(width: 80, alignment: .trailing)
                            }.font(.callout).padding(12).contentShape(Rectangle())
                                .background(selectedIndex == index ? AppTheme.accent.opacity(0.09) : .clear)
                        }.buttonStyle(.plain).help(recordCaption(record))
                        Divider().opacity(0.4)
                    }
                }
            }.frame(height: min(220, CGFloat(records.count) * 44))
        }
    }
}
