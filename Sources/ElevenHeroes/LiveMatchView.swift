import SwiftUI

struct MatchPlayback: Identifiable {
    let id = UUID()
    var fixture: Fixture
    let home: String
    let away: String
    var parameters: MatchSimulationParameters = .default
    var tactic: String = "Balanced"
    var homeKit = "#C2F559"
    var awayKit = "#00BCD4"
    var managedClubID: Int? = nil
    var squad: [Footballer] = []
    static let duration: Double = 60

    struct Action: Identifiable {
        let id: Int
        let minute: Int
        let text: String
        let goal: GoalEvent?
        var time: Double { Double(minute) / 90 * 57 }
    }

    var actions: [Action] {
        let passages = [
            "Kick-off! Both teams settle into their shape.",
            "\(home) work the ball across midfield, looking for an opening.",
            "\(away) press high and force the ball back into defence.",
            "A dangerous cross is cleared from the penalty area.",
            "A quick attack breaks down at the edge of the box.",
            "Half-time. The teams regroup for the second half.",
            "Play resumes, with both sides looking for space out wide.",
            "A through ball runs just too far and the keeper gathers it.",
            "The defence closes down a promising attack.",
            "The tempo rises as the final whistle approaches.",
            "One last push forward in the closing minutes."
        ]
        let minutes = [0, 9, 18, 27, 36, 45, 46, 57, 68, 79, 88]
        var result = zip(minutes, passages).enumerated().map {
            Action(id: $0.offset, minute: $0.element.0, text: $0.element.1, goal: nil)
        }
        for (index, goal) in (fixture.goalEvents ?? []).enumerated() {
            result.append(Action(id: passages.count + index, minute: goal.minute ?? 90,
                                 text: goal.goalDescription ?? "\(goal.scorerName ?? goal.clubName) scores!", goal: goal))
        }
        for (index, change) in (fixture.substitutions ?? []).enumerated() {
            result.append(Action(id: -1000 - index, minute: change.minute,
                text: "Substitution · \(change.incomingName) on for \(change.outgoingName)", goal: nil))
        }
        return result.sorted { $0.minute == $1.minute ? $0.id < $1.id : $0.minute < $1.minute }
    }

    func score(at elapsed: Double) -> (home: Int, away: Int) {
        let goals = actions.filter { $0.time <= elapsed }.compactMap(\.goal)
        return (goals.filter { $0.clubID == fixture.home }.count,
                goals.filter { $0.clubID == fixture.away }.count)
    }
}

struct LiveMatchView: View {
    let match: MatchPlayback
    let onFinish: () -> Void
    var onStrategyChange: (String, MatchSimulationParameters, Double) -> Void = { _, _, _ in }
    var onSubstitute: (Int, Int, Double) -> String? = { _, _, _ in "Substitutions unavailable." }
    @State private var paused = false
    @State private var showingSubstitution = false
    @State private var strategy = "Balanced"
    @State private var baselineTactic = "Balanced"
    @State private var baselineParameters = MatchSimulationParameters.default
    @State private var strategyParameters = MatchSimulationParameters.default
    @State private var elapsed: Double = 0
    @State private var showingCalculations = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var finished: Bool { elapsed >= MatchPlayback.duration }
    private var visible: [MatchPlayback.Action] { match.actions.filter { $0.time <= elapsed } }
    private var celebration: MatchPlayback.Action? {
        visible.last(where: { $0.goal != nil && elapsed - $0.time < 3 })
    }

