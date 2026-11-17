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
    static let halfTime: Double = 28.5

    static func playbackTime(proposed: Double, halfTimeTaken: Bool) -> Double {
        min(proposed, halfTimeTaken ? duration : halfTime)
    }

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
    @State private var halfTimeTaken = false
    @State private var atHalfTime = false
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
            let upperHeight = min(170.0, max(150.0, geometry.size.height * 0.30))
            VStack(spacing: 8) {
                scoreboard.frame(height: 78)
                HStack(alignment: .top, spacing: 8) {
                    dashboardPanel("DUGOUT", icon: "slider.horizontal.3") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(StrategyMix.names, id: \.self) { name in
                                HStack(spacing: 6) {
                                    Text(name).font(.caption).frame(width: 62, alignment: .leading)
                                    Slider(value: Binding(get: {
                                        strategyParameters.strategyMix.value(for: name)
                                    }, set: {
                                        strategyParameters.setStrategyShare(name, to: $0)
                                    }), in: 0...1, step: 0.01, onEditingChanged: { editing in
                                        if !editing && !finished { onStrategyChange(strategy, strategyParameters, elapsed) }
                                    }).tint(AppTheme.accent).accessibilityLabel("\(name) share")
                                    Text(strategyParameters.strategyMix.value(for: name), format: .percent.precision(.fractionLength(0)))
                                        .font(.caption.monospacedDigit()).frame(width: 32, alignment: .trailing)
                                }.disabled(elapsed >= 57)
                            }
                            Button("Pause & substitute", systemImage: "arrow.left.arrow.right") {
                                paused = true
                                showingSubstitution = true
                            }.gamePrimaryAction().controlSize(.small).disabled(elapsed >= 57)
                        }
                    }.frame(width: 250)
                    dashboardPanel("MATCH EVENTS", icon: "list.bullet") {
                        events
                    }
                    dashboardPanel("MATCH DETAILS", icon: "sportscourt") {
                        VStack(alignment: .leading, spacing: 6) {
                            detail("Competition", "Round \(match.fixture.round)")
                            detail("Venue", match.fixture.stadiumName ?? "Home stadium")
                            detail("Phase", finished ? "Full time" : atHalfTime ? "Half time" : elapsed < MatchPlayback.halfTime ? "First half" : "Second half")
                            Spacer(minLength: 0)
                        }.frame(maxWidth: .infinity, alignment: .topLeading)
                    }.frame(width: 170).help("Player movement is illustrative.")
                }.frame(height: upperHeight)
                dashboardPanel("ON THE PITCH", icon: "soccerball") {
                    HStack(spacing: 10) {
                        teamSummary(home: true).frame(width: 130)
                        ZStack {
                            TacticalMatchPitch(elapsed: elapsed, reduceMotion: reduceMotion,
                                               homeKit: match.homeKit, awayKit: match.awayKit)
                            if let goal = celebration?.goal {
                                VStack(spacing: 6) {
                                    Text("GOAL!").font(.system(size: 32, weight: .black, design: .rounded))
                                    Text(goal.scorerName ?? goal.clubName).font(.headline)
                                }.padding(18).background(.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 8))
                            }
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                        teamSummary(home: false).frame(width: 130)
                    }
                }
                HStack {
                    Text(finished ? "Match report ready" : atHalfTime ? "Half time · adjust tactics or substitutions" : "\(max(0, 60 - Int(elapsed))) seconds to full time")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if atHalfTime {
                        Button("Start second half", systemImage: "play.fill") {
                            atHalfTime = false
                            paused = false
                        }.gamePrimaryAction()
                    }
                    Button("Score calculations") { showingCalculations = true }.gamePrimaryAction().disabled(!finished)
                    Button("View match report", action: onFinish).gamePrimaryAction().disabled(!finished).keyboardShortcut(.defaultAction)
                }.controlSize(.small)
            }.padding(12)
        }.frame(width: min(920, (NSScreen.main?.visibleFrame.width ?? 1024) - 48), height: AppTheme.sheetHeight(620))
            .background(LinearGradient(colors: [AppTheme.background, Color(red: 0.025, green: 0.22, blue: 0.15)], startPoint: .top, endPoint: .bottom))
            .preferredColorScheme(.dark)
            .interactiveDismissDisabled()
            .sheet(isPresented: $showingCalculations) {
                ScoreCalculationView(fixture: match.fixture, homeName: match.home, awayName: match.away)
            }
            .sheet(isPresented: $showingSubstitution) {
                MatchSubstitutionView(match: match, onSubstitute: { off, on in onSubstitute(off, on, elapsed) }, onResume: {
                    showingSubstitution = false
                    if !atHalfTime { paused = false }
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
                    elapsed = MatchPlayback.playbackTime(
                        proposed: startingElapsed + Double(duration.seconds) + Double(duration.attoseconds) / 1e18,
                        halfTimeTaken: halfTimeTaken)
                    if !halfTimeTaken && elapsed >= MatchPlayback.halfTime {
                        halfTimeTaken = true
                        atHalfTime = true
                        paused = true
                        return
                    }
                    if finished {
                        strategy = baselineTactic
                        strategyParameters = baselineParameters
                    }
                }
            }
    }

    private var scoreboard: some View {
        VStack(spacing: 6) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(finished ? "FULL TIME" : atHalfTime ? "HALF TIME" : paused ? "PAUSED" : "LIVE MATCH")
                        .font(.caption2.bold()).foregroundStyle(AppTheme.accent)
                    Text("\(min(90, Int(elapsed / 57 * 90)))′")
                        .font(.title2.monospacedDigit().bold())
                }.frame(width: 80, alignment: .leading)
                MatchTeamLabel(name: match.home, kit: match.homeKit).frame(maxWidth: .infinity, alignment: .trailing)
                let score = match.score(at: elapsed)
                Text("\(score.home) : \(score.away)")
                    .font(.system(size: 30, weight: .bold, design: .rounded)).monospacedDigit().fixedSize()
                MatchTeamLabel(name: match.away, kit: match.awayKit).frame(maxWidth: .infinity, alignment: .leading)
            }.font(.headline)
            ProgressView(value: elapsed, total: MatchPlayback.duration).tint(AppTheme.accent)
        }.padding(10).background(.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 8))
    }

    private func dashboardPanel<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon).font(.system(size: 11, weight: .heavy)).tracking(1)
                .foregroundStyle(.white.opacity(0.65))
            content()
        }.padding(10).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(red: 0.075, green: 0.11, blue: 0.13).opacity(0.95), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.12)))
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.caption.bold()).lineLimit(2).help(value)
        }
    }

    private func teamSummary(home: Bool) -> some View {
        let clubID = home ? match.fixture.home : match.fixture.away
        let goals = visible.compactMap(\.goal).filter { $0.clubID == clubID }
        return VStack(alignment: .leading, spacing: 6) {
            MatchTeamLabel(name: home ? match.home : match.away, kit: home ? match.homeKit : match.awayKit)
                .font(.caption.bold())
            HStack {
                Text("Goals")
                Spacer()
                Text("\(goals.count)").bold().monospacedDigit()
            }.font(.caption).padding(7).background(.white.opacity(0.06))
            ScrollView {
            VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(goals.enumerated()), id: \.offset) { _, goal in
                Text("\(goal.minute ?? 90)′  \(goal.scorerName ?? goal.clubName)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            }
            }
            Text(home ? "HOME" : "AWAY").font(.caption2.bold()).tracking(2).foregroundStyle(.secondary)
        }.frame(maxHeight: .infinity, alignment: .top)
    }

    private var events: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(visible) { action in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(action.minute)′").font(.caption.monospacedDigit().bold())
                                .foregroundStyle(AppTheme.accent).frame(width: 28, alignment: .leading)
                            Text(action.text).font(.callout)
                                .foregroundStyle(action.goal == nil ? Color.white.opacity(0.7) : .white)
                                .fixedSize(horizontal: false, vertical: true)
                        }.id(action.id)
                        Divider().opacity(0.4)
                    }
                    if finished { Text("Full time — the final whistle blows.").font(.headline).id(-1) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: visible.count) { _, _ in
                if let last = visible.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
            .onChange(of: finished) { _, done in if done { proxy.scrollTo(-1, anchor: .bottom) } }
        }
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
