import SwiftUI

// MARK: - Wrapped Hero Page

struct WrappedHeroPage: View {
    let viewModel: YearlyRecapViewModel
    let animationPhase: Int

    private var gradientColors: [Color] {
        let colors = viewModel.accentGradient
        guard colors.count >= 2 else { return [viewModel.accentColor.opacity(0.6), .black] }
        return colors.map { $0.opacity(0.5) } + [.black]
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: gradientColors, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            FloatingShapesBackground(color: viewModel.accentColor, shapeCount: 5)

            VStack(spacing: 16) {
                Text(viewModel.formattedYear)
                    .font(.system(size: 80, weight: .black))
                    .foregroundStyle(.white)
                    .scaleEffect(animationPhase >= 2 ? 1 : 0.3)
                    .opacity(animationPhase >= 2 ? 1 : 0)

                Text(String(localized: "Your year on the network", comment: "Wrapped hero: tagline"))
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .opacity(animationPhase >= 3 ? 1 : 0)
                    .offset(y: animationPhase >= 3 ? 0 : 20)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: -40)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Wrapped Numbers Page

struct WrappedNumbersPage: View {
    let viewModel: YearlyRecapViewModel
    let snapshot: YearlySnapshot
    let previous: YearlySnapshot?
    let animationPhase: Int

    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 88
    @State private var displayedCount = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.black, viewModel.accentColor.opacity(0.3), .black],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Text(String(localized: "YEAR IN NUMBERS", comment: "Wrapped numbers: section heading"))
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(3)
                    .opacity(animationPhase >= 1 ? 1 : 0)

                VStack(spacing: 4) {
                    Text("\(displayedCount)", comment: "Wrapped numbers: animated travel count")
                        .font(.system(size: min(numberSize, 96), weight: .heavy).monospacedDigit())
                        .foregroundStyle(viewModel.accentColor)
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.6)
                    Text(String(localized: "travels", comment: "Wrapped numbers: label below travel count"))
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .opacity(animationPhase >= 2 ? 1 : 0)

                if let previous {
                    NumbersDeltaPill(current: snapshot.totalTravels, previous: previous.totalTravels)
                        .opacity(animationPhase >= 3 ? 1 : 0)
                }

                numbersStatsRow
                    .opacity(animationPhase >= 4 ? 1 : 0)
                    .offset(y: animationPhase >= 4 ? 0 : 20)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: -30)
        }
        .onChange(of: animationPhase) {
            if animationPhase >= 2 {
                animateCounter()
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var numbersStatsRow: some View {
        HStack(spacing: 0) {
            StoryMiniStat(
                icon: "mappin.and.ellipse",
                value: snapshot.totalDiscoveries.count,
                label: String(localized: "Discoveries", comment: "Wrapped numbers: discoveries count")
            )
            StoryMiniStat(
                icon: "calendar",
                value: snapshot.totalActiveDays,
                label: String(localized: "Active days", comment: "Wrapped numbers: active days count")
            )
            StoryMiniStat(
                icon: "tram.fill",
                value: snapshot.totalNewLines.count,
                label: String(localized: "New lines", comment: "Wrapped numbers: new lines explored count")
            )
        }
    }

    private func animateCounter() {
        let target = snapshot.totalTravels
        guard target > 0 else {
            displayedCount = 0
            return
        }
        let steps = min(target, 20)
        let interval = 0.6 / Double(steps)
        for step in 1 ... steps {
            let value = Int(Double(target) * Double(step) / Double(steps))
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(Int(interval * 1000) * step))
                withAnimation(.easeOut(duration: interval)) {
                    displayedCount = value
                }
            }
        }
    }
}

// MARK: - Best Month Page

struct WrappedBestMonthPage: View {
    let viewModel: YearlyRecapViewModel
    let snapshot: YearlySnapshot
    let animationPhase: Int

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [viewModel.accentColor.opacity(0.4), .black],
                startPoint: .topTrailing, endPoint: .bottomLeading
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Text(String(localized: "BEST MONTH", comment: "Wrapped best month: section heading"))
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(3)
                    .opacity(animationPhase >= 1 ? 1 : 0)

                VStack(spacing: 8) {
                    Text(viewModel.resolvedBestMonth)
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(.white)
                    Text(
                        "\(snapshot.monthRankings.first?.1 ?? 0) travels",
                        comment: "Wrapped best month: travel count"
                    )
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
                }
                .opacity(animationPhase >= 2 ? 1 : 0)
                .scaleEffect(animationPhase >= 2 ? 1 : 0.8)

