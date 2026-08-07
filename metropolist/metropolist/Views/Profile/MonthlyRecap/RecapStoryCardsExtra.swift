import SwiftUI

// MARK: - Distance Story Page

struct DistanceStoryPage: View {
    let viewModel: MonthlyRecapViewModel
    let animationPhase: Int

    @ScaledMetric(relativeTo: .largeTitle) private var distanceSize: CGFloat = 64

    var body: some View {
        ZStack {
            StoryBackground(page: .distance, color: viewModel.accentColor)
            FloatingShapesBackground(color: .teal, shapeCount: 3)

            VStack(spacing: 20) {
                Text(String(localized: "DISTANCE COVERED", comment: "Story distance page: section heading"))
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(3)
                    .opacity(animationPhase >= 1 ? 1 : 0)

                Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.teal)
                    .scaleEffect(animationPhase >= 2 ? 1 : 0.3)
                    .opacity(animationPhase >= 2 ? 1 : 0)

                VStack(spacing: 6) {
                    Text(DistanceCalculator.formatDistance(viewModel.totalDistance))
                        .font(
                            .system(
                                size: min(distanceSize, 72),
                                weight: .heavy
                            )
                        )
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                    Text(
                        String(
                            localized: "traveled this month",
                            comment: "Story distance page: label below distance"
                        )
                    )
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                }
                .opacity(animationPhase >= 3 ? 1 : 0)
                .scaleEffect(animationPhase >= 3 ? 1 : 0.8)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: -30)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Leveled Up Story Page

struct LeveledUpStoryPage: View {
    let viewModel: MonthlyRecapViewModel
    let animationPhase: Int

    @State private var showConfetti = false
    @State private var confettiTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            StoryBackground(page: .leveledUp, color: viewModel.accentColor)
            FloatingShapesBackground(color: .yellow, shapeCount: 4)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundStyle(.yellow)
                        .scaleEffect(animationPhase >= 1 ? 1 : 0.3)
                        .opacity(animationPhase >= 1 ? 1 : 0)

                    Text(String(localized: "LEVELED UP", comment: "Story leveled up page: section heading"))
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(3)
                        .opacity(animationPhase >= 2 ? 1 : 0)

                    Text("You leveled up", comment: "Leveled up story page subtitle")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .opacity(animationPhase >= 3 ? 1 : 0)

                    upgradesList
                        .opacity(animationPhase >= 4 ? 1 : 0)
                        .offset(y: animationPhase >= 4 ? 0 : 20)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
                .padding(.vertical, 80)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDisabled(true)

            if !reduceMotion {
                ConfettiView(isActive: showConfetti, color: .yellow)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            }
        }
        .onChange(of: animationPhase) {
            if animationPhase >= 4 {
                confettiTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    showConfetti = true
                }
            }
        }
        .onDisappear { confettiTask?.cancel() }
        .accessibilityElement(children: .combine)
    }

    private var upgradesList: some View {
        let displayUpgrades = Array(viewModel.resolvedBadgeUpgrades.prefix(8))
        let remaining = viewModel.resolvedBadgeUpgrades.count - displayUpgrades.count

        return VStack(spacing: 10) {
            ForEach(displayUpgrades, id: \.lineSourceID) { upgrade in
                upgradeRow(upgrade)
            }

            if remaining > 0 {
                Text(String(
                    localized: "+\(remaining) more",
                    comment: "Leveled up: remaining upgrades count"
                ))
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 4)
            }
        }
    }

    private func upgradeRow(_ upgrade: ResolvedBadgeUpgrade) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(upgrade.lineColor)
                .frame(width: 4)
                .padding(.trailing, 10)

            Text(upgrade.shortName)
                .font(.caption2.bold())
                .foregroundStyle(upgrade.lineTextColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .frame(minWidth: 32, minHeight: 24)
                .background(upgrade.lineColor, in: RoundedRectangle(cornerRadius: 4))

            Spacer()

            Text(upgrade.newTier.label)
                .font(.caption.bold())
                .foregroundStyle(upgrade.newTier.color)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Summary Story Page

struct SummaryStoryPage: View {
    let viewModel: MonthlyRecapViewModel
    let snapshot: MonthlySnapshot
    let animationPhase: Int
    let onClose: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var summaryNumberSize: CGFloat = 72
    @State private var showConfetti = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            StoryBackground(page: .summary, color: viewModel.accentColor)
            FloatingShapesBackground(color: viewModel.accentColor, shapeCount: 5)

            VStack(spacing: 20) {
                Text(String(localized: "END OF THE LINE", comment: "Story summary page: section heading"))
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(4)
                    .opacity(animationPhase >= 1 ? 1 : 0)

                Text(viewModel.formattedMonth)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .opacity(animationPhase >= 2 ? 1 : 0)

                VStack(spacing: 4) {
                    Text("\(snapshot.travelCount)")
                        .font(
                            .system(size: min(summaryNumberSize, 80), weight: .heavy)
                                .monospacedDigit()
                        )
                        .foregroundStyle(viewModel.accentColor)
                        .minimumScaleFactor(0.6)
                    Text(String(localized: "travels", comment: "Story summary page: label below travel count"))
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .opacity(animationPhase >= 3 ? 1 : 0)

                Button(action: onClose) {
                    Text(String(localized: "Close", comment: "Story: close button"))
                        .font(.headline)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(.white, in: Capsule())
                }
                .opacity(animationPhase >= 4 ? 1 : 0)
                .padding(.top, 16)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: -20)

            if !reduceMotion {
                ConfettiView(isActive: showConfetti, color: viewModel.accentColor)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            }
        }
        .onChange(of: animationPhase) {
            if animationPhase >= 2 {
                showConfetti = true
            }
        }
        .accessibilityElement(children: .combine)
    }
}
