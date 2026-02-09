import SwiftUI

// MARK: - Tournament Selection View

struct TournamentSelectView: View {
    let onSelect: (TournamentConfig) -> Void
    let onBack: () -> Void
    @State private var selected: TournamentConfig?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.12),
                    Color(red: 0.10, green: 0.06, blue: 0.18),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 10) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.yellow)
                    Text("Tournament Mode")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Play a series of matches against unique opponents")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    ForEach(TournamentConfig.allConfigs, id: \.name) { config in
                        tournamentCard(config: config)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 12) {
                    Button(action: {
                        if let s = selected { onSelect(s) }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "flag.checkered")
                            Text("Enter Tournament")
                                .font(.headline)
                        }
                        .foregroundStyle(selected != nil ? .black : .white.opacity(0.3))
                        .frame(maxWidth: 260)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(selected != nil ? Color.yellow : Color.white.opacity(0.08))
                        )
                    }
                    .disabled(selected == nil)

                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(.bottom, 30)
            }
        }
    }

    @ViewBuilder
    private func tournamentCard(config: TournamentConfig) -> some View {
        let isSelected = selected?.name == config.name
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selected = config } }) {
            HStack(spacing: 16) {
                VStack {
                    Text("\(config.matchCount)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.yellow)
                    Text("Matches")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(width: 60)

                VStack(alignment: .leading, spacing: 4) {
                    Text(config.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(configDescription(config))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.yellow)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(isSelected ? 0.08 : 0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isSelected ? Color.yellow.opacity(0.5) : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func configDescription(_ config: TournamentConfig) -> String {
        switch config.matchCount {
        case 3: return "Quick format — different opponents each match."
        case 5: return "Standard regional. Varied strategies and builds."
        case 7: return "Full championship. Escalating difficulty."
        default: return "\(config.matchCount) matches."
        }
    }
}

// MARK: - Tournament Progress View

struct TournamentProgressView: View {
    @ObservedObject var tournament: TournamentState
    let onStartMatch: () -> Void
    let onFinish: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.12),
                    Color(red: 0.10, green: 0.06, blue: 0.18),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                VStack(spacing: 6) {
                    Text(tournament.config.name.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.yellow.opacity(0.7))
                        .tracking(2)
                    Text("Match \(tournament.currentMatchIndex + 1) of \(tournament.config.matchCount)")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }
                .padding(.top, 40)

                // Standings
                standingsCard
                    .padding(.horizontal, 20)

                // Match history
                if !tournament.matchResults.isEmpty {
                    matchHistorySection
                        .padding(.horizontal, 20)
                }

                Spacer()

                // Next match preview
                if !tournament.isComplete {
                    nextMatchPreview
                        .padding(.horizontal, 20)

                    Button(action: onStartMatch) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text("Start Match \(tournament.currentMatchIndex + 1)")
                                .font(.headline)
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: 260)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.yellow)
                        )
                    }
                } else {
                    Button(action: onFinish) {
                        HStack(spacing: 8) {
                            Image(systemName: "trophy.fill")
                            Text("View Final Results")
                                .font(.headline)
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: 260)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.yellow)
                        )
                    }
                }

                Spacer().frame(height: 30)
            }
        }
    }

    @ViewBuilder
    private var standingsCard: some View {
        HStack(spacing: 20) {
            statPill(value: "\(tournament.wins)", label: "Wins", color: .green)
            statPill(value: "\(tournament.losses)", label: "Losses", color: .red)
            statPill(value: "\(tournament.ties)", label: "Ties", color: .orange)
            Divider().frame(height: 30).background(Color.white.opacity(0.1))
            statPill(value: "\(tournament.totalRedScore)", label: "Red Pts", color: .red)
            statPill(value: "\(tournament.totalBlueScore)", label: "Blue Pts", color: Color(red: 0.3, green: 0.5, blue: 1))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.yellow.opacity(0.15), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func statPill(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    @ViewBuilder
    private var matchHistorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MATCH HISTORY")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1)

            ForEach(Array(tournament.matchResults.enumerated()), id: \.offset) { idx, result in
                HStack(spacing: 12) {
                    Text("M\(idx + 1)")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 30)

                    Text("\(result.redScore)")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                    Text("-")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.3))
                    Text("\(result.blueScore)")
                        .font(.caption.bold())
                        .foregroundStyle(Color(red: 0.3, green: 0.5, blue: 1))

                    Spacer()

                    Text(result.playerWon ? "WIN" : (result.margin == 0 ? "TIE" : "LOSS"))
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(result.playerWon ? .green : (result.margin == 0 ? .orange : .red))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(
                                (result.playerWon ? Color.green : (result.margin == 0 ? Color.orange : Color.red))
                                    .opacity(0.15)
                            )
                        )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.03))
                )
            }
        }
    }

    @ViewBuilder
    private var nextMatchPreview: some View {
        let roles = tournament.opponentRoles(for: tournament.currentMatchIndex)
        VStack(alignment: .leading, spacing: 8) {
            Text("NEXT OPPONENTS")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1)

            HStack(spacing: 12) {
                ForEach(Array(roles.enumerated()), id: \.offset) { _, role in
                    HStack(spacing: 6) {
                        Image(systemName: role.icon)
                            .font(.caption)
                            .foregroundStyle(Color(red: 0.3, green: 0.5, blue: 1))
                        Text(role.rawValue)
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(Color(red: 0.3, green: 0.5, blue: 1).opacity(0.12))
                    )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
        )
    }
}

