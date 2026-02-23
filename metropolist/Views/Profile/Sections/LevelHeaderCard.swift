import SwiftUI

struct LevelHeaderCard: View {
    let snapshot: GamificationSnapshot

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
