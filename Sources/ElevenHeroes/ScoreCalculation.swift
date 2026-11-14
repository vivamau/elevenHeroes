import SwiftUI

struct ScoreCalculation: Codable {
    struct Team: Codable {
        let base: Double
        let venue: Double
        let strength: Double
        let form: Double
        let strategy: Double
        var raw: Double { base + venue + strength + form + strategy }
        var expected: Double { min(max(raw, 0.2), 4.5) }
    }
    struct SubstitutionImpact: Codable {
        let change: MatchSubstitution
        let outgoingRating: Int
        let incomingRating: Int
        let strengthBefore: Double
        let strengthAfter: Double
        let homeBefore: Team
        let awayBefore: Team
    }
    var substitutionImpact: SubstitutionImpact? = nil

    struct Draw: Codable {
        let home: Bool
        let minute: Int?
        let value: Double
    }
    let afterMinute: Int
    let home: Team
    let away: Team
    let mix: StrategyMix
    let maxGoals: Int
    var draws: [Draw] = []
    var homeGoals = 0
    var awayGoals = 0
}

struct ScoreCalculationView: View {
    let fixture: Fixture
    let homeName: String
    let awayName: String
    @Environment(\.dismiss) private var dismiss

    private func number(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(4))) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Score calculations").font(.title.bold())
            Text("\(homeName) \(fixture.homeGoals ?? 0) – \(fixture.awayGoals ?? 0) \(awayName)").font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Expected goals describe scoring chances, not a rounded prediction. Random draws decide the score.")
                        .foregroundStyle(.secondary)
                    if let stages = fixture.scoreCalculations, !stages.isEmpty {
                        ForEach(stages.indices, id: \.self) { index in
                            let stage = stages[index]
                            VStack(alignment: .leading, spacing: 12) {
                                Text(stage.substitutionImpact != nil ? "Substitution at \(stage.afterMinute)′" : index == 0 ? "Kick-off calculation" : "Match adjustment after \(stage.afterMinute)′").font(.headline)
                                if let impact = stage.substitutionImpact {
                                    Text("\(impact.change.incomingName) (\(impact.incomingRating) OVR) replaces \(impact.change.outgoingName) (\(impact.outgoingRating) OVR)")
                                    Text("Active XI average: \(number(impact.strengthBefore)) → \(number(impact.strengthAfter)) · change \(number(impact.strengthAfter - impact.strengthBefore))")
                                        .font(.callout).monospacedDigit()
                                    Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                                        GridRow { Text("Substitution effect"); Text(homeName); Text(awayName) }.fontWeight(.semibold)
                                        row("Strength contribution before", impact.homeBefore.strength, impact.awayBefore.strength)
                                        row("Strength contribution after", stage.home.strength, stage.away.strength)
                                        row("Expected goals before", impact.homeBefore.expected, impact.awayBefore.expected)
                                        row("Expected goals after", stage.home.expected, stage.away.expected)
                                        row("Expected-goal change", stage.home.expected - impact.homeBefore.expected, stage.away.expected - impact.awayBefore.expected)
                                        row("Goal probability per minute before (%)", 100 * (1 - exp(-impact.homeBefore.expected / 90)), 100 * (1 - exp(-impact.awayBefore.expected / 90)))
                                        row("Goal probability per minute after (%)", 100 * (1 - exp(-stage.home.expected / 90)), 100 * (1 - exp(-stage.away.expected / 90)))
                                    }.font(.callout)
                                    Text("These rates apply only after the substitution. Earlier goals are retained. Expected goals are full-match rates; the remaining minutes determine the number of new scoring opportunities. The 0.2–4.5 clamp can limit the effect.")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Text(StrategyMix.names.map { "\($0): \(stage.mix.value(for: $0).formatted(.number.precision(.fractionLength(2))))" }.joined(separator: " · "))
                                    .font(.caption)
                                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                                    GridRow { Text("Contribution"); Text(homeName); Text(awayName) }.fontWeight(.semibold)
                                    row("Base goals", stage.home.base, stage.away.base)
                                    row("Home advantage (+ / −)", stage.home.venue, stage.away.venue)
                                    row("Strength difference × weight", stage.home.strength, stage.away.strength)
                                    row("Recent form × weight", stage.home.form, stage.away.form)
                                    row("Blended strategy", stage.home.strategy, stage.away.strategy)
                                    row("Sum", stage.home.raw, stage.away.raw)
                                    row("Expected goals (clamped 0.2–4.5)", stage.home.expected, stage.away.expected)
                                }.font(.callout)
                                Text("Goal cap: \(stage.maxGoals) per team · Result after this calculation: \(stage.homeGoals)–\(stage.awayGoals)")
                                    .font(.callout.bold())
                                if index == 0 {
                                    Text("Poisson sampling: multiply uniform random draws until the product ≤ exp(−expected goals), or the goal cap is reached. Goals = min(cap, number of draws − 1). Goal minutes are then assigned randomly.")
                                    Text("Stopping thresholds: home \(number(exp(-stage.home.expected))), away \(number(exp(-stage.away.expected))).")
                                } else {
                                    Text("Goals through minute \(stage.afterMinute) were kept. For each remaining minute, a goal occurs when its random draw is below 1 − exp(−expected goals / 90), until the goal cap is reached. Earlier projections for these minutes were replaced.")
                                    Text("Per-minute probability: home \(number(1 - exp(-stage.home.expected / 90))), away \(number(1 - exp(-stage.away.expected / 90))).")
                                }
                                DisclosureGroup("Recorded random draws (\(stage.draws.count))") {
                                    VStack(alignment: .leading, spacing: 4) {
                                        ForEach(stage.draws.indices, id: \.self) { drawIndex in
                                            let draw = stage.draws[drawIndex]
                                            Text("\(draw.home ? homeName : awayName) · \(draw.minute.map { "\($0)′" } ?? "draw \(drawIndex + 1)") · \(draw.value.formatted(.number.precision(.fractionLength(8))))")
                                                .font(.caption.monospacedDigit())
                                        }
                                    }
                                }
                            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 12))
                        }
                    } else {
                        Text("Calculation details were not recorded for this older match.").foregroundStyle(.secondary)
                    }
                }
            }
            HStack { Spacer(); Button("Close", role: .cancel) { dismiss() }.gamePrimaryAction().keyboardShortcut(.cancelAction) }
        }.padding(24).frame(width: 760, height: AppTheme.sheetHeight(680)).background(AppTheme.panel)
    }

    private func row(_ title: String, _ home: Double, _ away: Double) -> some View {
        GridRow { Text(title); Text(number(home)); Text(number(away)) }.monospacedDigit()
    }
}
