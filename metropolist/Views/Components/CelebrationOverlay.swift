import SwiftUI

struct CelebrationOverlay: ViewModifier {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showToast = false
    @State private var currentEvent: CelebrationEvent?
    @State private var dismissTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if showToast, let event = currentEvent {
                    CelebrationToast(event: event)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                        .onTapGesture {
                            dismissToast()
                        }
                }
            }
            .sensoryFeedback(.success, trigger: showToast)
            .onChange(of: dataStore.pendingCelebration) { _, newValue in
                if let event = newValue {
                    currentEvent = event
                    dataStore.pendingCelebration = nil
                    withAnimation(reduceMotion ? .none : .spring(duration: 0.4)) {
                        showToast = true
                    }
                    let duration: Double = (event.leveledUp || !event.newAchievements.isEmpty) ? 10 : 6
                    dismissTask?.cancel()
                    dismissTask = Task { @MainActor in
                        try? await Task.sleep(for: .seconds(duration))
                        guard !Task.isCancelled else { return }
                        dismissToast()
                    }
                }
            }
    }

    private func dismissToast() {
        withAnimation(reduceMotion ? .none : .easeOut(duration: 0.3)) {
            showToast = false
        }
    }
}

extension View {
    func celebrationOverlay() -> some View {
        modifier(CelebrationOverlay())
    }
}
