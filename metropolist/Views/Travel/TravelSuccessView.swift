import SwiftUI
import TransitModels

struct TravelSuccessView: View {
    let viewModel: TravelFlowViewModel
    let onDone: () -> Void

    // Phase states
    @State private var showArrival = false
    @State private var showCheckmark = false
    @State private var showHeadline = false
    @State private var showJourneyHeader = false
    @State private var showXPItems: Set<Int> = []
    @State private var showTicker = false
    @State private var tickerValue = 0
    @State private var showLevelBar = false
    @State private var levelBarProgress: CGFloat = 0
    @State private var levelBounce = false
    @State private var showConfetti = false
    @State private var showLoot = false
    @State private var showTeaser = false
    @State private var showDone = false

    @State private var tickerTimer: Timer?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var lineColor: Color {
        if let line = viewModel.selectedLine {
            Color(hex: line.color)
        } else {
            .accentColor
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 40)

                // MARK: Phase 1 — Arrival

                arrivalSection

                // MARK: Phase 2 — Journey Header

                journeyHeaderSection

                // MARK: Phase 3 — XP Breakdown

                xpBreakdownSection

                // MARK: Phase 4 — Ticker & Level Bar

                tickerSection

                // MARK: Phase 5 — Loot & Teaser

                lootSection
                teaserSection

                Spacer().frame(height: 32)
            }
            .padding(.horizontal, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            Button {
                onDone()
            } label: {
                Text(String(localized: "Done", comment: "Travel success: dismiss button"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .accessibilityIdentifier("button-done")
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
            )
            .opacity(showDone ? 1 : 0)
            .offset(y: showDone ? 0 : 10)
        }
        .overlay {
            if !reduceMotion {
                ConfettiView(isActive: showConfetti, color: lineColor)
                    .ignoresSafeArea()
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.success, trigger: showCheckmark)
        .onAppear(perform: startSequence)
        .onDisappear { tickerTimer?.invalidate() }
    }

    // MARK: - Phase 1: Arrival

    private var arrivalSection: some View {
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

            Text(String(localized: "Journey Recorded!", comment: "Travel success: main headline"))
                .font(.title2.bold())
                .opacity(showHeadline ? 1 : 0)
                .offset(y: showHeadline ? 0 : 10)
        }
    }

    // MARK: - Phase 2: Journey Header

    private var journeyHeaderSection: some View {
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
                .opacity(showJourneyHeader ? 1 : 0)
                .offset(y: showJourneyHeader ? 0 : 10)
            }
        }
    }

    // MARK: - Phase 3: XP Breakdown

    private var xpBreakdownSection: some View {
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

    private func xpItemRow(item: CelebrationXPItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.systemImage)
                .font(.body)
                .foregroundStyle(xpItemColor(for: item.kind))
                .frame(width: 24)

            Text(item.label)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            if item.xp > 0 {
                Text("+\(item.xp) XP")
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(xpItemColor(for: item.kind))
            }
        }
    }

    private func xpItemColor(for kind: CelebrationXPItem.Kind) -> Color {
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

    // MARK: - Phase 4: Ticker & Level Bar

    private var tickerSection: some View {
        Group {
            if let celebration = viewModel.celebrationEvent, celebration.xpGained > 0 {
                VStack(spacing: 12) {
                    // Total XP ticker
                    Text("+\(tickerValue) XP")
                        .font(.title.bold().monospacedDigit())
                        .foregroundStyle(.orange)
                        .contentTransition(.numericText(value: Double(tickerValue)))
                        .opacity(showTicker ? 1 : 0)

                    // Level progress bar
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
                        }
                        .padding(.horizontal, 8)
                        .transition(.opacity)
                    }

                    // Level up announcement
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

    // MARK: - Phase 5: Loot & Teaser

    private var lootSection: some View {
        Group {
            if let celebration = viewModel.celebrationEvent, showLoot {
                VStack(spacing: 10) {
                    // Badge cards
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

                    // Achievement cards
                    ForEach(celebration.newAchievements) { achievement in
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

    private func lootCard(icon: String, iconColor: Color, title: String, description: String) -> some View {
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
    }

    private var teaserSection: some View {
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

    private func teaserText(_ teaser: CelebrationTeaser) -> Text {
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


    // MARK: - Animation Sequence

    private func startSequence() {
        if reduceMotion {
            setAllVisible()
            return
        }

        let celebration = viewModel.celebrationEvent
        let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
        let lightImpact = UIImpactFeedbackGenerator(style: .light)
        heavyImpact.prepare()
        lightImpact.prepare()

        // Phase 1: Arrival (0.0s–0.5s)
        heavyImpact.impactOccurred()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            showArrival = true
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.15)) {
            showCheckmark = true
        }
        withAnimation(.easeOut(duration: 0.3).delay(0.3)) {
            showHeadline = true
        }

        // Phase 2: Journey Header (0.5s–0.8s)
        withAnimation(.easeOut(duration: 0.3).delay(0.5)) {
            showJourneyHeader = true
        }

        // Phase 3: XP Breakdown (0.8s+)
        if let celebration {
            for (index, _) in celebration.xpItems.enumerated() {
                let delay = 0.8 + Double(index) * 0.1
                withAnimation(.easeOut(duration: 0.3).delay(delay)) {
                    showXPItems.insert(index)
                }
            }

            // Phase 4: Ticker & Level Bar
            let phase4Start = 0.8 + Double(celebration.xpItems.count) * 0.1 + 0.3
            startTicker(
                target: celebration.xpGained,
                levelProgress: celebration.levelProgress,
                startDelay: phase4Start,
                lightImpact: lightImpact,
                heavyImpact: heavyImpact
            )

            // Phase 5: Loot & Teaser
            let phase5Start = phase4Start + 1.2
            withAnimation(.spring(duration: 0.5).delay(phase5Start)) {
                showLoot = true
            }

            // Confetti on level-up
            if celebration.leveledUp {
                DispatchQueue.main.asyncAfter(deadline: .now() + phase5Start) {
                    showConfetti = true
                    heavyImpact.impactOccurred()
                }
            }

            withAnimation(.easeOut(duration: 0.3).delay(phase5Start + 0.3)) {
                showTeaser = true
            }
            withAnimation(.easeOut(duration: 0.3).delay(phase5Start + 0.5)) {
                showDone = true
            }
        } else {
            // No celebration event — just show done
            withAnimation(.easeOut(duration: 0.3).delay(1.0)) {
                showDone = true
            }
        }
    }

    private func startTicker(
        target: Int,
        levelProgress: CelebrationLevelProgress,
        startDelay: TimeInterval,
        lightImpact: UIImpactFeedbackGenerator,
        heavyImpact: UIImpactFeedbackGenerator
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + startDelay) {
            withAnimation(.easeOut(duration: 0.2)) {
                showTicker = true
                showLevelBar = true
            }

            // Set initial bar position (before state)
            let beforeFraction: CGFloat = if levelProgress.beforeXPToNext > 0 {
                CGFloat(levelProgress.beforeXPInLevel) / CGFloat(levelProgress.beforeXPToNext)
            } else {
                0
            }
            levelBarProgress = beforeFraction

            guard target > 0 else {
                tickerValue = target
                return
            }

            // Ticker animation
            let totalDuration: TimeInterval = 0.8
            let steps = min(target, 30)
            let interval = totalDuration / Double(steps)
            var currentStep = 0

            tickerTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
                currentStep += 1
                let progress = Double(currentStep) / Double(steps)
                let easedProgress = 1 - pow(1 - progress, 3) // ease-out cubic

                withAnimation(.linear(duration: interval)) {
                    tickerValue = Int(easedProgress * Double(target))
                }

                // Light haptic every 3rd tick
                if currentStep % 3 == 0 {
                    lightImpact.impactOccurred(intensity: 0.4)
                }

                // Animate level bar in sync
                let barTarget: CGFloat
                if levelProgress.leveledUp {
                    if progress < 0.5 {
                        // Fill to 100% of old level
                        barTarget = beforeFraction + (1.0 - beforeFraction) * CGFloat(progress / 0.5)
                    } else {
                        // Reset and fill new level
                        let newProgress = (progress - 0.5) / 0.5
                        let afterFraction: CGFloat = if levelProgress.afterXPToNext > 0 {
                            CGFloat(levelProgress.afterXPInLevel) / CGFloat(levelProgress.afterXPToNext)
                        } else {
                            0
                        }
                        barTarget = afterFraction * CGFloat(newProgress)

                        // Trigger level bounce at midpoint
                        if currentStep == steps / 2 + 1 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                                levelBounce = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation(.spring(response: 0.2)) {
                                    levelBounce = false
                                }
                            }
                            heavyImpact.impactOccurred()
                        }
                    }
                } else {
                    let afterFraction: CGFloat = if levelProgress.afterXPToNext > 0 {
                        CGFloat(levelProgress.afterXPInLevel) / CGFloat(levelProgress.afterXPToNext)
                    } else {
                        0
                    }
                    barTarget = beforeFraction + (afterFraction - beforeFraction) * CGFloat(easedProgress)
                }

                withAnimation(.linear(duration: interval)) {
                    levelBarProgress = barTarget
                }

                if currentStep >= steps {
                    timer.invalidate()
                    tickerTimer = nil
                    tickerValue = target
                }
            }
        }
    }

    private func setAllVisible() {
        showArrival = true
        showCheckmark = true
        showHeadline = true
        showJourneyHeader = true
        showTicker = true
        showLevelBar = true
        showLoot = true
        showTeaser = true
        showDone = true

        if let celebration = viewModel.celebrationEvent {
            for index in celebration.xpItems.indices {
                showXPItems.insert(index)
            }
            tickerValue = celebration.xpGained

            if celebration.levelProgress.afterXPToNext > 0 {
                levelBarProgress = CGFloat(celebration.levelProgress.afterXPInLevel)
                    / CGFloat(celebration.levelProgress.afterXPToNext)
            }
        }
    }
}
