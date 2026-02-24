import SwiftUI

// MARK: - Group Tint Colors

private extension AchievementGroup {
    var tintColor: Color {
        switch self {
        case .explorer: .blue
        case .completionist: .green
        case .variety: .purple
        case .dedication: .orange
        case .secret: .indigo
        }
    }
}

// MARK: - Summary Header

struct AchievementsSummaryHeader: View {
    let achievements: [AchievementState]

    @ScaledMetric(relativeTo: .body) private var ringSize: CGFloat = 72

    private var unlockedCount: Int {
        achievements.filter(\.isUnlocked).count
    }

    var body: some View {
        HStack(spacing: 16) {
            CompletionRing(
                completed: unlockedCount,
                total: achievements.count,
                size: ringSize
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "\(unlockedCount) of \(achievements.count)", comment: "Achievements: unlocked count ratio"))
                    .font(.title3.weight(.bold).monospacedDigit())

                Text(String(localized: "achievements unlocked", comment: "Achievements: unlocked count subtitle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(String(localized: "\(AchievementGroup.allCases.count) categories", comment: "Achievements: category count"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}

// MARK: - Category Filter

struct AchievementGroupFilter: View {
    let achievements: [AchievementState]
    let grouped: [AchievementGroup: [AchievementState]]
    @Binding var selectedGroup: AchievementGroup?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    icon: "trophy.fill",
                    name: String(localized: "All", comment: "Achievements: filter chip showing all categories"),
                    count: achievements.filter(\.isUnlocked).count,
                    total: achievements.count,
                    tint: .primary,
                    isSelected: selectedGroup == nil
                ) {
                    withAnimation(reduceMotion ? .none : .snappy(duration: 0.25)) {
                        selectedGroup = nil
                    }
                }

                ForEach(AchievementGroup.allCases, id: \.self) { group in
                    let items = grouped[group] ?? []
                    let count = items.filter(\.isUnlocked).count

                    FilterChip(
                        icon: group.systemImage,
                        name: group.label,
                        count: count,
                        total: items.count,
                        tint: group.tintColor,
                        isSelected: selectedGroup == group
                    ) {
                        withAnimation(reduceMotion ? .none : .snappy(duration: 0.25)) {
                            selectedGroup = group
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, -16) // counteract parent padding so scroll goes edge-to-edge
    }
}

struct FilterChip: View {
    let icon: String
    let name: String
    let count: Int
    let total: Int
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)

                Text(name)
                    .font(.caption.weight(.medium))

                Text("\(count)/\(total)")
                    .font(.caption2.monospacedDigit())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? Color(UIColor.systemBackground) : tint)
            .background(
                isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.1)),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Achievements List

struct AchievementsList: View {
    let selectedGroup: AchievementGroup?
    let grouped: [AchievementGroup: [AchievementState]]

    private var sections: [(group: AchievementGroup, items: [AchievementState])] {
        AchievementGroup.allCases.compactMap { group in
            guard let items = grouped[group], !items.isEmpty else { return nil }
            return (group: group, items: items)
        }
    }

    private var filteredItems: [AchievementState] {
        guard let group = selectedGroup else { return [] }
        return grouped[group] ?? []
    }

    var body: some View {
        if selectedGroup == nil {
            // Show all, grouped with section headers
            ForEach(sections, id: \.group) { section in
                VStack(alignment: .leading, spacing: 10) {
                    GroupSectionHeader(
                        group: section.group,
                        items: section.items
                    )

                    ForEach(section.items) { item in
                        RichAchievementCard(state: item)
                    }
                }
                .padding(.bottom, 10) // extra spacing between groups
            }
        } else {
            // Show filtered group without section header
            ForEach(filteredItems) { item in
                RichAchievementCard(state: item)
            }
        }
    }
}

// MARK: - Group Section Header

private struct GroupSectionHeader: View {
    let group: AchievementGroup
    let items: [AchievementState]

    private var unlockedCount: Int {
        items.filter(\.isUnlocked).count
    }

    var body: some View {
        HStack {
            Label(group.label, systemImage: group.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(group.tintColor)

            Spacer()

            Text("\(unlockedCount)/\(items.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }
}

// MARK: - Rich Achievement Card

struct RichAchievementCard: View {
    let state: AchievementState

    private var group: AchievementGroup {
        state.definition.group
    }

    private var isHiddenAndLocked: Bool {
        state.definition.isHidden && !state.isUnlocked
    }

    private var displayIcon: String {
        isHiddenAndLocked ? "questionmark" : state.definition.systemImage
    }

    private var displayTitle: String {
        isHiddenAndLocked
            ? String(localized: "???", comment: "Achievement: hidden achievement title placeholder")
            : state.definition.title
    }

    private var displayDescription: String {
        isHiddenAndLocked
            ? String(localized: "Secret achievement", comment: "Achievement: hidden achievement description placeholder")
            : state.definition.description
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon circle
            if state.isUnlocked {
                Image(systemName: displayIcon)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(
                            colors: [group.tintColor, group.tintColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
            } else if isHiddenAndLocked {
                Image(systemName: "questionmark")
                    .font(.title3)
                    .foregroundStyle(.quaternary)
                    .frame(width: 44, height: 44)
                    .background(Color(UIColor.quaternarySystemFill), in: Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [2, 2]))
                            .foregroundStyle(.quaternary)
                    )
            } else {
                Image(systemName: displayIcon)
                    .font(.title3)
                    .foregroundStyle(.quaternary)
                    .frame(width: 44, height: 44)
                    .background(Color(UIColor.quaternarySystemFill), in: Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                            .foregroundStyle(.quaternary)
                    )
            }

            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text(displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(state.isUnlocked ? .primary : .secondary)

                Text(displayDescription)
                    .font(.caption)
                    .foregroundStyle(state.isUnlocked ? .secondary : .tertiary)
                    .italic(isHiddenAndLocked)
            }

            Spacer()

            // Status indicator
            if state.isUnlocked, let date = state.unlockedAt {
                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.body)

                    Text(date, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 3, y: 2)
    }
}
