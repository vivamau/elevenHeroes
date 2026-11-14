import SwiftUI

struct MatchSubstitution: Codable {
    let clubID: Int
    let minute: Int
    let outgoingID: Int
    let incomingID: Int
    let outgoingName: String
    let incomingName: String
}

extension Fixture {
    func activeLineup(for clubID: Int) -> [Int] {
        var active = (clubID == home ? homeLineup : awayLineup) ?? []
        for change in substitutions ?? [] where change.clubID == clubID {
            if let index = active.firstIndex(of: change.outgoingID) { active[index] = change.incomingID }
        }
        return active
    }

    func availableBench(for clubID: Int) -> [Int] {
        let used = Set((substitutions ?? []).filter { $0.clubID == clubID }.map(\.incomingID))
        return ((clubID == home ? homeSubstitutes : awaySubstitutes) ?? []).filter { !used.contains($0) }
    }
}

extension Season {
    mutating func substitute<R: RandomNumberGenerator>(fixtureID: Int, outgoing: Int, incoming: Int,
        minute: Int, parameters: MatchSimulationParameters, rng: inout R) throws -> Fixture {
        guard (0..<90).contains(minute), let index = fixtures.firstIndex(where: { $0.id == fixtureID }),
              fixtures[index].home == selectedClub || fixtures[index].away == selectedClub,
              let club = clubs.first(where: { $0.id == selectedClub }),
              let off = club.players.first(where: { $0.id == outgoing }),
              let on = club.players.first(where: { $0.id == incoming }),
              fixtures[index].activeLineup(for: selectedClub).contains(outgoing),
              fixtures[index].availableBench(for: selectedClub).contains(incoming) else {
            throw DatabaseIssue(message: "Choose a player on the pitch and an unused substitute.")
        }
        guard (off.role == "GK") == (on.role == "GK") else {
            throw DatabaseIssue(message: "Replace a goalkeeper with a goalkeeper, and an outfield player with an outfield player.")
        }
        let fixture = fixtures[index]
        guard let home = clubs.first(where: { $0.id == fixture.home }),
              let away = clubs.first(where: { $0.id == fixture.away }) else {
            throw DatabaseIssue(message: "Match clubs could not be found.")
        }
        let simulator = MatchSimulator(parameters: parameters)
        let priorLineup = fixture.activeLineup(for: selectedClub)
        let before = simulator.calculation(context: MatchSimulationContext(home: home, away: away,
            selectedClub: selectedClub, lineup: priorLineup, tactic: tactic, round: fixture.round,
            fixtures: fixtures.filter { $0.round < fixture.round }, year: year), afterMinute: minute)
        let strengthBefore = simulator.power(for: club, lineup: priorLineup, selected: true)
        let change = MatchSubstitution(clubID: selectedClub, minute: minute, outgoingID: outgoing,
            incomingID: incoming, outgoingName: off.name, incomingName: on.name)
        fixtures[index].substitutions = (fixtures[index].substitutions ?? []) + [change]
        guard var result = changeStrategy(fixtureID: fixtureID, after: minute, tactic: tactic, parameters: parameters, rng: &rng) else {
            throw DatabaseIssue(message: "This match has already ended.")
        }
        let strengthAfter = simulator.power(for: club, lineup: result.activeLineup(for: selectedClub), selected: true)
        if let last = result.scoreCalculations?.indices.last {
            result.scoreCalculations?[last].substitutionImpact = .init(change: change,
                outgoingRating: off.rating, incomingRating: on.rating, strengthBefore: strengthBefore,
                strengthAfter: strengthAfter,
                homeBefore: before.home, awayBefore: before.away)
        }
        fixtures[index] = result
        return result
    }
}

extension GameStore {
    func makeMatchSubstitution(_ outgoing: Int, _ incoming: Int, _ elapsed: Double) -> String? {
        guard var match = liveMatch, var updated = season, elapsed < 57 else { return "This match has already ended." }
        do {
            var rng = SystemRandomNumberGenerator()
            match.fixture = try updated.substitute(fixtureID: match.fixture.id, outgoing: outgoing, incoming: incoming,
                minute: Int(elapsed / 57 * 90), parameters: match.parameters, rng: &rng)
            try JSONEncoder().encode(updated).write(to: saveURL, options: .atomic)
            season = updated
            liveMatch = match
            return nil
        } catch { return error.localizedDescription }
    }
}

struct MatchSubstitutionView: View {
    let match: MatchPlayback
    let onSubstitute: (Int, Int) -> String?
    let onResume: () -> Void
    @State private var outgoing: Int?
    @State private var incoming: Int?
    @State private var completed = false
    @State private var error: String?

    private var clubID: Int { match.managedClubID ?? match.fixture.home }
    private var active: [Footballer] { match.squad.filter { match.fixture.activeLineup(for: clubID).contains($0.id) } }
    private var bench: [Footballer] { match.squad.filter { match.fixture.availableBench(for: clubID).contains($0.id) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(completed ? "Substitution complete" : "Match paused").font(.title2.bold())
            if completed {
                Text("Your substitute is on the pitch. Resume when you’re ready.")
                Button("Resume match", systemImage: "play.fill", action: onResume).gamePrimaryAction()
                    .keyboardShortcut(.defaultAction)
            } else {
                Text("The clock and play are stopped while you choose a substitute.").foregroundStyle(.secondary)
                Picker("Player off", selection: $outgoing) {
                    Text("Choose player").tag(nil as Int?)
                    ForEach(active) { Text("\($0.name) · \($0.role) · \($0.rating) OVR").tag(Optional($0.id)) }
                }
                Picker("Player on", selection: $incoming) {
                    Text("Choose substitute").tag(nil as Int?)
                    ForEach(bench) { Text("\($0.name) · \($0.role) · \($0.rating) OVR").tag(Optional($0.id)) }
                }
                if bench.isEmpty { Text("No unused substitutes remain.").foregroundStyle(.secondary) }
                if let error { Text(error).foregroundStyle(.orange) }
                HStack {
                    Button("Resume without changes", role: .cancel, action: onResume).gamePrimaryAction()
                    Spacer()
                    Button("Make substitution") {
                        guard let outgoing, let incoming else { return }
                        error = onSubstitute(outgoing, incoming)
                        completed = error == nil
                    }.gamePrimaryAction().disabled(outgoing == nil || incoming == nil)
                }
            }
        }.padding(24).frame(width: 580).background(AppTheme.panel).interactiveDismissDisabled()
    }
}