                miniBarChart
                    .opacity(animationPhase >= 3 ? 1 : 0)
                    .offset(y: animationPhase >= 3 ? 0 : 20)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: -20)
        }
        .accessibilityElement(children: .combine)
    }

    private var miniBarChart: some View {
        let rankings = snapshot.monthRankings
        let maxCount = rankings.first?.1 ?? 1

        return HStack(alignment: .bottom, spacing: 4) {
            ForEach(sortedMonthsChronologically(), id: \.0) { month, count in
                let isBest = month == snapshot.bestMonth
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isBest ? viewModel.accentColor : Color.white.opacity(0.3))
                        .frame(height: max(4, CGFloat(count) / CGFloat(maxCount) * 80))
                    Text(MonthFormatting.abbreviatedMonth(month))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(isBest ? .white : .white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 100)
        .padding(.horizontal, 8)
    }

    private func sortedMonthsChronologically() -> [(DateComponents, Int)] {
        snapshot.monthRankings.sorted { lhs, rhs in
            guard let lhsMonth = lhs.0.month, let rhsMonth = rhs.0.month else { return false }
            return lhsMonth < rhsMonth
        }
    }
}

// MARK: - Month Rankings Page

struct WrappedRankingsPage: View {
    let viewModel: YearlyRecapViewModel
    let animationPhase: Int

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.black, viewModel.accentColor.opacity(0.2), .black],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Text(String(localized: "MONTH RANKINGS", comment: "Wrapped rankings: section heading"))
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(3)
                    .opacity(animationPhase >= 1 ? 1 : 0)

                rankingsList
                    .opacity(animationPhase >= 2 ? 1 : 0)
                    .offset(y: animationPhase >= 2 ? 0 : 20)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: -20)
        }
        .accessibilityElement(children: .combine)
    }

    private var rankingsList: some View {
        let top5 = Array(viewModel.resolvedMonthRankings.prefix(5))
        return VStack(spacing: 10) {
            ForEach(Array(top5.enumerated()), id: \.offset) { index, entry in
                HStack(spacing: 12) {
                    Text("#\(index + 1)", comment: "Wrapped rankings: rank number prefix")
                        .font(.headline.bold().monospacedDigit())
                        .foregroundStyle(index == 0 ? viewModel.accentColor : .white.opacity(0.6))
                        .frame(width: 36, alignment: .leading)

                    Text(entry.0)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)

                    Spacer()

                    Text("\(entry.1)", comment: "Wrapped rankings: travel count for ranked month")
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    index == 0 ? viewModel.accentColor.opacity(0.15) : Color.white.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 10)
                )
            }
        }
    }
}

// MARK: - Top Line Page

struct WrappedTopLinePage: View {
    let viewModel: YearlyRecapViewModel
    let animationPhase: Int

    @ScaledMetric(relativeTo: .largeTitle) private var lineNameSize: CGFloat = 96

    var body: some View {
        ZStack {
            let lineColor = viewModel.resolvedTopLine?.color ?? viewModel.accentColor
            LinearGradient(
                colors: [lineColor.opacity(0.5), lineColor.opacity(0.15), .black.opacity(0.95)],
                startPoint: .bottom, endPoint: .top
            )
            .ignoresSafeArea()
            FloatingShapesBackground(color: lineColor, shapeCount: 3)

            if let topLine = viewModel.resolvedTopLine {
                VStack(spacing: 16) {
                    Text(
                        "YOUR #1 LINE OF \(viewModel.formattedYear)",
                        comment: "Wrapped top line: heading with year"
                    )
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(3)
                    .opacity(animationPhase >= 1 ? 1 : 0)

                    Text(topLine.shortName)
                        .font(.system(size: min(lineNameSize, 104), weight: .black))
                        .foregroundStyle(topLine.color)
                        .shadow(color: topLine.color.opacity(0.5), radius: 20)
                        .minimumScaleFactor(0.5)
                        .scaleEffect(animationPhase >= 2 ? 1 : 0.3)
                        .opacity(animationPhase >= 2 ? 1 : 0)

                    Text(
                        "\(topLine.travelCount) travels this year",
                        comment: "Wrapped top line: travel count"
                    )
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))
                    .opacity(animationPhase >= 3 ? 1 : 0)
                    .offset(y: animationPhase >= 3 ? 0 : 20)
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(y: -40)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
