import SwiftUI

// MARK: - Animation Sequence

extension TravelSuccessView {
    func startSequence() {
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
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { showArrival = true }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.15)) { showCheckmark = true }
        withAnimation(.easeOut(duration: 0.3).delay(0.3)) { showHeadline = true }

        // Phase 2: Journey Header (0.5s–0.8s)
        withAnimation(.easeOut(duration: 0.3).delay(0.5)) { showJourneyHeader = true }

        // Phase 3+: XP Breakdown, Ticker, Loot, Epic
        guard let celebration else {
            withAnimation(.easeOut(duration: 0.3).delay(1.0)) { showDone = true }
            return
        }

        for index in celebration.xpItems.indices {
            let delay = 0.8 + Double(index) * 0.1
            _ = withAnimation(.easeOut(duration: 0.3).delay(delay)) { showXPItems.insert(index) }
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

        // Phase 5: Loot & Confetti
        let phase5Start = phase4Start + 1.2
        withAnimation(.spring(duration: 0.5).delay(phase5Start)) { showLoot = true }

        if celebration.leveledUp {
            sequenceTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(phase5Start))
                guard !Task.isCancelled else { return }
                showConfetti = true
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
        }

        // Phase 6: Epic hidden achievement reveal or wrap up
        let hasHiddenAchievements = celebration.newAchievements.contains(where: \.isHidden)
        let phase6Start = phase5Start + (hasHiddenAchievements ? 0.6 : 0)

        if hasHiddenAchievements {
            epicRevealTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(phase6Start))
                guard !Task.isCancelled else { return }
                showEpicOverlay = true
            }
        } else {
            withAnimation(.easeOut(duration: 0.3).delay(phase6Start + 0.3)) { showTeaser = true }
            withAnimation(.easeOut(duration: 0.3).delay(phase6Start + 0.5)) { showDone = true }
        }
    }

    func startTicker(
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

            let totalDuration: TimeInterval = 0.8
            let steps = min(target, 30)
            let interval = totalDuration / Double(steps)

            for currentStep in 1 ... steps {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }

                let progress = Double(currentStep) / Double(steps)
                let easedProgress = 1 - pow(1 - progress, 3)

                withAnimation(.linear(duration: interval)) {
                    tickerValue = Int(easedProgress * Double(target))
                }

                if currentStep % 3 == 0 {
                    lightImpact.impactOccurred(intensity: 0.4)
                }

                let barTarget = levelBarTarget(
                    progress: progress,
                    easedProgress: easedProgress,
                    beforeFraction: beforeFraction,
                    levelProgress: levelProgress
                )

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

    func handleEpicDismissed() {
        withAnimation(.spring(duration: 0.5).delay(0.2)) {
            showEpicLoot = true
        }
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            epicShimmerPhase = 1
        }
        withAnimation(.easeOut(duration: 0.3).delay(0.8)) {
            showTeaser = true
        }
        withAnimation(.easeOut(duration: 0.3).delay(1.0)) {
            showDone = true
        }
    }

    func levelBarTarget(
        progress: Double,
        easedProgress: Double,
        beforeFraction: CGFloat,
        levelProgress: CelebrationLevelProgress
    ) -> CGFloat {
        if levelProgress.leveledUp {
            if progress < 0.5 {
                return beforeFraction + (1.0 - beforeFraction) * CGFloat(progress / 0.5)
            } else {
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

    func setAllVisible() {
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

            AccessibilityNotification.Announcement(String(
                localized: "Journey recorded. \(celebration.xpGained) XP earned.",
                comment: "Travel success accessibility: summary announcement for reduce motion"
            )).post()
        }
    }
}
