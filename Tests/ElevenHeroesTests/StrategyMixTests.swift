import Foundation
import Testing
@testable import ElevenHeroes

struct StrategyMixTests {
    @Test func alwaysTotalsOneAcrossRepeatedChanges() {
        var mix = StrategyMix()
        for name in StrategyMix.names {
            for point in 0...100 {
                mix.update(name, to: Double(point) / 100)
                let values = StrategyMix.names.map { mix.value(for: $0) }
                #expect(values.allSatisfy { (0...1).contains($0) })
                #expect(values.map { Int(($0 * 100).rounded()) }.reduce(0, +) == 100)
                #expect(abs(mix.value(for: name) - Double(point) / 100) < 0.000001)
            }
        }
    }

    @Test func redistributesProportionallyAndRecoversFromAllIn() {
        var mix = StrategyMix()
        mix.update("Attacking", to: 0.4)
        #expect(mix.value(for: "Balanced") == 0.4)
        #expect(mix.value(for: "Defensive") == 0.2)
        mix.update("Attacking", to: 1)
        mix.update("Attacking", to: 0.5)
        #expect(mix.value(for: "Balanced") == 0.25)
        #expect(mix.value(for: "Defensive") == 0.25)
    }

    @Test func savedSharesRoundTripAndLegacyParametersHaveValidDefaults() throws {
        var parameters = MatchSimulationParameters.default
        parameters.setStrategyShare("Defensive", to: 0.7)
        let decoded = try JSONDecoder().decode(MatchSimulationParameters.self, from: JSONEncoder().encode(parameters))
        #expect(decoded.strategyMix == parameters.strategyMix)
        let data = try JSONEncoder().encode(MatchSimulationParameters.default)
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "mix")
        let legacy = try JSONDecoder().decode(MatchSimulationParameters.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(legacy.strategyMix == StrategyMix())
    }
}
