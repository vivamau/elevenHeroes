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

    func expectedGoals(context: MatchSimulationContext) -> (Double, Double) {
        let homePower = power(for: context.home, lineup: context.isHomeSelected ? context.lineup : [], selected: context.isHomeSelected)
        let awayPower = power(for: context.away, lineup: context.isAwaySelected ? context.lineup : [], selected: context.isAwaySelected)
        let delta = homePower - awayPower

        let homeForm = formScore(clubID: context.home.id, fixtures: context.fixtures)
        let awayForm = formScore(clubID: context.away.id, fixtures: context.fixtures)

        let tactic = context.tactic
        let profile = parameters.tactics[tactic] ?? TacticProfile(attack: 0, defense: 0)
        let tacticBoost = profile.attack

        var lambdaHome = parameters.baseHomeGoals
            + parameters.homeAdvantage
            + delta * parameters.powerWeight
            + homeForm * parameters.formWeight
            + tacticBoost
        var lambdaAway = parameters.baseAwayGoals
            - parameters.homeAdvantage
            - delta * parameters.powerWeight
            + awayForm * parameters.formWeight
            + tacticBoost

        lambdaHome = min(max(lambdaHome, 0.2), 4.5)
        lambdaAway = min(max(lambdaAway, 0.2), 4.5)
        return (lambdaHome, lambdaAway)
    }

    func simulate<R: RandomNumberGenerator>(context: MatchSimulationContext, rng: inout R) -> (Int, Int) {
        let (lambdaHome, lambdaAway) = expectedGoals(context: context)
        return (poisson(lambdaHome, maxGoals: parameters.maxGoals, rng: &rng),
                poisson(lambdaAway, maxGoals: parameters.maxGoals, rng: &rng))
    }

    private func poisson<R: RandomNumberGenerator>(_ lambda: Double, maxGoals: Int, rng: inout R) -> Int {
        let limit = exp(-lambda)
        var product = 1.0
        var count = 0
        repeat {
            count += 1
            product *= Double.random(in: 0.000001...1, using: &rng)
        } while product > limit && count < maxGoals + 1
        return min(maxGoals, count - 1)
    }
}