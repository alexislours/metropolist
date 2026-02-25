import SwiftUI

struct FAQView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ForEach(faqSections) { section in
                    FAQSectionView(section: section)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 80)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(String(localized: "FAQ", comment: "FAQ: navigation title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - FAQ Section

private struct FAQSectionView: View {
    let section: FAQSection

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)

            VStack(spacing: 12) {
                ForEach(section.items) { item in
                    FAQItemView(item: item)
                }
            }
        }
    }
}

// MARK: - FAQ Item

private struct FAQItemView: View {
    let item: FAQItem
    @State private var isExpanded = false

    var body: some View {
        CardSection(title: nil) {
            DisclosureGroup(isExpanded: $isExpanded) {
                Text(item.answer)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            } label: {
                Text(item.question)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
            }
            .tint(.primary)
        }
    }
}

// MARK: - Data

private struct FAQItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

private struct FAQSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [FAQItem]
}

private let faqSections: [FAQSection] = [
    FAQSection(
        title: String(localized: "General", comment: "FAQ: general section title"),
        items: [
            FAQItem(
                question: String(localized: "What area does Métropolist cover?", comment: "FAQ: coverage question"),
                answer: String(
                    // swiftlint:disable:next line_length
                    localized: "Métropolist covers the entire Ile-de-France (Paris region) public transit network, including Metro, RER, Tramway, Bus, and other modes operated by IDFM.",
                    comment: "FAQ: coverage answer"
                )
            ),
            FAQItem(
                question: String(localized: "Does the app work offline?", comment: "FAQ: offline question"),
                answer: String(
                    // swiftlint:disable:next line_length
                    localized: "Yes! All transit data is bundled with the app so you can browse lines, stations, and routes without an internet connection.",
                    comment: "FAQ: offline answer"
                )
            ),
            FAQItem(
                question: String(localized: "How is my data synced across devices?", comment: "FAQ: sync question"),
                answer: String(
                    // swiftlint:disable:next line_length
                    localized: "Your travels and completed stops are synced via iCloud. Make sure you are signed into iCloud on all your devices for automatic sync.",
                    comment: "FAQ: sync answer"
                )
            ),
        ]
    ),
    FAQSection(
        title: String(localized: "Progression & Rewards", comment: "FAQ: gamification section title"),
        items: [
            FAQItem(
                question: String(localized: "How do I earn XP?", comment: "FAQ: XP question"),
                answer: String(
                    // swiftlint:disable:next line_length
                    localized: "• 5 XP per travel\n• 20 XP per new station\n• Line completion: 50 + 5 per station\n• First line bonus: 25 (bus) or 50 (other modes)\n• Daily streak: up to 50 XP/day\n• Achievement rewards",
                    comment: "FAQ: XP answer"
                )
            ),
            FAQItem(
                question: String(localized: "What are badges and how do I earn them?", comment: "FAQ: badges question"),
                answer: String(
                    localized: "Each line has three badge tiers: Bronze at 10% completion, Silver at 40%, and Gold at 100%.",
                    comment: "FAQ: badges answer"
                )
            ),
            FAQItem(
                question: String(localized: "How do streaks work?", comment: "FAQ: streaks question"),
                answer: String(
                    // swiftlint:disable:next line_length
                    localized: "Streaks track consecutive days you log a travel. Each day of your streak earns a bonus of 5 × streak day in XP (capped at 50 XP/day). If you miss a day, the streak resets. Keep it going to unlock the 7-day and 30-day achievements!",
                    comment: "FAQ: streaks answer"
                )
            ),
            FAQItem(
                question: String(localized: "What are secret achievements?", comment: "FAQ: secret achievements question"),
                answer: String(
                    localized: "Secret achievements are hidden challenges that only reveal themselves once unlocked.",
                    comment: "FAQ: secret achievements answer"
                )
            ),
        ]
    ),
    FAQSection(
        title: String(localized: "Travels", comment: "FAQ: travels section title"),
        items: [
            FAQItem(
                question: String(localized: "What counts as a completed stop?", comment: "FAQ: completed stop question"),
                answer: String(
                    // swiftlint:disable:next line_length
                    localized: "When you log a travel, all intermediate stations between your departure and destination are marked as completed. Visiting a stop on different lines counts separately for each line.",
                    comment: "FAQ: completed stop answer"
                )
            ),
            FAQItem(
                question: String(localized: "Can I delete a travel I recorded?", comment: "FAQ: delete travel question"),
                answer: String(
                    // swiftlint:disable:next line_length
                    localized: "Yes. Go to Profile > History, tap Select, choose the travels you want to remove, then delete them. If a stop is no longer covered by another travel on that line, it will also be removed from your completion.",
                    comment: "FAQ: delete travel answer"
                )
            ),
        ]
    ),
    FAQSection(
        title: String(localized: "Data Management", comment: "FAQ: data management section title"),
        items: [
            FAQItem(
                question: String(localized: "How do I export or import my data?", comment: "FAQ: export import question"),
                answer: String(
                    // swiftlint:disable:next line_length
                    localized: "Go to Settings > Data Management. Use Export Data to save a JSON backup, and Import Data to restore from a previous export.",
                    comment: "FAQ: export import answer"
                )
            ),
            FAQItem(
                question: String(localized: "What happens if I delete all my data?", comment: "FAQ: delete data question"),
                answer: String(
                    // swiftlint:disable:next line_length
                    localized: "Deleting all data permanently removes all your travels and completed stops. Your progress, XP, badges, and achievements will all be lost and this cannot be undone. Export a backup first via Settings > Data Management.",
                    comment: "FAQ: delete data answer"
                )
            ),
        ]
    ),
]
