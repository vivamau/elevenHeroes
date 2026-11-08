import SwiftUI

struct MatchFinance {
    let income: Int?
    let wages: Int?
    var net: Int? {
        guard let income, let wages else { return nil }
        return income - wages
    }
    init(fixture: Fixture, clubID: Int) {
        income = fixture.home == clubID ? fixture.ticketRevenue : 0
        wages = fixture.home == clubID ? fixture.homeWages : fixture.awayWages
    }
}

struct LatestMatchReportView: View {
    let season: Season
    private var fixture: Fixture? {
        season.fixtures.first { $0.round == season.round - 1 && $0.homeGoals != nil && ($0.home == season.selectedClub || $0.away == season.selectedClub) }
    }
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 24) {
                events.frame(minWidth: 340, maxWidth: .infinity, alignment: .leading)
                finances.frame(width: 280)
            }
            VStack(alignment: .leading, spacing: 20) { events; finances }
        }
    }
    private var events: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(season.commentary.filter { !$0.hasPrefix("Weekly wages ·") }.enumerated()), id: \.offset) { _, line in
                PlayerLinkedText(text: line, career: season)
                    .font(line.hasPrefix("Full") ? .system(size: 22, weight: .bold, design: .rounded) : line.hasPrefix("    assist") ? .system(size: 12) : .system(size: 14))
                    .foregroundStyle(line.hasPrefix("Full") ? AppTheme.accent : line.hasPrefix("    assist") ? .secondary : .primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    private var finances: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Match finances", systemImage: "creditcard").font(.subheadline.weight(.semibold))
            if let fixture {
                let finance = MatchFinance(fixture: fixture, clubID: season.selectedClub)
                Text("Matchweek \(fixture.round) · \(fixture.home == season.selectedClub ? "Home" : "Away")")
                    .font(.caption).foregroundStyle(.secondary)
                financeRow("Stadium income", value: finance.income, prefix: "+")
                financeRow("Full-squad wages", value: finance.wages, prefix: "−")
                Divider()
                financeRow("Match net", value: finance.net, prefix: (finance.net ?? 0) >= 0 ? "+" : "", emphasized: true)
                if fixture.home != season.selectedClub {
                    Text("Ticket income goes to the home club.").font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("No match this week. No income or wages were recorded.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("Current balance").font(.caption).foregroundStyle(.secondary)
                Text("\(season.credits.formatted()) credits")
                    .font(.system(.title2, design: .rounded).weight(.semibold)).monospacedDigit()
                    .foregroundStyle(season.credits < 0 ? Color.orange : AppTheme.accent)
            }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 12))
    }
    private func financeRow(_ title: String, value: Int?, prefix: String, emphasized: Bool = false) -> some View {
        HStack {
            Text(title).foregroundStyle(emphasized ? .primary : .secondary)
            Spacer(minLength: 12)
            Text(value.map { "\(prefix)\($0.formatted()) cr" } ?? "Not recorded")
                .fontWeight(emphasized ? .semibold : .medium).monospacedDigit()
        }.font(.callout).accessibilityElement(children: .combine)
    }
}

struct FixtureFinanceView: View {
    let fixture: Fixture
    var body: some View {
        if fixture.homeGoals != nil {
            HStack(spacing: 20) {
                metric("Home income", fixture.ticketRevenue)
                metric("Home wages", fixture.homeWages)
                metric("Away wages", fixture.awayWages)
            }.font(.caption).padding(.vertical, 8).frame(maxWidth: .infinity)
                .background(AppTheme.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        }
    }
    private func metric(_ label: String, _ value: Int?) -> some View {
        VStack(spacing: 3) {
            Text(label).foregroundStyle(.secondary)
            Text(value.map { "\($0.formatted()) cr" } ?? "Not recorded").monospacedDigit().fontWeight(.medium)
        }.frame(maxWidth: .infinity).accessibilityElement(children: .combine)
    }
}
