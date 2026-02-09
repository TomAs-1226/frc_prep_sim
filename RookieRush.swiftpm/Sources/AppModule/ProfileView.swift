import SwiftUI

// MARK: - Profile View

/// Stats dashboard, achievement gallery, and round history for the player.
struct ProfileView: View {
    @ObservedObject var profileManager: ProfileManager
    @Environment(\.dismiss) private var dismiss

    @State private var showResetAlert = false

    private var profile: PlayerProfile { profileManager.profile }

    private var unlockedPartsCount: Int {
        let dtCount = DrivetrainChoice.allCases.filter { profile.isUnlocked($0) }.count
        let frCount = FrameChoice.allCases.filter { profile.isUnlocked($0) }.count
        let mpCount = ManipulatorChoice.allCases.filter { profile.isUnlocked($0) }.count
        let inCount = IntakeChoice.allCases.filter { profile.isUnlocked($0) }.count
        return dtCount + frCount + mpCount + inCount
    }

    private var earnedAchievementsCount: Int {
        Achievement.allCases.filter { profile.earnedAchievements.contains($0.rawValue) }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.1),
                        Color(red: 0.08, green: 0.06, blue: 0.14),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        playerCard
                            .padding(.top, 16)

                        statsGrid

                        robotPartsSection

                        achievementsSection

                        roundHistorySection

