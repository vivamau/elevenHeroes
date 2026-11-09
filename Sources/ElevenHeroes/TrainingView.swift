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
    @State private var currentTactic: String = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Choose and tune the tactics available to your club. Changes feed the match engine parameters.")
                .foregroundStyle(.secondary)
            if let error {
                Label(error, systemImage: "exclamationmark.circle.fill").foregroundStyle(.red)
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("CURRENT TACTIC").font(.system(size: 11, weight: .bold)).tracking(1.7).foregroundStyle(.secondary)
                Picker("Current tactic", selection: $currentTactic) {
                    ForEach(tactics) { tactic in Text(tactic.name).tag(tactic.name) }
                }.pickerStyle(.segmented)
                Button("Apply to season") { applyTactic() }.gamePrimaryAction()
            }
            .padding(20).background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 12) {
                Text("TACTICS").font(.system(size: 11, weight: .bold)).tracking(1.7).foregroundStyle(.secondary)
                ForEach(tactics.indices, id: \.self) { index in
                    tacticEditor(index: index)
                }
                Button("Save tactics") { saveTactics() }.buttonStyle(.borderedProminent).tint(AppTheme.accent).foregroundStyle(AppTheme.background)
            }
            .padding(20).background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 14))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear(perform: load)
    }

    private func tacticEditor(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Name", text: $tactics[index].name).textFieldStyle(.roundedBorder)
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
        do {
            let db = try FootballDatabase(url: store.databaseURL)
            tactics = try db.tactics()
            currentTactic = season.tactic
            if !tactics.contains(where: { $0.name == currentTactic }) {
                currentTactic = tactics.first?.name ?? "Balanced"
            }
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
            load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func applyTactic() {
        store.season?.tactic = currentTactic
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
            store.season?.matchParameters = params
            store.save()
        } catch {
            self.error = error.localizedDescription
        }
    }
}