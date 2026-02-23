import SwiftUI
import TransitModels

struct TravelSuccessView: View {
    let viewModel: TravelFlowViewModel
    let onDone: () -> Void

    @State private var showCheckmark = false
    @State private var showTitle = false
    @State private var showDetails = false
    @State private var showCelebration = false
    @State private var showButton = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: showCheckmark)
                .opacity(showCheckmark ? 1 : 0)
                .offset(y: showCheckmark ? 0 : 10)

            Text(String(localized: "Journey recorded!", comment: "Travel success: main title"))
                .font(.title2.bold())
                .opacity(showTitle ? 1 : 0)
                .offset(y: showTitle ? 0 : 10)

            if let line = viewModel.selectedLine,
               let origin = viewModel.originStation,
               let destination = viewModel.destinationStation {
                VStack(spacing: 8) {
                    LineBadge(line: line)

                    Text(String(
                        localized: "\(origin.name) → \(destination.name)",
                        comment: "Travel success: origin to destination route summary"
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
                .opacity(showDetails ? 1 : 0)
                .offset(y: showDetails ? 0 : 10)
            }

            if let travel = viewModel.recordedTravel {
                VStack(spacing: 4) {
                    Text(String(
                        localized: "\(travel.stopsCompleted) stops traveled",
                        comment: "Travel success: total stops traveled count"
                    ))
                    .font(.subheadline)
                    if viewModel.newStopsCompleted > 0 {
                        Text(String(
                            localized: "\(viewModel.newStopsCompleted) new stops completed!",
                            comment: "Travel success: new unique stops count"
                        ))
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                    }
                }
                .padding(.top, 4)
                .opacity(showDetails ? 1 : 0)
                .offset(y: showDetails ? 0 : 10)
            }

            // Celebration info
            if let celebration = viewModel.celebrationEvent, showCelebration {
                VStack(spacing: 8) {
                    // XP gained
                    if celebration.xpGained > 0 {
                        Text(String(localized: "+\(celebration.xpGained) XP", comment: "Travel success: XP gained amount"))
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(.orange)
                    }

                    // Level up
                    if celebration.leveledUp, let newLevel = celebration.newLevel {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundStyle(.yellow)
                            Text(String(localized: "Level \(newLevel.number)", comment: "Travel success: new level reached"))
                                .font(.subheadline.bold())
                        }
                    }

                    // New badges
                    ForEach(celebration.newBadges, id: \.lineSourceID) { badge in
                        HStack(spacing: 6) {
                            Image(systemName: badge.tier.systemImage)
                                .foregroundStyle(badge.tier.color)
                            Text(String(localized: "\(badge.tier.label) Badge", comment: "Travel success: badge tier earned"))
                                .font(.caption)
                        }
                    }

                    // New achievements
                    ForEach(celebration.newAchievements) { achievement in
                        HStack(spacing: 6) {
                            Image(systemName: achievement.systemImage)
                                .foregroundStyle(.yellow)
                            Text(achievement.title)
                                .font(.caption.bold())
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            Button {
                onDone()
            } label: {
                Text(String(localized: "Done", comment: "Travel success: dismiss button"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("button-done")
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .opacity(showButton ? 1 : 0)
            .offset(y: showButton ? 0 : 10)
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.success, trigger: showCheckmark)
        .onAppear {
            if reduceMotion {
                showCheckmark = true
                showTitle = true
                showDetails = true
                showCelebration = true
                showButton = true
            } else {
                withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                    showCheckmark = true
                }
                withAnimation(.easeOut(duration: 0.4).delay(0.35)) {
                    showTitle = true
                }
                withAnimation(.easeOut(duration: 0.4).delay(0.55)) {
                    showDetails = true
                }
                withAnimation(.spring(duration: 0.5).delay(0.75)) {
                    showCelebration = true
                }
                withAnimation(.easeOut(duration: 0.4).delay(0.95)) {
                    showButton = true
                }
            }
        }
    }
}
