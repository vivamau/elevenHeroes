import Foundation

/// Configurable parameters for match simulation. Future AI agents can tune these
/// or supply their own profile to experiment with different game models.
struct TacticProfile: Codable {
    var attack: Double
    var defense: Double
}

struct MatchSimulationParameters: Codable {
    var homeAdvantage: Double = 0.30
    var baseHomeGoals: Double = 1.25
    var baseAwayGoals: Double = 1.00
    var powerWeight: Double = 0.10
    var formWeight: Double = 0.20
    var maxGoals: Int = 10
    var mix: StrategyMix? = nil
    var tactics: [String: TacticProfile] = [
        "Attacking": TacticProfile(attack: 0.22, defense: -0.12),
        "Balanced": TacticProfile(attack: 0.00, defense: 0.00),
        "Defensive": TacticProfile(attack: -0.18, defense: 0.20)
    ]

    static let `default` = MatchSimulationParameters()
}

/// Context needed to simulate a single fixture.
struct MatchSimulationContext {
    let home: Club
    let away: Club
    let selectedClub: Int
    let lineup: [Int]
    let tactic: String
    let round: Int
    let fixtures: [Fixture]
    let year: Int

    var isHomeSelected: Bool { home.id == selectedClub }
    var isAwaySelected: Bool { away.id == selectedClub }
}

/// Deterministic, parametrizable match simulator. All randomness flows through the
/// supplied generator so simulations remain reproducible and testable.
struct MatchSimulator {
    var parameters: MatchSimulationParameters = .default

    /// Goalkeepers share a 0.01% chance per goal, regardless of how many are selected.
    /// Outfield players retain equal chances among themselves.
    func scorer<R: RandomNumberGenerator>(from squad: [Footballer], rng: inout R) -> Footballer? {
        let outfield = squad.filter { $0.role != "GK" }
        let goalkeepers = squad.filter { $0.role == "GK" }
        // Keep unusual goalkeeper-only lineups and empty squads safe.
        guard !outfield.isEmpty else { return goalkeepers.randomElement(using: &rng) }
        if !goalkeepers.isEmpty, Int.random(in: 0..<10_000, using: &rng) == 0 {
            return goalkeepers.randomElement(using: &rng)
        }
        return outfield.randomElement(using: &rng)
    }

    func power(for club: Club, lineup: [Int], selected: Bool) -> Double {
        if selected, !lineup.isEmpty {
            let ratings = lineup.compactMap { id in club.players.first { $0.id == id }?.rating }
            if !ratings.isEmpty {
                return Double(ratings.reduce(0, +)) / Double(ratings.count)
            }
        }
        return club.strength
    }

    func formScore(clubID: Int, fixtures: [Fixture]) -> Double {
        let recent = fixtures
            .filter { $0.homeGoals != nil && ($0.home == clubID || $0.away == clubID) }
            .sorted { $0.round == $1.round ? $0.id < $1.id : $0.round < $1.round }
            .suffix(5)
        guard !recent.isEmpty else { return 0 }
        var score = 0
        for fixture in recent {
            let own = fixture.home == clubID ? (fixture.homeGoals ?? 0) : (fixture.awayGoals ?? 0)
            let opponent = fixture.home == clubID ? (fixture.awayGoals ?? 0) : (fixture.homeGoals ?? 0)
            if own > opponent { score += 1 } else if own < opponent { score -= 1 }
        }
        return Double(score) / Double(recent.count)
    }

    func calculation(context: MatchSimulationContext, afterMinute: Int = 0) -> ScoreCalculation {
        let homePower = power(for: context.home, lineup: context.isHomeSelected ? context.lineup : [], selected: context.isHomeSelected)
        let awayPower = power(for: context.away, lineup: context.isAwaySelected ? context.lineup : [], selected: context.isAwaySelected)
        let delta = homePower - awayPower

        let homeForm = formScore(clubID: context.home.id, fixtures: context.fixtures)
        let awayForm = formScore(clubID: context.away.id, fixtures: context.fixtures)

        let profile = parameters.blendedProfile
        let homeBoost = context.isHomeSelected ? profile.attack : context.isAwaySelected ? -profile.defense : 0
        let awayBoost = context.isAwaySelected ? profile.attack : context.isHomeSelected ? -profile.defense : 0

        return ScoreCalculation(afterMinute: afterMinute,
            home: .init(base: parameters.baseHomeGoals, venue: parameters.homeAdvantage,
                        strength: delta * parameters.powerWeight, form: homeForm * parameters.formWeight, strategy: homeBoost),
            away: .init(base: parameters.baseAwayGoals, venue: -parameters.homeAdvantage,
                        strength: -delta * parameters.powerWeight, form: awayForm * parameters.formWeight, strategy: awayBoost),
            mix: parameters.strategyMix, maxGoals: parameters.maxGoals)
    }

    func expectedGoals(context: MatchSimulationContext) -> (Double, Double) {
        let details = calculation(context: context)
        return (details.home.expected, details.away.expected)
    }

    func simulate<R: RandomNumberGenerator>(context: MatchSimulationContext, rng: inout R) -> (Int, Int) {
        let result = simulateRecorded(context: context, rng: &rng)
        return (result.homeGoals, result.awayGoals)
    }

    func simulateRecorded<R: RandomNumberGenerator>(context: MatchSimulationContext, rng: inout R) -> ScoreCalculation {
        var result = calculation(context: context)
        result.homeGoals = poisson(result.home.expected, maxGoals: parameters.maxGoals, rng: &rng, home: true, draws: &result.draws)
        result.awayGoals = poisson(result.away.expected, maxGoals: parameters.maxGoals, rng: &rng, home: false, draws: &result.draws)
        return result
    }

    private func poisson<R: RandomNumberGenerator>(_ lambda: Double, maxGoals: Int, rng: inout R, home: Bool, draws: inout [ScoreCalculation.Draw]) -> Int {
        let limit = exp(-lambda)
        var product = 1.0
        var count = 0
        repeat {
            count += 1
            let draw = Double.random(in: 0.000001...1, using: &rng)
            draws.append(.init(home: home, minute: nil, value: draw))
            product *= draw
        } while product > limit && count < maxGoals + 1
        return min(maxGoals, count - 1)
    }
}
