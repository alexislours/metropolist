import SwiftUI

// MARK: - Superlatives Page

struct WrappedSuperlativesPage: View {
    let viewModel: YearlyRecapViewModel
    let snapshot: YearlySnapshot
    let animationPhase: Int

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.purple.opacity(0.2), viewModel.accentColor.opacity(0.15), .black],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Text(String(localized: "YOUR RECORDS", comment: "Wrapped superlatives: heading"))
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(3)
                    .opacity(animationPhase >= 1 ? 1 : 0)

                VStack(spacing: 12) {
                    if snapshot.busiestDay.1 > 0 {
                        superlativeCard(
                            icon: "flame.fill",
                            title: String(localized: "Busiest Day", comment: "Superlative: busiest day label"),
                            value: "\(snapshot.busiestDay.1) travels",
                            detail: viewModel.resolvedBusiestDay
                        )
                    }

                    if snapshot.longestStreak.length > 1 {
                        superlativeCard(
                            icon: "bolt.fill",
                            title: String(localized: "Longest Streak", comment: "Superlative: longest streak label"),
                            value: "\(snapshot.longestStreak.length) days",
                            detail: viewModel.resolvedStreakRange
                        )
                    }

                    if snapshot.mostLinesInADay.1 > 0 {
                        superlativeCard(
                            icon: "rectangle.stack.fill",
                            title: String(
                                localized: "Most Lines in a Day",
                                comment: "Superlative: most lines in a day label"
                            ),
                            value: "\(snapshot.mostLinesInADay.1) lines",
                            detail: viewModel.resolvedMostLinesDay
                        )
                    }

                    if snapshot.mostStationsInADay.1 > 0 {
                        superlativeCard(
                            icon: "mappin.and.ellipse",
                            title: String(
                                localized: "Most Stations in a Day",
                                comment: "Superlative: most stations in a day label"
                            ),
                            value: "\(snapshot.mostStationsInADay.1) stations",
                            detail: viewModel.resolvedMostStationsDay
                        )
                    }

                    if viewModel.mostDistanceDayMeters > 0 {
                        superlativeCard(
                            icon: "point.bottomleft.forward.to.point.topright.scurvepath.fill",
                            title: String(
                                localized: "Most Distance in a Day",
                                comment: "Superlative: most distance traveled in a day label"
                            ),
                            value: DistanceCalculator.formatDistance(viewModel.mostDistanceDayMeters),
                            detail: viewModel.resolvedMostDistanceDay
                        )
                    }
                }
                .opacity(animationPhase >= 2 ? 1 : 0)
                .offset(y: animationPhase >= 2 ? 0 : 20)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: -20)
        }
        .accessibilityElement(children: .combine)
    }

    private func superlativeCard(icon: String, title: String, value: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.yellow)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Text(value)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Wrapped Summary Page

struct WrappedSummaryPage: View {
    let viewModel: YearlyRecapViewModel
    let snapshot: YearlySnapshot
    let animationPhase: Int
    let onClose: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var summaryNumberSize: CGFloat = 72
    @State private var showConfetti = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var gradientColors: [Color] {
        let colors = viewModel.accentGradient
        guard colors.count >= 2 else {
            return [viewModel.accentColor.opacity(0.5), .purple.opacity(0.15), .black]
        }
        return colors.map { $0.opacity(0.4) } + [.black]
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            FloatingShapesBackground(color: viewModel.accentColor, shapeCount: 5)

            VStack(spacing: 20) {
                Text(String(localized: "END OF THE LINE", comment: "Wrapped summary: section heading"))
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(4)
                    .opacity(animationPhase >= 1 ? 1 : 0)

                summaryHeading
                    .opacity(animationPhase >= 2 ? 1 : 0)

                summaryTravelCount
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

    private var summaryHeading: some View {
        Text(
            "That's a wrap on \(viewModel.formattedYear)",
            comment: "Wrapped summary: heading for completed year"
        )
        .font(.largeTitle.bold())
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
    }

    private var summaryTravelCount: some View {
        VStack(spacing: 4) {
            Text("\(snapshot.totalTravels)", comment: "Wrapped summary: total travel count for the year")
                .font(
                    .system(size: min(summaryNumberSize, 80), weight: .heavy)
                        .monospacedDigit()
                )
                .foregroundStyle(viewModel.accentColor)
                .minimumScaleFactor(0.6)
            Text(String(localized: "travels", comment: "Wrapped summary: label below travel count"))
                .font(.title3)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
