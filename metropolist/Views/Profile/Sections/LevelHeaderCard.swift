import SwiftUI

struct LevelHeaderCard: View {
    let snapshot: GamificationSnapshot

    @State private var showXPBreakdown = false

    var body: some View {
        CardSection {
            VStack(spacing: 16) {
                // Level circle + title
                HStack(spacing: 16) {
                    Text("\(snapshot.level.number)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(levelGradient, in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "Level \(snapshot.level.number)", comment: "Profile: current level number"))
                            .font(.title3.bold())

                        Text(String(localized: "\(snapshot.totalXP) XP", comment: "Profile: total XP count"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let firstDate = snapshot.stats.firstTravelDate {
                        Text(String(
                            localized: "Since \(firstDate.formatted(.dateTime.month(.abbreviated).day().year()))",
                            comment: "Profile: member since date"
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                // XP progress bar
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        let progress = min(1.0, Double(snapshot.xpInCurrentLevel) / Double(snapshot.xpToNextLevel))
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.quaternary)
                                .frame(height: 8)

                            Capsule()
                                .fill(levelGradient)
                                .frame(width: max(8, geo.size.width * progress), height: 8)
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Text(String(
                            localized: "\(snapshot.xpInCurrentLevel) / \(snapshot.xpToNextLevel) XP",
                            comment: "Profile: XP progress toward next level"
                        ))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                        Spacer()

                        Text(String(localized: "Level \(nextLevel.number)", comment: "Profile: next level number"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // XP Breakdown
                xpBreakdownSection
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.snappy(duration: 0.25)) {
                    showXPBreakdown.toggle()
                }
            }
        }
    }

    private var xpBreakdownSection: some View {
        VStack(spacing: 0) {
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(showXPBreakdown ? 180 : 0))
                .frame(maxWidth: .infinity)
                .padding(.top, 4)

            if showXPBreakdown {
                let breakdown = snapshot.xpBreakdown
                let rows: [(String, String, Int)] = {
                    var r: [(String, String, Int)] = []
                    if breakdown.travelXP > 0 {
                        r.append((
                            "tram.fill",
                            String(localized: "Travels", comment: "XP breakdown: travel XP"),
                            breakdown.travelXP
                        ))
                    }
                    if breakdown.stopXP > 0 {
                        r.append((
                            "mappin.and.ellipse",
                            String(localized: "Stations", comment: "XP breakdown: station XP"),
                            breakdown.stopXP
                        ))
                    }
                    if breakdown.firstLineXP > 0 {
                        r.append((
                            "sparkles",
                            String(localized: "Line discovery", comment: "XP breakdown: first line XP"),
                            breakdown.firstLineXP
                        ))
                    }
                    if breakdown.lineCompletionXP > 0 {
                        r.append((
                            "checkmark.seal.fill",
                            String(localized: "Line completions", comment: "XP breakdown: line completion XP"),
                            breakdown.lineCompletionXP
                        ))
                    }
                    if breakdown.achievementXP > 0 {
                        r.append((
                            "trophy.fill",
                            String(localized: "Achievements", comment: "XP breakdown: achievement XP"),
                            breakdown.achievementXP
                        ))
                    }
                    if breakdown.streakXP > 0 {
                        r.append((
                            "flame.fill",
                            String(localized: "Streaks", comment: "XP breakdown: streak XP"),
                            breakdown.streakXP
                        ))
                    }
                    return r
                }()

                VStack(spacing: 8) {
                    ForEach(rows, id: \.1) { icon, label, xp in
                        HStack(spacing: 10) {
                            Image(systemName: icon)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)

                            Text(label)
                                .font(.caption)
                                .foregroundStyle(.primary)

                            Spacer()

                            Text(String(localized: "\(xp) XP", comment: "XP breakdown: amount"))
                                .font(.caption.monospacedDigit().bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var levelGradient: LinearGradient {
        let colors: [Color] = [.blue, .green, .purple, .orange, .red, .yellow]
        let index = (snapshot.level.number - 1) % colors.count
        let base = colors[index]
        return LinearGradient(colors: [base, base.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var nextLevel: PlayerLevel {
        LevelDefinitions.nextLevel(after: snapshot.level)
    }
}