// MARK: - Tournament Results View

struct TournamentResultsView: View {
    @ObservedObject var tournament: TournamentState
    let onDone: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.12),
                    Color(red: 0.10, green: 0.06, blue: 0.18),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Trophy
                    VStack(spacing: 12) {
                        Image(systemName: tournament.wins > tournament.losses ? "trophy.fill" : "medal.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(tournament.wins > tournament.losses ? .yellow : .orange)

                        Text(tournamentVerdict)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text("\(tournament.config.name) Complete")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.top, 40)

                    // Final standings
                    VStack(spacing: 12) {
                        HStack(spacing: 30) {
                            resultStat(value: "\(tournament.wins)", label: "Wins", color: .green)
                            resultStat(value: "\(tournament.losses)", label: "Losses", color: .red)
                            resultStat(value: "\(tournament.ties)", label: "Ties", color: .orange)
                        }

                        Divider().background(Color.white.opacity(0.1))

                        HStack(spacing: 30) {
                            resultStat(value: "\(tournament.totalRedScore)", label: "Total Red", color: .red)
                            resultStat(value: "\(tournament.totalBlueScore)", label: "Total Blue",
                                       color: Color(red: 0.3, green: 0.5, blue: 1))
                            resultStat(value: String(format: "%.0f%%", tournament.winRate * 100),
                                       label: "Win Rate", color: .yellow)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.yellow.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)

                    // Match-by-match
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ALL MATCHES")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                            .tracking(1)

                        ForEach(Array(tournament.matchResults.enumerated()), id: \.offset) { idx, result in
                            matchResultRow(index: idx, result: result)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Build recommendation
                    buildRecommendation
                        .padding(.horizontal, 20)

                    Button(action: onDone) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Return to Menu")
                                .font(.headline)
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: 260)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.yellow)
                        )
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private var tournamentVerdict: String {
        if tournament.wins > tournament.losses { return "Champion!" }
        if tournament.wins == tournament.losses { return "Even Split" }
        return "Keep Practicing!"
    }

    @ViewBuilder
    private func resultStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    @ViewBuilder
    private func matchResultRow(index: Int, result: MatchResult) -> some View {
        HStack(spacing: 12) {
            Text("Match \(index + 1)")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 60, alignment: .leading)

            Text("\(result.redScore) - \(result.blueScore)")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(.white)

            Spacer()

            Text("\(result.playerRobotScored) scored")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.4))

            Text(result.playerWon ? "WIN" : (result.margin == 0 ? "TIE" : "LOSS"))
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(result.playerWon ? .green : (result.margin == 0 ? .orange : .red))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(
                        (result.playerWon ? Color.green : (result.margin == 0 ? Color.orange : Color.red)).opacity(0.15)
                    )
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
        )
    }

    @ViewBuilder
    private var buildRecommendation: some View {
        let avgScored = tournament.matchResults.isEmpty ? 0 :
            tournament.matchResults.reduce(0) { $0 + $1.playerRobotScored } / tournament.matchResults.count
        let hadStalls = tournament.matchResults.contains { $0.didPlayerStall }
        let build = tournament.playerBuild

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundStyle(.orange)
                Text("Build Analysis")
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)
            }

            Text(buildAnalysisText(avgScored: avgScored, hadStalls: hadStalls, build: build))
                .font(.body)
                .foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.orange.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.orange.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private func buildAnalysisText(avgScored: Int, hadStalls: Bool, build: RobotBuild) -> String {
        var lines: [String] = []

        lines.append("Your \(build.drivetrain.shortLabel)/\(build.mechanism.shortLabel)/\(build.intake.shortLabel) build averaged \(avgScored) scores per match across \(tournament.config.matchCount) matches.")

        if hadStalls {
            if build.intake == .roller {
                lines.append("You experienced stalls. Consider switching to Claw intake for +8% reliability, especially with \(build.mechanism.shortLabel) mechanism.")
            } else {
                lines.append("Stalls occurred despite Claw intake. Try a safer auto plan or simpler mechanism for better consistency.")
            }
        }

        if tournament.winRate < 0.4 {
            if build.mechanism == .elevator {
                lines.append("Try Arm or Low Intake for faster cycle times — high ceiling doesn't help if cycles are too slow.")
            }
            if tournament.playerRole == .defender {
                lines.append("Consider Cycler role — your team may need more scoring output.")
            }
        } else if tournament.winRate > 0.6 {
            lines.append("Strong performance! To optimize further, experiment with your tuning sliders — gear ratio and mechanism precision can squeeze out extra points.")
        }

        return lines.joined(separator: "\n\n")
    }
}