                        resetButton
                            .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.headline)
                        .foregroundStyle(.orange)
                }
            }
            .alert("Reset Progress", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    profileManager.resetProfile()
                }
            } message: {
                Text("This will erase all stats, achievements, and round history. This cannot be undone.")
            }
        }
    }

    // MARK: - 1. Player Card

    @ViewBuilder
    private var playerCard: some View {
        VStack(spacing: 16) {
            // Level display
            VStack(spacing: 4) {
                Text("LEVEL")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(2)

                Text("\(profile.level)")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(.orange)
            }

            // XP progress bar
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.orange.opacity(0.7), .orange],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geo.size.width * CGFloat(min(1.0, profile.xpProgress)),
                                height: 6
                            )
                    }
                }
                .frame(height: 6)

                Text("\(profile.xp) / \(profile.xpForNextLevel) XP")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
            }

            // Quick stats row
            HStack(spacing: 0) {
                quickStat(value: "\(profile.totalRounds)", label: "Rounds")
                quickStat(value: "\(Int(profile.winRate))%", label: "Win Rate")
                quickStat(value: "\(profile.bestBuildScore)", label: "Best Build")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func quickStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 2. Stats Grid

    @ViewBuilder
    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "STATS", icon: "chart.bar.fill")

            let columns = [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
            ]

            LazyVGrid(columns: columns, spacing: 10) {
                statCard(icon: "trophy.fill", value: "\(profile.wins)", label: "Total Wins", color: .yellow)
                statCard(icon: "xmark.circle.fill", value: "\(profile.losses)", label: "Total Losses", color: .red)
                statCard(icon: "flame.fill", value: "\(profile.bestWinStreak)", label: "Win Streak", color: .orange)
                statCard(icon: "gauge.with.dots.needle.67percent", value: "\(profile.averageBuildScore)", label: "Avg Build Score", color: .cyan)
                statCard(icon: "star.fill", value: "\(profile.bestBuildScore)", label: "Best Build Score", color: .purple)
                statCard(icon: "flag.checkered", value: "\(profile.totalRounds)", label: "Total Rounds", color: .green)
            }
        }
    }

    @ViewBuilder
    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: - 3. Robot Parts Section

    @ViewBuilder
    private var robotPartsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(title: "ROBOT PARTS", icon: "wrench.and.screwdriver.fill")
                Spacer()
                Text("\(unlockedPartsCount)/13 Unlocked")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.orange)
            }

            // Drivetrain row
            partCategoryRow(
                category: "Drivetrain",
                parts: DrivetrainChoice.allCases.map { dt in
                    (dt.icon, dt.shortLabel, dt.color, dt.unlockLevel, profile.isUnlocked(dt))
                }
            )

            // Frame row
            partCategoryRow(
                category: "Frame",
                parts: FrameChoice.allCases.map { fr in
                    (fr.icon, fr.shortLabel, fr.color, fr.unlockLevel, profile.isUnlocked(fr))
                }
            )

            // Manipulator row
            partCategoryRow(
                category: "Manipulator",
                parts: ManipulatorChoice.allCases.map { mp in
                    (mp.icon, mp.shortLabel, mp.color, mp.unlockLevel, profile.isUnlocked(mp))
                }
            )

            // Intake row
            partCategoryRow(
                category: "Intake",
                parts: IntakeChoice.allCases.map { ink in
                    (ink.icon, ink.shortLabel, ink.color, ink.unlockLevel, profile.isUnlocked(ink))
                }
            )
        }
    }

    @ViewBuilder
    private func partCategoryRow(category: String, parts: [(icon: String, label: String, color: Color, unlockLevel: Int, unlocked: Bool)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(category.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1)

            HStack(spacing: 8) {
                ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                    partBadge(
                        icon: part.icon,
                        label: part.label,
                        color: part.color,
                        unlockLevel: part.unlockLevel,
                        isUnlocked: part.unlocked
                    )
                }
                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
        )
    }

    @ViewBuilder
    private func partBadge(icon: String, label: String, color: Color, unlockLevel: Int, isUnlocked: Bool) -> some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isUnlocked ? color.opacity(0.15) : Color.white.opacity(0.04))
                    .frame(width: 48, height: 48)

                if isUnlocked {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                } else {
                    VStack(spacing: 2) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.25))
                        Text("Lv. \(unlockLevel)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }

                // Checkmark badge for unlocked
                if isUnlocked {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)
                                .offset(x: 4, y: -4)
                        }
                        Spacer()
                    }
                    .frame(width: 48, height: 48)
                }
            }

            Text(label)
                .font(.system(size: 9, weight: isUnlocked ? .bold : .regular))
                .foregroundStyle(isUnlocked ? .white.opacity(0.8) : .white.opacity(0.3))
                .lineLimit(1)
        }
    }

    // MARK: - 4. Achievements Section

    @ViewBuilder
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(title: "ACHIEVEMENTS", icon: "medal.fill")
                Spacer()
                Text("\(earnedAchievementsCount)/12 Earned")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.orange)
            }

            let columns = [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ]

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Achievement.allCases) { achievement in
                    achievementBadge(achievement: achievement)
                }
            }
        }
    }

    @ViewBuilder
    private func achievementBadge(achievement: Achievement) -> some View {
        let isEarned = profile.earnedAchievements.contains(achievement.rawValue)

        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isEarned ? achievement.color.opacity(0.2) : Color.white.opacity(0.04))
                    .frame(width: 52, height: 52)

                if isEarned {
                    Image(systemName: achievement.icon)
                        .font(.title3)
                        .foregroundStyle(achievement.color)
                } else {
                    ZStack {
                        Image(systemName: achievement.icon)
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.1))
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.3))
                            .offset(x: 12, y: 12)
                    }
                }
            }

            Text(achievement.rawValue)
                .font(.system(size: 10, weight: isEarned ? .bold : .regular))
                .foregroundStyle(isEarned ? .white.opacity(0.85) : .white.opacity(0.3))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(achievement.description)
                .font(.system(size: 8))
                .foregroundStyle(isEarned ? achievement.color.opacity(0.7) : .white.opacity(0.2))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isEarned ? achievement.color.opacity(0.04) : Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isEarned ? achievement.color.opacity(0.2) : Color.clear,
                            lineWidth: 1
                        )
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(achievement.rawValue): \(achievement.description). \(isEarned ? "Earned" : "Locked")")
    }

    // MARK: - 5. Round History Section

    @ViewBuilder
    private var roundHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "RECENT MATCHES", icon: "clock.fill")

            if profile.roundHistory.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.15))
                        Text("No matches yet")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.3))
                        Text("Complete a match to see your history here")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.2))
                    }
                    .padding(.vertical, 30)
                    Spacer()
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.03))
                )
            } else {
                VStack(spacing: 2) {
                    ForEach(profile.roundHistory) { record in
                        roundRow(record: record)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func roundRow(record: RoundRecord) -> some View {
        let resultInfo = roundResultInfo(record: record)

        HStack(spacing: 12) {
            // Win/Loss/Tie indicator
            Circle()
                .fill(resultInfo.color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.gameName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(record.archetype)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(record.redScore) - \(record.blueScore)")
                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))

                HStack(spacing: 6) {
                    Text("Build: \(record.buildMatchScore)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))

                    Text(resultInfo.label)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(resultInfo.color)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.gameName), \(record.archetype). Score: \(record.redScore) to \(record.blueScore). Build score: \(record.buildMatchScore). \(resultInfo.label).")
    }

    /// Returns the result label and color for a round record without using
    /// a bare switch inside a @ViewBuilder context.
    private func roundResultInfo(record: RoundRecord) -> (label: String, color: Color) {
        if record.tied {
            return ("TIE", .orange)
        } else if record.won {
            return ("WIN", .green)
        } else {
            return ("LOSS", .red)
        }
    }

    // MARK: - 6. Reset Button

    @ViewBuilder
    private var resetButton: some View {
        Button(action: { showResetAlert = true }) {
            HStack(spacing: 8) {
                Image(systemName: "trash.fill")
                Text("Reset Progress")
                    .font(.headline)
            }
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.red.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
                    )
            )
            .modifier(GlassModifier(shape: RoundedRectangle(cornerRadius: 14)))
        }
        .accessibilityLabel("Reset all progress and start over")
    }

    // MARK: - Shared Components

    @ViewBuilder
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.orange)
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(1)
        }
    }
}
