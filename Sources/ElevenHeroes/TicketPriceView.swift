import SwiftUI

struct TicketPriceEditor: View {
    @Binding var price: Int
    var body: some View {
        HStack(spacing: 12) {
            Label("Home ticket price", systemImage: "ticket")
            Spacer()
            TextField("Credits", value: $price, format: .number.grouping(.never))
                .textFieldStyle(.roundedBorder).frame(width: 70)
                .accessibilityLabel("Ticket price in credits")
            Text("credits").foregroundStyle(.secondary)
            Stepper("Ticket price", value: $price, in: 1...100).labelsHidden()
        }
    }
}

struct SeasonTicketSetupView: View {
    let year: Int
    let initialPrice: Int
    let initialParameters: MatchSimulationParameters
    let onStart: (Int, MatchSimulationParameters) -> Void
    @Environment(\.dismiss) private var dismiss
    @State var price: Int
    @State var parameters: MatchSimulationParameters
    init(year: Int, price: Int = 10, parameters: MatchSimulationParameters = .default, onStart: @escaping (Int, MatchSimulationParameters) -> Void) {
        self.year = year
        self.initialPrice = price
        self.initialParameters = parameters
        self.onStart = onStart
        _price = State(initialValue: price)
        _parameters = State(initialValue: parameters)
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Season \(String(year))").font(.title2.weight(.semibold))
                Text("Set the ticket price and match parameters for your home matches this season.").foregroundStyle(.secondary)
                TicketPriceEditor(price: $price)
                Text("Choose 1–100 credits per ticket. This price is fixed for the season.")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                MatchParametersEditor(parameters: $parameters)
                HStack {
                    Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                    Spacer()
                    Button { onStart(price, parameters); dismiss() } label: {
                        Label("Start season", systemImage: "play.fill").padding(.horizontal, 9).padding(.vertical, 7)
                    }.buttonStyle(.borderedProminent).tint(AppTheme.accent).foregroundStyle(AppTheme.background)
                        .disabled(!(1...100).contains(price))
                }
            }.padding(24).frame(width: 520)
        }.frame(height: 640)
        .background(AppTheme.background)
    }
}

struct MatchParametersEditor: View {
    @Binding var parameters: MatchSimulationParameters
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("MATCH PARAMETERS").font(.system(size: 11, weight: .bold)).tracking(1.7).foregroundStyle(.secondary)
            sliderRow("Home advantage", value: $parameters.homeAdvantage, range: 0...1, step: 0.05, format: "%.2f")
            sliderRow("Base home goals", value: $parameters.baseHomeGoals, range: 0.5...3, step: 0.05, format: "%.2f")
            sliderRow("Base away goals", value: $parameters.baseAwayGoals, range: 0.5...3, step: 0.05, format: "%.2f")
            sliderRow("Power weight", value: $parameters.powerWeight, range: 0...0.3, step: 0.01, format: "%.2f")
            sliderRow("Form weight", value: $parameters.formWeight, range: 0...0.5, step: 0.01, format: "%.2f")
            Stepper("Max goals: \(parameters.maxGoals)", value: $parameters.maxGoals, in: 4...12)
                .font(.callout)
            Text("Tactic modifiers").font(.caption.bold()).foregroundStyle(.secondary)
            tacticRow("Attacking", key: "Attacking")
            tacticRow("Balanced", key: "Balanced")
            tacticRow("Defensive", key: "Defensive")
        }
        .padding(16).background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 12))
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, format: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.callout)
                Spacer()
                Text(String(format: format, value.wrappedValue)).monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
        }
    }

    private func tacticRow(_ title: String, key: String) -> some View {
        let binding = Binding<Double>(
            get: { parameters.tactics[key]?.attack ?? 0 },
            set: { newValue in
                var profile = parameters.tactics[key] ?? TacticProfile(attack: 0, defense: 0)
                profile.attack = newValue
                parameters.tactics[key] = profile
            }
        )
        return HStack {
            Text(title).font(.callout).frame(width: 100, alignment: .leading)
            Slider(value: binding, in: -0.3...0.3, step: 0.01)
            Text(String(format: "%.2f", binding.wrappedValue)).monospacedDigit().foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
        }
    }
}
