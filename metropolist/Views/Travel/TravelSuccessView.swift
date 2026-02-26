import SwiftUI
import TransitModels

struct TravelSuccessView: View {
    let viewModel: TravelFlowViewModel
    let onDone: () -> Void

    @State var showArrival = false
    @State var showCheckmark = false
    @State var showHeadline = false
    @State var showJourneyHeader = false
    @State var showXPItems: Set<Int> = []
    @State var showTicker = false
    @State var tickerValue = 0
    @State var showLevelBar = false
    @State var levelBarProgress: CGFloat = 0
    @State var levelBounce = false
    @State var showConfetti = false
    @State var showLoot = false
    @State var showEpicOverlay = false
    @State var showEpicLoot = false
    @State var epicShimmerPhase: CGFloat = 0
    @State var showTeaser = false
    @State var showDone = false

    @State var tickerTask: Task<Void, Never>?
    @State var sequenceTask: Task<Void, Never>?
    @State var epicRevealTask: Task<Void, Never>?

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var lineColor: Color {
        if let line = viewModel.selectedLine {
            Color(hex: line.color)
        } else {
            .accentColor
        }
    }

    var regularAchievements: [AchievementDefinition] {
        viewModel.celebrationEvent?.newAchievements.filter { !$0.isHidden } ?? []
    }

    var hiddenAchievements: [AchievementDefinition] {
        viewModel.celebrationEvent?.newAchievements.filter(\.isHidden) ?? []
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 40)

                arrivalSection
                journeyHeaderSection
                xpBreakdownSection
                tickerSection
                lootSection
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
                    .accessibilityHidden(true)
            }
        }
        .overlay {
            if showEpicOverlay {
                EpicAchievementOverlay(
                    achievements: hiddenAchievements,
                    isPresented: $showEpicOverlay,
                    showConfetti: $showConfetti,
                    onAllDismissed: { handleEpicDismissed() }
                )
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
}