    var body: some View {
        GeometryReader { geometry in
        let compactHeight = geometry.size.height < 560
        let pitchHeight = compactHeight ? 80.0 : min(200, geometry.size.height * 0.28)
        VStack(spacing: compactHeight ? 6 : 10) {
            HStack {
                Text(finished ? "FULL TIME" : paused ? "PAUSED" : "LIVE MATCH").font(.caption.bold()).tracking(2)
                Spacer()
                if !finished {
                    Button("Pause & substitute", systemImage: "pause.fill") {
                        paused = true
                        showingSubstitution = true
                    }.gamePrimaryAction().controlSize(.small).disabled(elapsed >= 57)
                }
                Text(finished ? "90′" : "\(min(90, Int(elapsed / 57 * 90)))′")
                    .font(.title2.monospacedDigit().bold())
            }.foregroundStyle(AppTheme.accent)
            HStack(spacing: 24) {
                MatchTeamLabel(name: match.home, kit: match.homeKit)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                let score = match.score(at: elapsed)
                Text("\(score.home) – \(score.away)").font(.system(size: 32, weight: .black, design: .monospaced))
                MatchTeamLabel(name: match.away, kit: match.awayKit)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.font(.title3.bold())
            ProgressView(value: elapsed, total: MatchPlayback.duration).tint(AppTheme.accent)
            ZStack {
                if celebration == nil {
                    PixelMatchPitch(elapsed: elapsed, reduceMotion: reduceMotion, homeKit: match.homeKit, awayKit: match.awayKit)
                        .transition(.opacity)
                } else {
                    PixelGoalArt(isGoal: true, shirtColor: TeamKits.color(celebration?.goal?.clubID == match.fixture.home ? match.homeKit : match.awayKit)).frame(height: 180).scaleEffect(min(1, pitchHeight / 180)).frame(height: pitchHeight)
                        .transition(.opacity)
                }
                if let action = celebration, let goal = action.goal {
                    VStack(spacing: 6) {
                        Text("GOAL!").font(.system(size: 42, weight: .black, design: .monospaced))
                        Text("\(goal.scorerName ?? goal.clubName) · \(goal.clubName)").font(.headline)
                    }.padding(16).background(.black.opacity(0.85))
                        .transition(.opacity)
                }
            }.frame(height: pitchHeight).clipped()
                .animation(.easeOut(duration: reduceMotion ? 0 : 0.2), value: celebration?.id)
            VStack(spacing: 6) {
                StrategyMixEditor(parameters: $strategyParameters, compact: true, showsHeading: !compactHeight) {
                    if !finished { onStrategyChange(strategy, strategyParameters, elapsed) }
                }
                if !compactHeight {
                    Text("This match only · season settings return at full time").font(.caption2).foregroundStyle(.secondary)
                }
            }.disabled(elapsed >= 57)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(visible) { action in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(action.minute)′").font(.callout.monospacedDigit()).frame(width: 36)
                                VStack(alignment: .leading, spacing: 4) {
                                    if let goal = action.goal {
                                        Text("GOAL · \(goal.clubName)").font(.headline).foregroundStyle(AppTheme.accent)
                                    }
                                    Text(action.text).fixedSize(horizontal: false, vertical: true)
                                }
                            }.id(action.id)
                        }
                        if finished { Text("Full time — the final whistle blows.").font(.headline).id(-1) }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                }.background(AppTheme.background, in: RoundedRectangle(cornerRadius: 8))
                    .onChange(of: visible.count) { _, _ in if let last = visible.last { proxy.scrollTo(last.id, anchor: .bottom) } }
                    .onChange(of: finished) { _, done in if done { proxy.scrollTo(-1, anchor: .bottom) } }
            }.frame(maxHeight: .infinity)
            HStack {
                Text(finished ? "Match report ready" : "\(max(0, 60 - Int(elapsed))) seconds to full time")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Score calculations") { showingCalculations = true }.gamePrimaryAction().disabled(!finished)
                Button("View match report", action: onFinish).gamePrimaryAction().disabled(!finished).keyboardShortcut(.defaultAction)
            }.controlSize(compactHeight ? .small : .regular)
        }.padding(compactHeight ? 12 : 16).frame(width: geometry.size.width, height: geometry.size.height)
        }.frame(width: 740, height: AppTheme.sheetHeight(720)).background(AppTheme.panel)
            .interactiveDismissDisabled()
            .sheet(isPresented: $showingCalculations) {
                ScoreCalculationView(fixture: match.fixture, homeName: match.home, awayName: match.away)
            }
            .sheet(isPresented: $showingSubstitution) {
                MatchSubstitutionView(match: match, onSubstitute: { off, on in onSubstitute(off, on, elapsed) }, onResume: {
                    showingSubstitution = false
                    paused = false
                })
            }
            .onAppear {
                baselineTactic = match.tactic
                baselineParameters = match.parameters
                strategy = match.tactic
                strategyParameters = match.parameters
            }
            .task(id: paused) {
                guard !paused, !finished else { return }
                let startingElapsed = elapsed
                let clock = ContinuousClock()
                let start = clock.now
                while !Task.isCancelled && !finished {
                    do { try await clock.sleep(until: start.advanced(by: .milliseconds(Int((elapsed - startingElapsed + 0.1) * 1000)))) }
                    catch { return }
                    let duration = start.duration(to: clock.now).components
                    elapsed = min(60, startingElapsed + Double(duration.seconds) + Double(duration.attoseconds) / 1e18)
                    if finished {
                        strategy = baselineTactic
                        strategyParameters = baselineParameters
                    }
                }
            }
    }
}

