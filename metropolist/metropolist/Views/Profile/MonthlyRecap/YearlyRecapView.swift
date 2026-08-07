import SwiftUI

enum YearlyStoryPage: Equatable {
    case hero
    case numbers
    case bestMonth
    case rankings
    case topLine
    case modeBreakdown
    case discoveries
    case leveledUp
    case superlatives
    case summary
}

struct YearlyRecapView: View {
    @State var viewModel: YearlyRecapViewModel
    @State private var currentPage = 0
    @State private var animationPhase = 0
    @State private var phaseTask: Task<Void, Never>?
    @State private var pages: [YearlyStoryPage] = []
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(year: Int, dataStore: DataStore) {
        _viewModel = State(initialValue: YearlyRecapViewModel(year: year, dataStore: dataStore))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.isEmpty || pages.isEmpty {
                emptyStoryState
            } else {
                storyContent
            }
        }
        .background(Color.black.ignoresSafeArea())
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .task {
            await viewModel.load()
            pages = buildPages()
            triggerPageAnimation()
        }
    }
}

// MARK: - Story Content

private extension YearlyRecapView {
    var storyContent: some View {
        StoryContainer(
            pageCount: pages.count,
            currentPage: $currentPage,
            onDismiss: { dismiss() },
            content: { pageIndex in
                storyPage(pages[pageIndex])
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        )
        .onChange(of: currentPage) {
            triggerPageAnimation()
        }
    }

    @ViewBuilder
    func storyPage(_ page: YearlyStoryPage) -> some View {
        if let snapshot = viewModel.snapshot {
            storyPageContent(page, snapshot: snapshot)
        }
    }

    @ViewBuilder
    func storyPageContent(_ page: YearlyStoryPage, snapshot: YearlySnapshot) -> some View {
        switch page {
        case .hero:
            WrappedHeroPage(viewModel: viewModel, animationPhase: animationPhase)
        case .numbers:
            WrappedNumbersPage(
                viewModel: viewModel,
                snapshot: snapshot,
                previous: viewModel.previousYearSnapshot,
                animationPhase: animationPhase
            )
        case .bestMonth:
            WrappedBestMonthPage(viewModel: viewModel, snapshot: snapshot, animationPhase: animationPhase)
        case .rankings:
            WrappedRankingsPage(viewModel: viewModel, animationPhase: animationPhase)
        case .topLine:
            WrappedTopLinePage(viewModel: viewModel, animationPhase: animationPhase)
        case .modeBreakdown:
            WrappedModeBreakdownPage(viewModel: viewModel, snapshot: snapshot, animationPhase: animationPhase)
        case .discoveries:
            WrappedDiscoveriesPage(viewModel: viewModel, animationPhase: animationPhase)
        case .leveledUp:
            WrappedLeveledUpPage(viewModel: viewModel, animationPhase: animationPhase)
        case .superlatives:
            WrappedSuperlativesPage(viewModel: viewModel, snapshot: snapshot, animationPhase: animationPhase)
        case .summary:
            WrappedSummaryPage(
                viewModel: viewModel,
                snapshot: snapshot,
                animationPhase: animationPhase,
                onClose: { dismiss() }
            )
        }
    }
}

// MARK: - Page Building

private extension YearlyRecapView {
    func buildPages() -> [YearlyStoryPage] {
        guard let snapshot = viewModel.snapshot else { return [] }
        var result: [YearlyStoryPage] = [.hero, .numbers]

        if snapshot.monthRankings.count >= 2 {
            result.append(.bestMonth)
            result.append(.rankings)
        }

        if viewModel.resolvedTopLine != nil {
            result.append(.topLine)
        }

        if !snapshot.modeBreakdown.isEmpty {
            result.append(.modeBreakdown)
        }

        let discoveries = viewModel.resolvedDiscoveries
        if !discoveries.newLines.isEmpty || !discoveries.newStations.isEmpty {
            result.append(.discoveries)
        }

        if !viewModel.resolvedBadgeUpgrades.isEmpty {
            result.append(.leveledUp)
        }

        if superlativeCount(for: snapshot) >= 2 {
            result.append(.superlatives)
        }

        result.append(.summary)
        return result
    }

    func superlativeCount(for snapshot: YearlySnapshot) -> Int {
        var count = 0
        if snapshot.busiestDay.1 > 0 {
            count += 1
        }
        if snapshot.longestStreak.length > 1 {
            count += 1
        }
        if snapshot.mostLinesInADay.1 > 0 {
            count += 1
        }
        if snapshot.mostStationsInADay.1 > 0 {
            count += 1
        }
        if viewModel.mostDistanceDayMeters > 0 {
            count += 1
        }
        return count
    }
}

// MARK: - Animation

private extension YearlyRecapView {
    func triggerPageAnimation() {
        phaseTask?.cancel()
        if reduceMotion {
            animationPhase = 4
            return
        }
        animationPhase = 0
        phaseTask = Task { @MainActor in
            let delays = [150, 300, 300, 350]
            for (index, delay) in delays.enumerated() {
                try? await Task.sleep(for: .milliseconds(delay))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.5)) {
                    animationPhase = index + 1
                }
            }
        }
    }
}

// MARK: - Empty State

private extension YearlyRecapView {
    var emptyStoryState: some View {
        VStack(spacing: 16) {
            Text(viewModel.formattedYear)
                .font(.title.bold())
                .foregroundStyle(.white)
            Text("No travels recorded this year", comment: "Yearly story: empty state message")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            Button(String(localized: "Close", comment: "Story: close button")) {
                dismiss()
            }
            .foregroundStyle(.white)
            .padding(.top, 24)
        }
    }
}
