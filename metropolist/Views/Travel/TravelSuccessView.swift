// swiftlint:disable file_length
import SwiftUI
import TransitModels

// swiftlint:disable:next type_body_length
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
    // Epic overlay states
    @State private var showEpicOverlay = false
    @State private var epicOverlayBackdrop = false
    @State private var epicOverlayRings = false
    @State private var epicOverlayIcon = false
    @State private var epicOverlayLabel = false
    @State private var epicOverlayTitle = false
    @State private var epicOverlayXP = false
    @State private var epicGlowPulse = false
    @State private var showEpicDismissButton = false
    // Inline card after overlay dismisses
    @State private var showEpicLoot = false
    @State private var currentEpicIndex = 0
    @State private var epicShimmerPhase: CGFloat = 0
    @State private var showTeaser = false
    @State private var showDone = false

    @State private var tickerTask: Task<Void, Never>?
    @State private var sequenceTask: Task<Void, Never>?
    @State private var epicRevealTask: Task<Void, Never>?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var lineColor: Color {
        if let line = viewModel.selectedLine {
            Color(hex: line.color)
        } else {
            .accentColor
        }
    }

    private var regularAchievements: [AchievementDefinition] {
        viewModel.celebrationEvent?.newAchievements.filter { !$0.isHidden } ?? []
    }

    private var hiddenAchievements: [AchievementDefinition] {
        viewModel.celebrationEvent?.newAchievements.filter(\.isHidden) ?? []
    }

    private var currentEpicAchievement: AchievementDefinition? {
        guard currentEpicIndex < hiddenAchievements.count else { return nil }
        return hiddenAchievements[currentEpicIndex]
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

                // MARK: Phase 6 — Epic Hidden Achievement Reveal

                epicLootSection

                teaserSection

                Spacer().frame(height: 32)
            }
            .padding(.horizontal, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
        .overlay {
            if showEpicOverlay {
                epicFullScreenOverlay
                    .transition(.opacity)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.success, trigger: showCheckmark)
        .onAppear(perform: startSequence)
        .onDisappear {
            tickerTask?.cancel()
            sequenceTask?.cancel()
            epicRevealTask?.cancel()
        }
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

            if item.xpValue > 0 {
                Text("+\(item.xpValue) XP")
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

                    // Regular achievement cards (non-hidden only)
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

    // MARK: - Phase 6: Epic Hidden Achievement Reveal

    private var epicLootSection: some View {
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

    private func epicInlineCard(achievement: AchievementDefinition) -> some View {
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
    }

    // MARK: - Epic Full-Screen Overlay

    private var epicFullScreenOverlay: some View {
        ZStack {
            // Backdrop
            Color.black
                .opacity(epicOverlayBackdrop ? 0.9 : 0)
                .ignoresSafeArea()

            // Expanding rings
            ForEach(0 ..< 3, id: \.self) { ring in
                Circle()
                    .strokeBorder(
                        Color.yellow.opacity(epicOverlayRings ? 0 : 0.4),
                        lineWidth: 2
                    )
                    .frame(width: 100, height: 100)
                    .scaleEffect(epicOverlayRings ? 4.0 + CGFloat(ring) * 1.5 : 0.3)
            }

            // Center content
            VStack(spacing: 0) {
                Spacer()

                // Glow + icon
                ZStack {
                    // Pulsing glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.yellow.opacity(0.3), .orange.opacity(0.1), .clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(epicGlowPulse ? 1.15 : 0.85)
                        .opacity(epicOverlayIcon ? 1 : 0)

                    // Icon circle
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 96, height: 96)
                            .shadow(color: .yellow.opacity(0.6), radius: 20)

                        if let achievement = currentEpicAchievement {
                            Image(systemName: achievement.systemImage)
                                .font(.system(size: 40, weight: .bold))
                                .foregroundStyle(.white)
                                .symbolEffect(.bounce, value: epicOverlayIcon)
                        }
                    }
                    .scaleEffect(epicOverlayIcon ? 1 : 0)
                }

                Spacer().frame(height: 32)

                // Label
                Text(String(localized: "Secret Achievement Unlocked!", comment: "Travel success: secret achievement reveal label"))
                    .font(.caption.weight(.black))
                    .foregroundStyle(.yellow)
                    .textCase(.uppercase)
                    .tracking(2)
                    .opacity(epicOverlayLabel ? 1 : 0)
                    .scaleEffect(epicOverlayLabel ? 1 : 0.7)

                Spacer().frame(height: 20)

                // Achievement details
                if let achievement = currentEpicAchievement {
                    VStack(spacing: 8) {
                        Text(achievement.title)
                            .font(.title.bold())
                            .foregroundStyle(.white)

                        Text(achievement.description)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(epicOverlayTitle ? 1 : 0)
                    .offset(y: epicOverlayTitle ? 0 : 20)

                    Spacer().frame(height: 24)

                    // XP reward
                    Text("+\(achievement.xpReward) XP")
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(.orange)
                        .opacity(epicOverlayXP ? 1 : 0)
                        .scaleEffect(epicOverlayXP ? 1 : 0.5)
                }

                Spacer().frame(height: 40)

                // Dismiss button
                if showEpicDismissButton {
                    Button {
                        dismissEpicOverlay()
                    } label: {
                        Text(String(localized: "Continue", comment: "Travel success: dismiss secret achievement overlay"))
                            .font(.headline)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(.yellow, in: Capsule())
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()
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
            for index in celebration.xpItems.indices {
                let delay = 0.8 + Double(index) * 0.1
                _ = withAnimation(.easeOut(duration: 0.3).delay(delay)) {
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
                sequenceTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(phase5Start))
                    guard !Task.isCancelled else { return }
                    showConfetti = true
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                }
            }

            // Phase 6: Epic hidden achievement reveal
            let hasHiddenAchievements = celebration.newAchievements.contains(where: \.isHidden)
            let phase6Start = phase5Start + (hasHiddenAchievements ? 0.6 : 0)

            if hasHiddenAchievements {
                startEpicReveal(at: phase6Start)
                // Teaser + done are triggered by dismissEpicOverlay()
            } else {
                withAnimation(.easeOut(duration: 0.3).delay(phase6Start + 0.3)) {
                    showTeaser = true
                }
                withAnimation(.easeOut(duration: 0.3).delay(phase6Start + 0.5)) {
                    showDone = true
                }
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
        tickerTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(startDelay))
            guard !Task.isCancelled else { return }

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

            for currentStep in 1 ... steps {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }

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
                let barTarget = levelBarTarget(
                    progress: progress,
                    easedProgress: easedProgress,
                    beforeFraction: beforeFraction,
                    levelProgress: levelProgress
                )

                // Trigger level bounce at midpoint
                if levelProgress.leveledUp, progress >= 0.5, currentStep == steps / 2 + 1 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                        levelBounce = true
                    }
                    try? await Task.sleep(for: .seconds(0.3))
                    withAnimation(.spring(response: 0.2)) {
                        levelBounce = false
                    }
                    heavyImpact.impactOccurred()
                }

                withAnimation(.linear(duration: interval)) {
                    levelBarProgress = barTarget
                }
            }

            tickerValue = target
        }
    }

    private func startEpicReveal(at startTime: TimeInterval) {
        epicRevealTask = Task { @MainActor in
            // t+0.0: Show overlay + backdrop fade
            try? await Task.sleep(for: .seconds(startTime))
            guard !Task.isCancelled else { return }
            showEpicOverlay = true
            withAnimation(.easeIn(duration: 0.4)) {
                epicOverlayBackdrop = true
            }

            // Wait for backdrop animation before content
            try? await Task.sleep(for: .seconds(0.4))
            guard !Task.isCancelled else { return }
            await runEpicRevealContent()
        }
    }

    private func runEpicRevealContent() async {
        // t+0.0: Expanding rings burst outward
        withAnimation(.easeOut(duration: 1.2)) {
            epicOverlayRings = true
        }

        // t+0.1: Icon slams in with heavy haptic
        try? await Task.sleep(for: .seconds(0.1))
        guard !Task.isCancelled else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
            epicOverlayIcon = true
        }
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            epicGlowPulse = true
        }

        // t+0.6: "SECRET ACHIEVEMENT UNLOCKED!" label
        try? await Task.sleep(for: .seconds(0.5))
        guard !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            epicOverlayLabel = true
        }

        // t+0.9: Achievement title + description
        try? await Task.sleep(for: .seconds(0.3))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.4)) {
            epicOverlayTitle = true
        }

        // t+1.2: XP reward + confetti
        try? await Task.sleep(for: .seconds(0.3))
        guard !Task.isCancelled else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            epicOverlayXP = true
        }
        showConfetti = false
        try? await Task.sleep(for: .milliseconds(10))
        guard !Task.isCancelled else { return }
        showConfetti = true

        // t+2.0: Show dismiss button
        try? await Task.sleep(for: .seconds(0.8))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            showEpicDismissButton = true
        }
    }

    private func dismissEpicOverlay() {
        let hasMore = currentEpicIndex + 1 < hiddenAchievements.count

        // Cancel any pending reveal sequence
        epicRevealTask?.cancel()

        // Fade out current content
        withAnimation(.easeIn(duration: 0.3)) {
            epicOverlayRings = false
            epicOverlayIcon = false
            epicOverlayLabel = false
            epicOverlayTitle = false
            epicOverlayXP = false
            epicGlowPulse = false
            showEpicDismissButton = false
        }

        if hasMore {
            // Advance to next achievement and re-animate content
            epicRevealTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.4))
                guard !Task.isCancelled else { return }
                currentEpicIndex += 1
                await runEpicRevealContent()
            }
        } else {
            // Final dismiss — collapse entire overlay
            withAnimation(.easeIn(duration: 0.5)) {
                epicOverlayBackdrop = false
            }

            epicRevealTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.5))
                guard !Task.isCancelled else { return }
                showEpicOverlay = false
            }

            // Inline cards spring in as overlay fades
            withAnimation(.spring(duration: 0.5).delay(0.2)) {
                showEpicLoot = true
            }

            // Start shimmer on inline cards
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                epicShimmerPhase = 1
            }

            // Show teaser + done after dismiss
            withAnimation(.easeOut(duration: 0.3).delay(0.8)) {
                showTeaser = true
            }
            withAnimation(.easeOut(duration: 0.3).delay(1.0)) {
                showDone = true
            }
        }
    }

    private func levelBarTarget(
        progress: Double,
        easedProgress: Double,
        beforeFraction: CGFloat,
        levelProgress: CelebrationLevelProgress
    ) -> CGFloat {
        if levelProgress.leveledUp {
            if progress < 0.5 {
                // Fill to 100% of old level
                return beforeFraction + (1.0 - beforeFraction) * CGFloat(progress / 0.5)
            } else {
                // Reset and fill new level
                let newProgress = (progress - 0.5) / 0.5
                let afterFraction: CGFloat = if levelProgress.afterXPToNext > 0 {
                    CGFloat(levelProgress.afterXPInLevel) / CGFloat(levelProgress.afterXPToNext)
                } else {
                    0
                }
                return afterFraction * CGFloat(newProgress)
            }
        } else {
            let afterFraction: CGFloat = if levelProgress.afterXPToNext > 0 {
                CGFloat(levelProgress.afterXPInLevel) / CGFloat(levelProgress.afterXPToNext)
            } else {
                0
            }
            return beforeFraction + (afterFraction - beforeFraction) * CGFloat(easedProgress)
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
        showEpicLoot = true
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
