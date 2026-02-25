import SwiftUI

private struct OnboardingBadge {
    let name: String
    let background: String
    let foreground: String
}

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @State private var currentPage = 0
    @State private var slidingAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pageCount = 4

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                travelPage.tag(1)
                rewardsPage.tag(2)
                getStartedPage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(reduceMotion ? .none : .easeInOut, value: currentPage)

            bottomBar
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            HStack(spacing: 8) {
                ForEach(0 ..< pageCount, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.primary : Color.secondary.opacity(0.5))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == currentPage ? 1.2 : 1.0)
                        .animation(reduceMotion ? .none : .spring(duration: 0.3), value: currentPage)
                }
            }
            .accessibilityHidden(true)

            Spacer()

            if currentPage < pageCount - 1 {
                Button {
                    withAnimation(reduceMotion ? .none : .easeInOut) {
                        currentPage += 1
                    }
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.body.bold())
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(.blue, in: Circle())
                }
                .accessibilityLabel(String(localized: "Next page", comment: "Accessibility: onboarding next button"))
            } else {
                Button {
                    hasSeenOnboarding = true
                } label: {
                    Text(String(localized: "Start Exploring", comment: "Onboarding: get started button"))
                        .font(.body.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .frame(height: 48)
                        .background(.blue, in: Capsule())
                }
            }
        }
        .frame(height: 48)
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        OnboardingPageView(
            title: String(localized: "Welcome to Métropolist", comment: "Onboarding: welcome title"),
            // swiftlint:disable:next line_length
            subtitle: String(localized: "Collect every station in the Île-de-France transit network", comment: "Onboarding: welcome subtitle")
        ) {
            welcomePreview
        }
    }

    private var welcomePreview: some View {
        let modes: [TransitMode] = [.metro, .rer, .tram, .train, .bus]

        return HStack(spacing: 16) {
            ForEach(modes, id: \.self) { mode in
                VStack(spacing: 8) {
                    Image(systemName: mode.systemImage)
                        .font(.title)
                        .foregroundStyle(mode.tintColor)
                        .frame(width: 56, height: 56)
                        .background(mode.tintColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    Text(mode.label)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Page 2: Record Travels

    private var travelPage: some View {
        OnboardingPageView(
            title: String(localized: "Record Your Travels", comment: "Onboarding: travel title"),
            // swiftlint:disable:next line_length
            subtitle: String(localized: "Tap + to log a journey and discover new stations along the way", comment: "Onboarding: travel subtitle")
        ) {
            travelPreview
        }
    }

    private var travelPreview: some View {
        VStack(spacing: 24) {
            // Sample line badge
            Text("14")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .frame(minWidth: 32, minHeight: 24)
                .background(Color.purple, in: RoundedRectangle(cornerRadius: 4))

            // Station dots connected by a line
            HStack(spacing: 0) {
                ForEach(0 ..< 6, id: \.self) { index in
                    if index > 0 {
                        Rectangle()
                            .fill(Color.purple.opacity(0.3))
                            .frame(height: 3)
                    }
                    Circle()
                        .fill(index < 3 ? Color.purple : Color.purple.opacity(0.3))
                        .frame(width: 14, height: 14)
                        .overlay {
                            if index < 3 {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                }
            }
            .accessibilityHidden(true)
            .padding(.horizontal, 20)

            // Mini FAB
            Image(systemName: "plus")
                .font(.title3.bold())
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.blue, in: Circle())
                .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Page 3: Earn Rewards

    private var rewardsPage: some View {
        OnboardingPageView(
            title: String(localized: "Earn Rewards", comment: "Onboarding: rewards title"),
            // swiftlint:disable:next line_length
            subtitle: String(localized: "Complete lines to unlock badges and level up as you explore", comment: "Onboarding: rewards subtitle")
        ) {
            rewardsPreview
        }
    }

    private var rewardsPreview: some View {
        VStack(spacing: 28) {
            CompletionRing(completed: 7, total: 10, size: 100, showPercentage: true, tint: .purple)

            HStack(spacing: 24) {
                ForEach([BadgeTier.bronze, .silver, .gold], id: \.self) { tier in
                    VStack(spacing: 6) {
                        Image(systemName: tier.systemImage)
                            .font(.title2)
                            .foregroundStyle(tier.color)
                        Text(tier.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Page 4: Get Started

    private static let badgeWidth: CGFloat = 48
    private static let badgeSpacing: CGFloat = 10

    private static let lineRows: [[OnboardingBadge]] = [
        [
            .init(name: "1", background: "#FFCD00", foreground: "#000000"),
            .init(name: "A", background: "#E3051C", foreground: "#FFFFFF"),
            .init(name: "T3a", background: "#6EC4E8", foreground: "#000000"),
            .init(name: "6", background: "#6ECA97", foreground: "#000000"),
            .init(name: "B", background: "#5291CE", foreground: "#FFFFFF"),
            .init(name: "11", background: "#704B1C", foreground: "#FFFFFF"),
            .init(name: "C", background: "#FFBE00", foreground: "#000000"),
            .init(name: "T1", background: "#006DB8", foreground: "#FFFFFF"),
        ],
        [
            .init(name: "14", background: "#62259D", foreground: "#FFFFFF"),
            .init(name: "3", background: "#837902", foreground: "#FFFFFF"),
            .init(name: "T2", background: "#C04191", foreground: "#FFFFFF"),
            .init(name: "9", background: "#B6BD00", foreground: "#000000"),
            .init(name: "D", background: "#009B3A", foreground: "#FFFFFF"),
            .init(name: "7", background: "#FA9ABA", foreground: "#000000"),
            .init(name: "E", background: "#BD559C", foreground: "#FFFFFF"),
            .init(name: "4", background: "#CF009E", foreground: "#FFFFFF"),
        ],
        [
            .init(name: "12", background: "#007852", foreground: "#FFFFFF"),
            .init(name: "5", background: "#FF7E2E", foreground: "#000000"),
            .init(name: "T4", background: "#000000", foreground: "#FFFFFF"),
            .init(name: "8", background: "#E19BDF", foreground: "#000000"),
            .init(name: "13", background: "#6EC4E8", foreground: "#000000"),
            .init(name: "2", background: "#003CA6", foreground: "#FFFFFF"),
            .init(name: "N", background: "#009B3A", foreground: "#FFFFFF"),
            .init(name: "10", background: "#C9910D", foreground: "#000000"),
        ],
        [
            .init(name: "7b", background: "#6ECA97", foreground: "#000000"),
            .init(name: "P", background: "#FFBE00", foreground: "#000000"),
            .init(name: "T6", background: "#E3051C", foreground: "#FFFFFF"),
            .init(name: "L", background: "#5291CE", foreground: "#FFFFFF"),
            .init(name: "R", background: "#6EC4E8", foreground: "#000000"),
            .init(name: "3b", background: "#6EC4E8", foreground: "#000000"),
            .init(name: "J", background: "#CDCD00", foreground: "#000000"),
            .init(name: "H", background: "#704B1C", foreground: "#FFFFFF"),
        ],
        [
            .init(name: "T7", background: "#6ECA97", foreground: "#000000"),
            .init(name: "U", background: "#B90845", foreground: "#FFFFFF"),
            .init(name: "T5", background: "#837902", foreground: "#FFFFFF"),
            .init(name: "K", background: "#6EC4E8", foreground: "#000000"),
            .init(name: "T8", background: "#6EC4E8", foreground: "#000000"),
            .init(name: "V", background: "#A0006E", foreground: "#FFFFFF"),
            .init(name: "T9", background: "#FF7E2E", foreground: "#000000"),
            .init(name: "15", background: "#A0006E", foreground: "#FFFFFF"),
        ],
        [
            .init(name: "M", background: "#6EC4E8", foreground: "#000000"),
            .init(name: "T10", background: "#9B5FC0", foreground: "#FFFFFF"),
            .init(name: "T13", background: "#837902", foreground: "#FFFFFF"),
            .init(name: "O", background: "#E3051C", foreground: "#FFFFFF"),
            .init(name: "T3b", background: "#6EC4E8", foreground: "#000000"),
            .init(name: "S", background: "#C04191", foreground: "#FFFFFF"),
            .init(name: "T11", background: "#F29DC3", foreground: "#000000"),
            .init(name: "R", background: "#6EC4E8", foreground: "#000000"),
        ],
    ]

    private var scrollingLinesOverlay: some View {
        VStack(spacing: 14) {
            ForEach(Array(Self.lineRows.enumerated()), id: \.offset) { index, row in
                slidingRow(
                    badges: row,
                    movesRight: index.isMultiple(of: 2),
                    duration: Double(28 + index * 6)
                )
            }
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.15),
                    .init(color: .black, location: 0.85),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .opacity(0.45)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var getStartedPage: some View {
        VStack(spacing: 0) {
            Spacer()

            Color.clear
                .overlay { scrollingLinesOverlay }
                .frame(maxWidth: .infinity)

            Spacer()

            VStack(spacing: 12) {
                Text(String(localized: "Ready to Explore?", comment: "Onboarding: get started title"))
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(String(localized: "Your progress syncs across devices with iCloud", comment: "Onboarding: get started subtitle"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)

            Spacer()
                .frame(height: 120)
        }
        .clipped()
        .onAppear { slidingAnimating = true }
    }

    private func slidingRow(
        badges: [OnboardingBadge],
        movesRight: Bool,
        duration: Double
    ) -> some View {
        let tripled = badges + badges + badges
        let copyWidth = CGFloat(badges.count) * (Self.badgeWidth + Self.badgeSpacing)

        return HStack(spacing: Self.badgeSpacing) {
            ForEach(tripled.indices, id: \.self) { index in
                let badge = badges[index % badges.count]
                Text(badge.name)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .font(.caption.bold())
                    .foregroundStyle(Color(hex: badge.foreground))
                    .frame(width: Self.badgeWidth, height: 28)
                    .background(Color(hex: badge.background), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .offset(x: slidingAnimating
            ? (movesRight ? CGFloat(0) : -copyWidth)
            : (movesRight ? -copyWidth : CGFloat(0)))
        .animation(
            reduceMotion ? nil : .linear(duration: duration).repeatForever(autoreverses: false),
            value: slidingAnimating
        )
    }
}
