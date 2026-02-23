import SwiftUI

struct CelebrationToast: View {
    let event: CelebrationEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.leveledUp ? "arrow.up.circle.fill" : "star.fill")
                .font(.title3)
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 2) {
                if event.leveledUp, let newLevel = event.newLevel {
                    Text(String(localized: "Level \(newLevel.number)!", comment: "Celebration: level up notification"))
                        .font(.subheadline.bold())
                } else if !event.newAchievements.isEmpty {
                    Text(event.newAchievements.first?.title ?? "")
                        .font(.subheadline.bold())
                } else if event.xpGained > 0 {
                    Text(String(localized: "+\(event.xpGained) XP", comment: "Celebration: XP gained amount"))
                        .font(.subheadline.bold())
                }

                if !event.newBadges.isEmpty {
                    let count = event.newBadges.count
                    Text(String(localized: "\(count) new badge\(count > 1 ? "s" : "")", comment: "Celebration: new badges earned count"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .padding(.horizontal, 16)
    }
}
