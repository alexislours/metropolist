import SwiftUI

// MARK: - Hero Story Page

struct HeroStoryPage: View {
    let viewModel: MonthlyRecapViewModel
    let snapshot: MonthlySnapshot
    let animationPhase: Int

    var body: some View {
        ZStack {
            StoryBackground(page: .hero, color: viewModel.accentColor)
            FloatingShapesBackground(color: viewModel.accentColor, shapeCount: 4)

            if let mode = viewModel.dominantMode {
                Image(systemName: mode.systemImage)
                    .font(.system(size: 160))
                    .foregroundStyle(.white.opacity(0.06))
                    .offset(x: 40, y: 80)
                    .scaleEffect(animationPhase >= 3 ? 1 : 0.5)
                    .opacity(animationPhase >= 3 ? 1 : 0)
            }

            VStack(spacing: 12) {
                Text(viewModel.formattedMonth)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))
                    .opacity(animationPhase >= 1 ? 1 : 0)
                    .offset(y: animationPhase >= 1 ? 0 : 20)

                Text(RecapCopy.heroTagline(snapshot))
                    .font(.system(size: 38, weight: .black))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .opacity(animationPhase >= 2 ? 1 : 0)
                    .offset(y: animationPhase >= 2 ? 0 : 30)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: -40)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Numbers Story Page

struct NumbersStoryPage: View {
    let viewModel: MonthlyRecapViewModel
    let snapshot: MonthlySnapshot
    let previous: MonthlySnapshot?
    let animationPhase: Int

    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 88
    @State private var displayedCount = 0

    var body: some View {
        ZStack {
            StoryBackground(page: .numbers, color: viewModel.accentColor)

            VStack(spacing: 24) {
                Text(String(localized: "BY THE NUMBERS", comment: "Story numbers page: section heading"))
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(3)
                    .opacity(animationPhase >= 1 ? 1 : 0)

                VStack(spacing: 4) {
                    Text("\(displayedCount)")
                        .font(.system(size: min(numberSize, 96), weight: .heavy).monospacedDigit())
                        .foregroundStyle(viewModel.accentColor)
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.6)
                    Text(String(localized: "travels", comment: "Story numbers page: label below travel count"))
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .opacity(animationPhase >= 2 ? 1 : 0)

                if let previous {
                    NumbersDeltaPill(current: snapshot.travelCount, previous: previous.travelCount)
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
                value: snapshot.uniqueStationsDiscovered.count,
                label: String(localized: "New stations", comment: "Story numbers page: new stations discovered count")
            )
            StoryMiniStat(
                icon: "calendar",
                value: snapshot.activeDays,
                label: String(localized: "Active days", comment: "Story numbers page: days with at least one travel")
            )
            StoryMiniStat(
                icon: "flame.fill",
                value: snapshot.bestStreak,
                label: String(localized: "Best streak", comment: "Story numbers page: longest consecutive travel days")
            )
        }
    }

    private func animateCounter() {
        let target = snapshot.travelCount
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

// MARK: - Discoveries Story Page

struct DiscoveriesStoryPage: View {
    let viewModel: MonthlyRecapViewModel
    let animationPhase: Int

    @ScaledMetric(relativeTo: .largeTitle) private var stationCountSize: CGFloat = 64

    private var discoveries: ResolvedDiscoveries {
        viewModel.resolvedDiscoveries
    }

    var body: some View {
        ZStack {
            StoryBackground(page: .discoveries, color: viewModel.accentColor)
            FloatingShapesBackground(color: viewModel.accentColor, shapeCount: 3)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    Text(String(localized: "DISCOVERIES", comment: "Story discoveries page: section heading"))
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(3)
                        .opacity(animationPhase >= 1 ? 1 : 0)

                    if !discoveries.newStations.isEmpty {
                        stationCountHero
                            .opacity(animationPhase >= 2 ? 1 : 0)
                            .scaleEffect(animationPhase >= 2 ? 1 : 0.6)
                    }

                    if !discoveries.newLines.isEmpty {
                        linesGrid
                            .opacity(animationPhase >= 3 ? 1 : 0)
                            .offset(y: animationPhase >= 3 ? 0 : 20)
                    }

                    if !discoveries.newStations.isEmpty {
                        stationsList
                            .opacity(animationPhase >= 4 ? 1 : 0)
                            .offset(y: animationPhase >= 4 ? 0 : 15)
                    }
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 80)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDisabled(true)
        }
        .accessibilityElement(children: .combine)
    }

    private var stationCountHero: some View {
        VStack(spacing: 6) {
            Text("\(discoveries.newStations.count)")
                .font(.system(size: min(stationCountSize, 72), weight: .heavy).monospacedDigit())
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
            Text(String(localized: "new stops discovered", comment: "Story discoveries page: label below new station count"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var linesGrid: some View {
        VStack(spacing: 10) {
            Text(String(localized: "New Lines", comment: "Story discoveries page: new lines subsection heading"))
                .font(.caption.weight(.black))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(2)

            FlowLayout(spacing: 8) {
                ForEach(discoveries.newLines) { line in
                    Text(line.shortName)
                        .font(.footnote.bold())
                        .foregroundStyle(line.textColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(minWidth: 36, minHeight: 28)
                        .background(line.color, in: RoundedRectangle(cornerRadius: 8))
                        .shadow(color: line.color.opacity(0.4), radius: 8, y: 2)
                }
            }
        }
    }

    private var stationsList: some View {
        VStack(spacing: 6) {
            Text(String(localized: "New Stops", comment: "Story discoveries page: new stops subsection heading"))
                .font(.caption.weight(.black))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            let displayStations = Array(discoveries.newStations.prefix(8))
            let remaining = discoveries.newStations.count - displayStations.count

            VStack(spacing: 0) {
                ForEach(displayStations) { station in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(viewModel.accentColor)
                            .frame(width: 6, height: 6)
                        Text(station.name)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                }

                if remaining > 0 {
                    Text(String(
                        localized: "+\(remaining) more",
                        comment: "Discoveries: remaining station count"
                    ))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                }
            }
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Top Line Story Page

struct TopLineStoryPage: View {
    let viewModel: MonthlyRecapViewModel
    let snapshot: MonthlySnapshot
    let animationPhase: Int

    @ScaledMetric(relativeTo: .largeTitle) private var lineNameSize: CGFloat = 96

    var body: some View {
        ZStack {
            let lineColor = viewModel.resolvedTopLine?.color ?? viewModel.accentColor
            StoryBackground(page: .topLine, color: lineColor)
            FloatingShapesBackground(color: lineColor, shapeCount: 3)

            if let topLine = viewModel.resolvedTopLine {
                VStack(spacing: 16) {
                    Text(String(localized: "YOUR #1 LINE", comment: "Story top line page: section heading"))
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

                    topLineCaption(topLine)
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

    @ViewBuilder
    private func topLineCaption(_ topLine: ResolvedLine) -> some View {
        let isOnlyLine = topLine.travelCount == snapshot.travelCount

        VStack(spacing: 4) {
            if isOnlyLine {
                Text("Your one and only", comment: "Top line: only line used")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white)
            } else {
                Text(
                    "\(topLine.travelCount) travels this month",
                    comment: "Story top line page: travel count for most-used line"
                )
                .font(.title3)
                .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
}
