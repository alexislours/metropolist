import SwiftUI

struct EpicAchievementOverlay: View {
    let achievements: [AchievementDefinition]
    @Binding var isPresented: Bool
    @Binding var showConfetti: Bool
    let onAllDismissed: () -> Void

    @State private var backdropVisible = false
    @State private var ringsExpanded = false
    @State private var iconVisible = false
    @State private var labelVisible = false
    @State private var titleVisible = false
    @State private var xpVisible = false
    @State private var glowPulse = false
    @State private var dismissButtonVisible = false
    @State private var currentIndex = 0
    @State private var revealTask: Task<Void, Never>?

    private var currentAchievement: AchievementDefinition? {
        guard currentIndex < achievements.count else { return nil }
        return achievements[currentIndex]
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(backdropVisible ? 0.9 : 0)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            ForEach(0 ..< 3, id: \.self) { ring in
                Circle()
                    .strokeBorder(
                        Color.yellow.opacity(ringsExpanded ? 0 : 0.4),
                        lineWidth: 2
                    )
                    .frame(width: 100, height: 100)
                    .scaleEffect(ringsExpanded ? 4.0 + CGFloat(ring) * 1.5 : 0.3)
            }
            .accessibilityHidden(true)

            VStack(spacing: 0) {
                Spacer()

                ZStack {
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
                        .scaleEffect(glowPulse ? 1.15 : 0.85)
                        .opacity(iconVisible ? 1 : 0)

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

                        if let achievement = currentAchievement {
                            Image(systemName: achievement.systemImage)
                                .font(.system(size: 40, weight: .bold))
                                .foregroundStyle(.white)
                                .symbolEffect(.bounce, value: iconVisible)
                        }
                    }
                    .scaleEffect(iconVisible ? 1 : 0)
                }
                .accessibilityHidden(true)

                Spacer().frame(height: 32)

                Text(String(localized: "Secret Achievement Unlocked!", comment: "Travel success: secret achievement reveal label"))
                    .font(.caption.weight(.black))
                    .foregroundStyle(.yellow)
                    .textCase(.uppercase)
                    .tracking(2)
                    .opacity(labelVisible ? 1 : 0)
                    .scaleEffect(labelVisible ? 1 : 0.7)

                Spacer().frame(height: 20)

                if let achievement = currentAchievement {
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
                    .opacity(titleVisible ? 1 : 0)
                    .offset(y: titleVisible ? 0 : 20)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("\(achievement.title), \(achievement.description)"))

                    Spacer().frame(height: 24)

                    Text("+\(achievement.xpReward) XP")
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(.orange)
                        .opacity(xpVisible ? 1 : 0)
                        .scaleEffect(xpVisible ? 1 : 0.5)
                }

                Spacer().frame(height: 40)

                if dismissButtonVisible {
                    Button {
                        dismissOverlay()
                    } label: {
                        Text(String(localized: "Continue", comment: "Travel success: dismiss secret achievement overlay"))
                            .font(.headline)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(.yellow, in: Capsule())
                    }
                    .accessibilityIdentifier("button-continue")
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()
            }
        }
        .accessibilityAddTraits(.isModal)
        .onAppear(perform: startRevealSequence)
        .onDisappear { revealTask?.cancel() }
    }

    // MARK: - Animation Sequence

    private func startRevealSequence() {
        revealTask = Task { @MainActor in
            withAnimation(.easeIn(duration: 0.4)) {
                backdropVisible = true
            }

            try? await Task.sleep(for: .seconds(0.4))
            guard !Task.isCancelled else { return }
            await runRevealContent()
        }
    }

    private func runRevealContent() async {
        withAnimation(.easeOut(duration: 1.2)) {
            ringsExpanded = true
        }

        try? await Task.sleep(for: .seconds(0.1))
        guard !Task.isCancelled else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
            iconVisible = true
        }
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            glowPulse = true
        }

        try? await Task.sleep(for: .seconds(0.5))
        guard !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            labelVisible = true
        }

        try? await Task.sleep(for: .seconds(0.3))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.4)) {
            titleVisible = true
        }

        try? await Task.sleep(for: .seconds(0.3))
        guard !Task.isCancelled else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            xpVisible = true
        }
        showConfetti = false
        try? await Task.sleep(for: .milliseconds(10))
        guard !Task.isCancelled else { return }
        showConfetti = true

        try? await Task.sleep(for: .seconds(0.8))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            dismissButtonVisible = true
        }
    }

    private func dismissOverlay() {
        let hasMore = currentIndex + 1 < achievements.count

        revealTask?.cancel()

        withAnimation(.easeIn(duration: 0.3)) {
            ringsExpanded = false
            iconVisible = false
            labelVisible = false
            titleVisible = false
            xpVisible = false
            glowPulse = false
            dismissButtonVisible = false
        }

        if hasMore {
            revealTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.4))
                guard !Task.isCancelled else { return }
                currentIndex += 1
                await runRevealContent()
            }
        } else {
            onAllDismissed()

            withAnimation(.easeIn(duration: 0.5)) {
                backdropVisible = false
            }

            revealTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.5))
                guard !Task.isCancelled else { return }
                isPresented = false
            }
        }
    }
}