/// Integer-sized blocks keep the goal, net and football crisp at every display scale.
private struct PixelGoalArt: View {
    let isGoal: Bool
    var shirtColor: Color = AppTheme.accent
    var body: some View {
        Canvas { context, size in
            let unit: CGFloat = 6
            func block(_ x: Int, _ y: Int, _ width: Int, _ height: Int, _ color: Color) {
                context.fill(Path(CGRect(x: CGFloat(x) * unit, y: CGFloat(y) * unit,
                                         width: CGFloat(width) * unit, height: CGFloat(height) * unit)), with: .color(color))
            }
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.06, green: 0.22, blue: 0.14)))
            for x in stride(from: 0, to: Int(size.width / unit), by: 12) { block(x, 0, 6, 30, .white.opacity(0.025)) }
            block(72, 4, 32, 1, .white); block(72, 4, 1, 22, .white); block(103, 4, 1, 22, .white)
            block(72, 25, 32, 1, .white)
            for x in stride(from: 76, through: 100, by: 4) { block(x, 5, 1, 20, .white.opacity(0.2)) }
            for y in stride(from: 8, through: 24, by: 4) { block(73, y, 30, 1, .white.opacity(0.2)) }
            // Player sprite: head, jersey, arms, shorts and boots.
            block(39, 9, 3, 3, Color(red: 0.88, green: 0.64, blue: 0.42))
            block(38, 12, 5, 6, shirtColor)
            block(35, isGoal ? 8 : 13, 2, 6, shirtColor)
            block(44, isGoal ? 8 : 13, 2, 6, shirtColor)
            block(38, 18, 5, 2, .black); block(38, 20, 2, 5, .white); block(42, 20, 2, 5, .white)
            let ballX = isGoal ? 90 : 51
            let pixels = [".WWW.", "WWBWW", "WBBBW", "WWBWW", ".WWW."]
            for (y, row) in pixels.enumerated() {
                for (x, pixel) in row.enumerated() where pixel != "." {
                    block(ballX + x, 20 + y, 1, 1, pixel == "B" ? .black : .white)
                }
            }
            if isGoal {
                for x in [14, 24, 55, 63, 108] { block(x, 5 + x % 9, 2, 2, AppTheme.accent) }
            }
        }.accessibilityLabel(isGoal ? "Pixel art: a football in the net and a player celebrating" : "Pixel art football pitch")
    }
}


/// The shirt shows the kit selected for this fixture, including any clash-driven alternate.
private struct MatchTeamLabel: View {
    let name: String
    let kit: String

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let logo = CSVTeam.logo(for: name), let url = URL(string: logo) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image { image.resizable().scaledToFit() }
                        else { Image(systemName: "shield.lefthalf.filled").foregroundStyle(.secondary) }
                    }
                } else {
                    Image(systemName: "shield.lefthalf.filled").foregroundStyle(.secondary)
                }
            }.frame(width: 24, height: 24).accessibilityHidden(true)
            Text(name).lineLimit(2)
            Image(systemName: "tshirt.fill")
                .font(.system(size: 17))
                .foregroundStyle(TeamKits.color(kit))
                .padding(5)
                .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.35)))
                .help("Match shirt colour: \(kit)")
                .accessibilityLabel("Match shirt colour \(kit)")
        }.accessibilityElement(children: .combine)
    }
}
