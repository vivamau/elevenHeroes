import SwiftUI

/// The same controls and language are used in season setup, training and live matches.
struct StrategyMixEditor: View {
    @Binding var parameters: MatchSimulationParameters
    var compact = false
    var showsHeading = true
    var onCommit: () -> Void = {}
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsHeading {
            HStack {
                Text("Strategy mix").font(.headline)
                Spacer()
                Text("Total 1.00").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            }
            let layout = compact ? AnyLayout(HStackLayout(spacing: 18)) : AnyLayout(VStackLayout(spacing: 10))
            layout {
                ForEach(StrategyMix.names, id: \.self) { name in
                    if compact {
                        VStack(spacing: 2) {
                            HStack {
                                Text(name).font(.caption)
                                Spacer(minLength: 4)
                                valueLabel(name)
                            }
                            slider(name)
                        }.frame(maxWidth: .infinity)
                    } else {
                        HStack(spacing: 12) {
                            Text(name).font(.callout).frame(width: 78, alignment: .leading)
                            slider(name)
                            valueLabel(name).frame(width: 38, alignment: .trailing)
                        }
                    }
                }
            }
            if !compact {
            Text("Adjust one share; the other two balance automatically.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func valueLabel(_ name: String) -> some View {
        Text(parameters.strategyMix.value(for: name).formatted(.number.precision(.fractionLength(2))))
            .font(.callout.monospacedDigit())
    }

    private func slider(_ name: String) -> some View {
        Slider(value: Binding(get: { parameters.strategyMix.value(for: name) }, set: {
            parameters.setStrategyShare(name, to: $0)
        }), in: 0...1, step: 0.01, onEditingChanged: { editing in if !editing { onCommit() } })
            .tint(AppTheme.accent)
            .accessibilityLabel("\(name) share")
            .accessibilityValue(parameters.strategyMix.value(for: name).formatted(.percent.precision(.fractionLength(0))))
            .help("Changing this share adjusts the other two to keep the total at 1.00.")
    }
}
