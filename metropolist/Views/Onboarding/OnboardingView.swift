import SwiftUI

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
                ForEach(0..<pageCount, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == currentPage ? 1.2 : 1.0)
                        .animation(reduceMotion ? .none : .spring(duration: 0.3), value: currentPage)
                }
            }

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
                ForEach(0 ..< 6, id: \.self) { i in
                    if i > 0 {
                        Rectangle()
                            .fill(Color.purple.opacity(0.3))
                            .frame(height: 3)
                    }
                    Circle()
                        .fill(i < 3 ? Color.purple : Color.purple.opacity(0.3))
                        .frame(width: 14, height: 14)
                        .overlay {
                            if i < 3 {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                }
            }
            .padding(.horizontal, 20)

            // Mini FAB
            Image(systemName: "plus")
                .font(.title3.bold())
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.blue, in: Circle())
                .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
        }
    }

    // MARK: - Page 3: Earn Rewards

    private var rewardsPage: some View {
        OnboardingPageView(
            title: String(localized: "Earn Rewards", comment: "Onboarding: rewards title"),
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

    // Real Paris transit line colors: (name, background hex, text hex)
    private static let lineRows: [[(String, String, String)]] = [
        [("1", "#FFCD00", "#000000"), ("A", "#E3051C", "#FFFFFF"), ("T3a", "#6EC4E8", "#000000"), ("6", "#6ECA97", "#000000"), ("B", "#5291CE", "#FFFFFF"), ("11", "#704B1C", "#FFFFFF"), ("C", "#FFBE00", "#000000"), ("T1", "#006DB8", "#FFFFFF")],
        [("14", "#62259D", "#FFFFFF"), ("3", "#837902", "#FFFFFF"), ("T2", "#C04191", "#FFFFFF"), ("9", "#B6BD00", "#000000"), ("D", "#009B3A", "#FFFFFF"), ("7", "#FA9ABA", "#000000"), ("E", "#BD559C", "#FFFFFF"), ("4", "#CF009E", "#FFFFFF")],
        [("12", "#007852", "#FFFFFF"), ("5", "#FF7E2E", "#000000"), ("T4", "#000000", "#FFFFFF"), ("8", "#E19BDF", "#000000"), ("13", "#6EC4E8", "#000000"), ("2", "#003CA6", "#FFFFFF"), ("N", "#009B3A", "#FFFFFF"), ("10", "#C9910D", "#000000")],
        [("7b", "#6ECA97", "#000000"), ("P", "#FFBE00", "#000000"), ("T6", "#E3051C", "#FFFFFF"), ("L", "#5291CE", "#FFFFFF"), ("R", "#6EC4E8", "#000000"), ("3b", "#6EC4E8", "#000000"), ("J", "#CDCD00", "#000000"), ("H", "#704B1C", "#FFFFFF")],
        [("T7", "#6ECA97", "#000000"), ("U", "#B90845", "#FFFFFF"), ("T5", "#837902", "#FFFFFF"), ("K", "#6EC4E8", "#000000"), ("T8", "#6EC4E8", "#000000"), ("V", "#A0006E", "#FFFFFF"), ("T9", "#FF7E2E", "#000000"), ("15", "#A0006E", "#FFFFFF")],
        [("M", "#6EC4E8", "#000000"), ("T10", "#9B5FC0", "#FFFFFF"), ("T13", "#837902", "#FFFFFF"), ("O", "#E3051C", "#FFFFFF"), ("T3b", "#6EC4E8", "#000000"), ("S", "#C04191", "#FFFFFF"), ("T11", "#F29DC3", "#000000"), ("R", "#6EC4E8", "#000000")],
    ]

    private var getStartedPage: some View {
        VStack(spacing: 0) {
            Spacer()

            // Preview area — Color.clear holds the layout, overlay renders the lines
            Color.clear
                .overlay {
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
                }
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
        badges: [(String, String, String)],
        movesRight: Bool,
        duration: Double
    ) -> some View {
        let tripled = badges + badges + badges
        let copyWidth = CGFloat(badges.count) * (Self.badgeWidth + Self.badgeSpacing)

        return HStack(spacing: Self.badgeSpacing) {
            ForEach(tripled.indices, id: \.self) { i in
                let b = badges[i % badges.count]
                Text(b.0)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .font(.caption.bold())
                    .foregroundStyle(Color(hex: b.2))
                    .frame(width: Self.badgeWidth, height: 28)
                    .background(Color(hex: b.1), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .offset(x: slidingAnimating
            ? (movesRight ? 0 : -copyWidth)
            : (movesRight ? -copyWidth : 0)
        )
        .animation(
            reduceMotion ? nil : .linear(duration: duration).repeatForever(autoreverses: false),
            value: slidingAnimating
        )
    }
}
