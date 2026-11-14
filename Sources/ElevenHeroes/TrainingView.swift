import SwiftUI

extension ContentView {
    func training(_ s: Season) -> some View {
        TrainingView(season: s, store: store)
    }
}

struct TrainingView: View {
    let season: Season
    let store: GameStore
    @State private var tactics: [Tactic] = []
    @State private var parameters = MatchSimulationParameters.default
    @State private var status = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Set your default approach for upcoming matches. Changes made during a match last for that match only.")
                .foregroundStyle(.secondary)
            if let error {
                Label(error, systemImage: "exclamationmark.circle.fill").foregroundStyle(.red)
            }
            GameCard(title: "Season strategy") {
                StrategyMixEditor(parameters: $parameters)
                HStack {
                    Button("Save season strategy") { applyTactic() }.gamePrimaryAction()
                    if !status.isEmpty { Label(status, systemImage: "checkmark.circle").font(.callout).foregroundStyle(.secondary) }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                DisclosureGroup("Advanced tactic profiles") {
                Text("Edit how each approach affects attack and defence. Save these profiles, then apply them to the season.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(tactics.indices, id: \.self) { index in
                    tacticEditor(index: index)
                }
                Button("Save tactic profiles") { saveTactics() }.gamePrimaryAction()
                Button("Apply saved profiles to season") { applyProfiles() }.gamePrimaryAction()
                }
            }
            .padding(20).gameSurface()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear(perform: load)
        .onChange(of: parameters.strategyMix) { _, _ in status = "" }
    }

    private func tacticEditor(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tactics[index].name).font(.headline)
            HStack {
                Text("Attack").frame(width: 60, alignment: .leading)
                Slider(value: $tactics[index].attack, in: -0.5...0.5, step: 0.01)
                Text(String(format: "%.2f", tactics[index].attack)).monospacedDigit().frame(width: 44)
            }
            HStack {
                Text("Defense").frame(width: 60, alignment: .leading)
                Slider(value: $tactics[index].defense, in: -0.5...0.5, step: 0.01)
                Text(String(format: "%.2f", tactics[index].defense)).monospacedDigit().frame(width: 44)
            }
            Divider()
        }
    }

    private func load() {
        parameters = store.season?.matchParameters ?? .default
        do {
            let db = try FootballDatabase(url: store.databaseURL)
            tactics = try db.tactics().filter { StrategyMix.names.contains($0.name) }
            parameters = store.season?.matchParameters ?? .default
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func saveTactics() {
        do {
            let db = try FootballDatabase(url: store.databaseURL, writable: true)
            for tactic in tactics {
                _ = try db.saveTactic(id: tactic.id, name: tactic.name, attack: tactic.attack, defense: tactic.defense)
            }
            tactics = try db.tactics().filter { StrategyMix.names.contains($0.name) }
            status = "Tactic profiles saved"
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func applyTactic() {
        let previous = store.season
        store.season?.matchParameters = parameters
        if store.save(to: store.saveURL) { status = "Season strategy saved" }
        else { store.season = previous; status = "" }
    }

    private func applyProfiles() {
        // Update match parameters tactic profiles from the database.
        do {
            let db = try FootballDatabase(url: store.databaseURL)
            let dbTactics = try db.tactics()
            var params = store.season?.matchParameters ?? .default
            var profiles: [String: TacticProfile] = [:]
            for tactic in dbTactics {
                profiles[tactic.name] = TacticProfile(attack: tactic.attack, defense: tactic.defense)
            }
            params.tactics = profiles
            let previous = store.season
            store.season?.matchParameters = params
            if store.save(to: store.saveURL) {
                parameters = params
                status = "Tactic profiles applied"
            } else { store.season = previous; status = "" }
        } catch {
            self.error = error.localizedDescription
        }
    }
}