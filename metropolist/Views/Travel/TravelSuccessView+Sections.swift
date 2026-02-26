import SwiftUI
import TransitModels

// MARK: - Section Views

extension TravelSuccessView {
    var arrivalSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(lineColor.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .scaleEffect(showArrival ? 1 : 0)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(lineColor)
                    .symbolEffect(.bounce, value: showCheckmark)
                    .scaleEffect(showCheckmark ? 1 : 0)
            }
            .accessibilityHidden(true)

            Text(String(localized: "Journey Recorded!", comment: "Travel success: main headline"))
                .font(.title2.bold())
                .opacity(showHeadline ? 1 : 0)
                .offset(y: showHeadline ? 0 : 10)
        }
    }

    var journeyHeaderSection: some View {
        Group {
            if let line = viewModel.selectedLine,
               let origin = viewModel.originStation,
               let destination = viewModel.destinationStation {
                VStack(spacing: 8) {
                    LineBadge(line: line)

                    Text(String(
                        localized: "\(origin.name) → \(destination.name)",
                        comment: "Travel success: route summary"
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(String(
                    localized: "Line \(line.shortName), \(origin.name) to \(destination.name)",
                    comment: "Travel success accessibility: route summary"
                )))
                .opacity(showJourneyHeader ? 1 : 0)
                .offset(y: showJourneyHeader ? 0 : 10)
            }
        }
    }

    var xpBreakdownSection: some View {
        Group {
            if let celebration = viewModel.celebrationEvent, !celebration.xpItems.isEmpty {
                VStack(spacing: 6) {
                    ForEach(Array(celebration.xpItems.enumerated()), id: \.element.id) { index, item in
                        xpItemRow(item: item)
                            .opacity(showXPItems.contains(index) ? 1 : 0)
                            .offset(y: showXPItems.contains(index) ? 0 : 12)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Phase 4: Ticker & Level Bar

    var tickerSection: some View {
        Group {
            if let celebration = viewModel.celebrationEvent, celebration.xpGained > 0 {
                VStack(spacing: 12) {
                    Text("+\(tickerValue) XP")
                        .font(.title.bold().monospacedDigit())
                        .foregroundStyle(.orange)
                        .contentTransition(.numericText(value: Double(tickerValue)))
                        .opacity(showTicker ? 1 : 0)

                    if showLevelBar {
                        VStack(spacing: 6) {
                            HStack {
                                Text(String(
                                    localized: "Level \(celebration.levelProgress.afterLevel.number)",
                                    comment: "Travel success: current level label"
                                ))
                                .font(.caption.bold())
                                .scaleEffect(levelBounce ? 1.2 : 1.0)

                                Spacer()

                                Text(String(
                                    localized: "\(celebration.levelProgress.afterXPInLevel)/\(celebration.levelProgress.afterXPToNext) XP",
                                    comment: "Travel success: XP progress within level"
                                ))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(.quaternary)
                                        .frame(height: 8)

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(lineColor)
                                        .frame(
                                            width: max(0, geo.size.width * levelBarProgress),
                                            height: 8
                                        )
                                }
                            }
                            .frame(height: 8)
                            .accessibilityHidden(true)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(String(
                            localized: "Level \(celebration.levelProgress.afterLevel.number)",
                            comment: "Travel success accessibility: level progress label"
                        )))
                        .accessibilityValue(Text(String(
                            localized: "\(celebration.levelProgress.afterXPInLevel) of \(celebration.levelProgress.afterXPToNext) XP",
                            comment: "Travel success accessibility: level progress value"
                        )))
                        .padding(.horizontal, 8)
                        .transition(.opacity)
                    }

                    if celebration.leveledUp, let newLevel = celebration.newLevel, showLoot {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.yellow)
                            Text(String(
                                localized: "Level \(newLevel.number) reached!",
                                comment: "Travel success: level up announcement"
                            ))
                            .font(.headline)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
    }

    // MARK: - Phase 5: Loot

    var lootSection: some View {
        Group {
            if let celebration = viewModel.celebrationEvent, showLoot {
                VStack(spacing: 10) {
                    ForEach(celebration.newBadges, id: \.lineSourceID) { badge in
                        lootCard(
                            icon: badge.tier.systemImage,
                            iconColor: badge.tier.color,
                            title: String(
                                localized: "\(badge.tier.label) Badge",
                                comment: "Travel success: badge card title"
                            ),
                            description: String(
                                localized: "Line badge upgraded",
                                comment: "Travel success: badge card description"
                            )
                        )
                    }

                    ForEach(regularAchievements) { achievement in
                        lootCard(
                            icon: achievement.systemImage,
                            iconColor: .yellow,
                            title: achievement.title,
                            description: achievement.description
                        )
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Phase 6: Epic Inline Cards

    var epicLootSection: some View {
        Group {
            if showEpicLoot, !hiddenAchievements.isEmpty {
                VStack(spacing: 10) {
                    ForEach(hiddenAchievements) { achievement in
                        epicInlineCard(achievement: achievement)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    var teaserSection: some View {
        Group {
            if let celebration = viewModel.celebrationEvent,
               let teaser = celebration.teaser,
               showTeaser {
                teaserText(teaser)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(showTeaser ? 1 : 0)
            }
        }
    }

    // MARK: - Helper Views

    func xpItemRow(item: CelebrationXPItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.systemImage)
                .font(.body)
                .foregroundStyle(xpItemColor(for: item.kind))
                .frame(width: 24)

            Text(item.label)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            if item.xpValue > 0 {
                Text("+\(item.xpValue) XP")
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(xpItemColor(for: item.kind))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(item.xpValue > 0
                ? "\(item.label), +\(item.xpValue) XP"
                : item.label))
    }

    func xpItemColor(for kind: CelebrationXPItem.Kind) -> Color {
        switch kind {
        case .baseTravel, .newStations, .streak:
            .green
        case .discoveryBonus, .lineCompletion:
            .yellow
        case .badgeMilestone:
            .orange
        case .achievement:
            .yellow
        }
    }

    func lootCard(icon: String, iconColor: Color, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(title), \(description)"))
    }

    func epicInlineCard(achievement: AchievementDefinition) -> some View {
        HStack(spacing: 12) {
            Image(systemName: achievement.systemImage)
                .font(.title2)
                .foregroundStyle(.yellow)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.title)
                    .font(.subheadline.bold())
                Text(achievement.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("+\(achievement.xpReward) XP")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(.orange)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            AngularGradient(
                                colors: [.yellow, .orange, .yellow.opacity(0.3), .orange, .yellow],
                                center: .center,
                                angle: .degrees(epicShimmerPhase * 360)
                            ),
                            lineWidth: 1.5
                        )
                }
                .shadow(color: .yellow.opacity(0.2), radius: 8, y: 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(achievement.title), \(achievement.description), +\(achievement.xpReward) XP"))
    }

    func teaserText(_ teaser: CelebrationTeaser) -> Text {
        switch teaser {
        case let .stopsToNextBadge(lineShortName, stopsRemaining, nextTier):
            Text(String(
                localized: "Only \(stopsRemaining) more stops to \(nextTier.label) on Line \(lineShortName)!",
                comment: "Travel success: teaser for next badge tier"
            ))
        case let .xpToNextLevel(xpRemaining, nextLevel):
            Text(String(
                localized: "\(xpRemaining) XP to Level \(nextLevel.number)",
                comment: "Travel success: teaser for next level"
            ))
        }
    }
}
