import SwiftUI

struct StoryContainer<Content: View>: View {
    let pageCount: Int
    @Binding var currentPage: Int
    let onDismiss: () -> Void
    @ViewBuilder let content: (Int) -> Content

    @State private var pageStartDate: Date = .now
    @State private var pauseAccumulated: TimeInterval = 0
    @State private var pauseStartDate: Date?
    @State private var isPaused = false
    @State private var containerWidth: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let autoAdvanceDuration: TimeInterval = 8.0

    var body: some View {
        TimelineView(.animation(paused: isPaused || reduceMotion)) { timeline in
            let progress = autoAdvanceProgress(now: timeline.date)
            ZStack {
                pageLayer
                topBar(progress: progress)
            }
            .onGeometryChange(for: CGFloat.self) { geo in
                geo.size.width
            } action: { newWidth in
                containerWidth = newWidth
            }
            .onChange(of: progress) {
                if progress >= 1, currentPage < pageCount - 1 {
                    goForward()
                }
            }
        }
        .simultaneousGesture(storyGesture)
        .accessibilityAction(.escape) { onDismiss() }
    }
}

// MARK: - Page Layer

private extension StoryContainer {
    var pageLayer: some View {
        content(currentPage)
            .id(currentPage)
            .transition(.opacity)
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.35), value: currentPage)
    }
}

// MARK: - Top Bar

private extension StoryContainer {
    func topBar(progress: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                StoryProgressBar(
                    pageCount: pageCount,
                    currentPage: currentPage,
                    progress: progress
                )

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel(String(localized: "Close", comment: "Story: close button"))
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()
        }
    }
}

// MARK: - Gesture

private extension StoryContainer {
    var storyGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                if !isPaused {
                    pauseStartDate = .now
                    isPaused = true
                }
            }
            .onEnded { value in
                let holdDuration: TimeInterval
                if let pauseStart = pauseStartDate {
                    holdDuration = Date.now.timeIntervalSince(pauseStart)
                    pauseAccumulated += holdDuration
                } else {
                    holdDuration = 0
                }
                pauseStartDate = nil
                isPaused = false

                let horizontalDistance = value.translation.width
                if horizontalDistance < -50 {
                    goForward()
                } else if horizontalDistance > 50 {
                    goBack()
                } else if holdDuration < 0.3 {
                    handleTap(at: value.startLocation)
                }
            }
    }

    func handleTap(at location: CGPoint) {
        if location.x < containerWidth / 3 {
            goBack()
        } else {
            goForward()
        }
    }
}

// MARK: - Navigation

private extension StoryContainer {
    func goForward() {
        if currentPage < pageCount - 1 {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            currentPage += 1
            resetAutoAdvance()
        } else {
            onDismiss()
        }
    }

    func goBack() {
        guard currentPage > 0 else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        currentPage -= 1
        resetAutoAdvance()
    }
}

// MARK: - Auto Advance

private extension StoryContainer {
    func autoAdvanceProgress(now: Date) -> CGFloat {
        guard !reduceMotion else { return 0 }
        let elapsed = now.timeIntervalSince(pageStartDate) - pauseAccumulated
        return min(max(CGFloat(elapsed / autoAdvanceDuration), 0), 1)
    }

    func resetAutoAdvance() {
        pageStartDate = .now
        pauseAccumulated = 0
        pauseStartDate = nil
    }
}
