import Foundation

/// Integer hundredths keep the displayed shares at exactly 1.00.
struct StrategyMix: Codable, Equatable {
    private var attacking = 25
    private var balanced = 50
    private var defensive = 25
    static let names = ["Attacking", "Balanced", "Defensive"]

    func value(for name: String) -> Double {
        Double(points(for: name)) / 100
    }

    private func points(for name: String) -> Int {
        switch name {
        case "Attacking": attacking
        case "Defensive": defensive
        default: balanced
        }
    }

    private mutating func set(_ name: String, points: Int) {
        switch name {
        case "Attacking": attacking = points
        case "Defensive": defensive = points
        default: balanced = points
        }
    }

    mutating func update(_ name: String, to value: Double) {
        guard Self.names.contains(name), value.isFinite else { return }
        let selected = Int((min(1, max(0, value)) * 100).rounded())
        let others = Self.names.filter { $0 != name }
        let total = points(for: others[0]) + points(for: others[1])
        let remainder = 100 - selected
        let first = total > 0
            ? Int((Double(remainder * points(for: others[0])) / Double(total)).rounded())
            : remainder / 2
        set(name, points: selected)
        set(others[0], points: first)
        set(others[1], points: remainder - first)
    }
}

extension MatchSimulationParameters {
    var strategyMix: StrategyMix { mix ?? StrategyMix() }

    mutating func setStrategyShare(_ name: String, to value: Double) {
        var updated = strategyMix
        updated.update(name, to: value)
        mix = updated
    }

    var blendedProfile: TacticProfile {
        var result = TacticProfile(attack: 0, defense: 0)
        for name in StrategyMix.names {
            let profile = tactics[name] ?? MatchSimulationParameters.default.tactics[name]!
            let share = strategyMix.value(for: name)
            result.attack += profile.attack * share
            result.defense += profile.defense * share
        }
        return result
    }
}
