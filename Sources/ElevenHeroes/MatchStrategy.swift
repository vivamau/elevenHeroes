import Foundation

extension Season {
    /// Replace only the unrevealed portion of the current match. Season defaults and finances stay untouched.
    mutating func changeStrategy<R: RandomNumberGenerator>(fixtureID: Int, after minute: Int,
        tactic: String, parameters: MatchSimulationParameters, rng: inout R) -> Fixture? {
        guard minute < 90, let index = fixtures.firstIndex(where: { $0.id == fixtureID }),
              let home = clubs.first(where: { $0.id == fixtures[index].home }),
              let away = clubs.first(where: { $0.id == fixtures[index].away }) else { return nil }
        let fixture = fixtures[index]
        let context = MatchSimulationContext(home: home, away: away, selectedClub: selectedClub,
            lineup: fixture.activeLineup(for: selectedClub), tactic: tactic, round: fixture.round,
            fixtures: fixtures.filter { $0.round < fixture.round }, year: year)
        let simulator = MatchSimulator(parameters: parameters)
        var calculation = simulator.calculation(context: context, afterMinute: minute)
        let rates = (calculation.home.expected, calculation.away.expected)
        var events = (fixture.goalEvents ?? []).filter { ($0.minute ?? 90) <= minute }
        for (club, rate, starters) in [(home, rates.0, fixture.activeLineup(for: home.id)), (away, rates.1, fixture.activeLineup(for: away.id))] {
            let squad = club.players.filter { starters.contains($0.id) }
            var count = events.filter { $0.clubID == club.id }.count
            for nextMinute in (max(0, minute) + 1)...90 where count < parameters.maxGoals {
                let draw = Double.random(in: 0..<1, using: &rng)
                calculation.draws.append(.init(home: club.id == home.id, minute: nextMinute, value: draw))
                guard draw < 1 - exp(-rate / 90) else { continue }
                let scorer = simulator.scorer(from: squad, rng: &rng)
                let assist = Bool.random(using: &rng) ? squad.filter { $0.id != scorer?.id }.randomElement(using: &rng) : nil
                let description = GoalCommentary.describe(scorer: scorer?.name ?? club.name,
                    assist: assist?.name, variation: nextMinute + events.count)
                events.append(GoalEvent(clubID: club.id, clubName: club.name, scorerID: scorer?.id,
                    scorerName: scorer?.name, assistID: assist?.id, assistName: assist?.name,
                    minute: nextMinute, goalDescription: description))
                count += 1
            }
        }
        // Keep prior event ordering stable so visible commentary and celebrations keep their identity.
        fixtures[index].goalEvents = events
        fixtures[index].homeGoals = events.filter { $0.clubID == home.id }.count
        fixtures[index].awayGoals = events.filter { $0.clubID == away.id }.count
        calculation.homeGoals = fixtures[index].homeGoals ?? 0
        calculation.awayGoals = fixtures[index].awayGoals ?? 0
        fixtures[index].scoreCalculations = (fixture.scoreCalculations ?? []) + [calculation]
        var lines = ["Kick-off · \(home.name) v \(away.name)"]
        for event in events.sorted(by: { ($0.minute ?? 90) < ($1.minute ?? 90) }) {
            lines.append("\(event.minute ?? 90)′  GOAL · \(event.scorerName ?? event.clubName) — \(event.clubName)\n\(event.goalDescription ?? "")")
            if let assist = event.assistName { lines.append("    assist · \(assist)") }
        }
        for change in fixtures[index].substitutions ?? [] {
            lines.append("\(change.minute)′  Substitution · \(change.incomingName) on for \(change.outgoingName)")
        }
        lines.append("Full time · \(home.name) \(fixtures[index].homeGoals ?? 0) – \(fixtures[index].awayGoals ?? 0) \(away.name)")
        commentary = lines
        return fixtures[index]
    }
}

extension GameStore {
    func changeMatchStrategy(_ tactic: String, _ parameters: MatchSimulationParameters, _ elapsed: Double) {
        guard var match = liveMatch, elapsed < 57 else { return }
        let previous = match.parameters.blendedProfile
        let next = parameters.blendedProfile
        match.parameters = parameters
        match.tactic = tactic
        if previous.attack != next.attack || previous.defense != next.defense {
            var rng = SystemRandomNumberGenerator()
            if let fixture = season?.changeStrategy(fixtureID: match.fixture.id,
                after: Int(elapsed / 57 * 90), tactic: tactic, parameters: parameters, rng: &rng) {
                match.fixture = fixture
                save()
            }
        }
        liveMatch = match
    }
}
