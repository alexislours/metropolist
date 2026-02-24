import Foundation

struct AchievementDefinition: Equatable, Identifiable {
    let id: String
    let title: String
    let description: String
    let group: AchievementGroup
    let systemImage: String
    let xpReward: Int
    let evaluate: (AchievementContext) -> Date?

    static func == (lhs: AchievementDefinition, rhs: AchievementDefinition) -> Bool {
        lhs.id == rhs.id
    }
}

enum AchievementGroup: String, CaseIterable {
    case explorer = "Explorer"
    case completionist = "Completionist"
    case variety = "Variety"
    case dedication = "Dedication"

    var label: String {
        switch self {
        case .explorer: String(localized: "Explorer", comment: "Achievement group: explorer category")
        case .completionist: String(localized: "Completionist", comment: "Achievement group: completionist category")
        case .variety: String(localized: "Variety", comment: "Achievement group: variety category")
        case .dedication: String(localized: "Dedication", comment: "Achievement group: dedication category")
        }
    }

    var systemImage: String {
        switch self {
        case .explorer: "map"
        case .completionist: "checkmark.seal"
        case .variety: "sparkles"
        case .dedication: "flame"
        }
    }
}

struct AchievementContext {
    let totalTravels: Int
    let modesUsed: Set<TransitMode>
    let linesByMode: [TransitMode: Set<String>]
    let travelDates: [Date]
    let firstTravelDate: Date?

    // Stable milestone dates (computed from actual data, not Date())
    let nthUniqueStationDates: [Date] // date each NEW unique station was first visited
    let nthUniqueLineDates: [Date] // date each NEW unique line was first used
    let sortedTravelDates: [Date] // all travel dates, chronologically sorted
    let sortedLineCompletionDates: [Date] // dates when lines were completed, sorted
    let modeCompletionDates: [TransitMode: Date] // when all lines of a mode were completed
    let modeFirstUsedDates: [TransitMode: Date] // when each mode was first used
    let firstMultiModeDayDate: Date? // first day with 3+ transport modes
    let firstNoctilienDate: Date? // first travel on a Noctilien line
    let streakMilestoneDates: [Int: Date] // streak length → end date when first achieved
    let networkHalfDate: Date? // when 50% of the network was reached
}

enum AchievementDefinitions {
    static let all: [AchievementDefinition] = explorer + completionist + variety + dedication

    // MARK: - Explorer (6)

    static let explorer: [AchievementDefinition] = [
        AchievementDefinition(
            id: "premier_pas",
            title: String(localized: "First Steps", comment: "Achievement title: record first travel"),
            description: String(localized: "Record your first travel", comment: "Achievement description: record first travel"),
            group: .explorer,
            systemImage: "figure.walk",
            xpReward: 25
        ) { ctx in
            ctx.totalTravels >= 1 ? ctx.firstTravelDate : nil
        },
        AchievementDefinition(
            id: "curieux",
            title: String(localized: "Curious", comment: "Achievement title: visit 10 stops"),
            description: String(localized: "Visit 10 stops", comment: "Achievement description: visit 10 stops"),
            group: .explorer,
            systemImage: "eye",
            xpReward: 50
        ) { ctx in
            ctx.nthUniqueStationDates.count >= 10 ? ctx.nthUniqueStationDates[9] : nil
        },
        AchievementDefinition(
            id: "decouvreur",
            title: String(localized: "Discoverer", comment: "Achievement title: visit 50 stops"),
            description: String(localized: "Visit 50 stops", comment: "Achievement description: visit 50 stops"),
            group: .explorer,
            systemImage: "binoculars",
            xpReward: 100
        ) { ctx in
            ctx.nthUniqueStationDates.count >= 50 ? ctx.nthUniqueStationDates[49] : nil
        },
        AchievementDefinition(
            id: "grand_decouvreur",
            title: String(localized: "Great Discoverer", comment: "Achievement title: visit 100 stops"),
            description: String(localized: "Visit 100 stops", comment: "Achievement description: visit 100 stops"),
            group: .explorer,
            systemImage: "scope",
            xpReward: 200
        ) { ctx in
            ctx.nthUniqueStationDates.count >= 100 ? ctx.nthUniqueStationDates[99] : nil
        },
        AchievementDefinition(
            id: "cartographe",
            title: String(localized: "Cartographer", comment: "Achievement title: visit 500 stops"),
            description: String(localized: "Visit 500 stops", comment: "Achievement description: visit 500 stops"),
            group: .explorer,
            systemImage: "map.fill",
            xpReward: 500
        ) { ctx in
            ctx.nthUniqueStationDates.count >= 500 ? ctx.nthUniqueStationDates[499] : nil
        },
        AchievementDefinition(
            id: "omniscient",
            title: String(localized: "Omniscient", comment: "Achievement title: visit 1000 stops"),
            description: String(localized: "Visit 1000 stops", comment: "Achievement description: visit 1000 stops"),
            group: .explorer,
            systemImage: "globe",
            xpReward: 1000
        ) { ctx in
            ctx.nthUniqueStationDates.count >= 1000 ? ctx.nthUniqueStationDates[999] : nil
        },
    ]

    // MARK: - Completionist (6)

    static let completionist: [AchievementDefinition] = [
        AchievementDefinition(
            id: "premiere_ligne",
            title: String(localized: "First Line", comment: "Achievement title: complete first line"),
            description: String(localized: "Complete a line at 100%", comment: "Achievement description: complete first line"),
            group: .completionist,
            systemImage: "checkmark.circle",
            xpReward: 100
        ) { ctx in
            ctx.sortedLineCompletionDates.first
        },
        AchievementDefinition(
            id: "collectionneur",
            title: String(localized: "Collector", comment: "Achievement title: complete 5 lines"),
            description: String(localized: "Complete 5 lines", comment: "Achievement description: complete 5 lines"),
            group: .completionist,
            systemImage: "tray.full",
            xpReward: 250
        ) { ctx in
            ctx.sortedLineCompletionDates.count >= 5 ? ctx.sortedLineCompletionDates[4] : nil
        },
        AchievementDefinition(
            id: "roi_du_metro",
            title: String(localized: "Metro King", comment: "Achievement title: complete all metro lines"),
            description: String(localized: "Complete all metro lines", comment: "Achievement description: complete all metro lines"),
            group: .completionist,
            systemImage: "crown",
            xpReward: 1000
        ) { ctx in
            ctx.modeCompletionDates[.metro]
        },
        AchievementDefinition(
            id: "maitre_du_rer",
            title: String(localized: "RER Master", comment: "Achievement title: complete all RER lines"),
            description: String(localized: "Complete all RER lines", comment: "Achievement description: complete all RER lines"),
            group: .completionist,
            systemImage: "train.side.front.car",
            xpReward: 1000
        ) { ctx in
            ctx.modeCompletionDates[.rer]
        },
        AchievementDefinition(
            id: "baron_du_tramway",
            title: String(localized: "Tram Baron", comment: "Achievement title: complete all tram lines"),
            description: String(localized: "Complete all tram lines", comment: "Achievement description: complete all tram lines"),
            group: .completionist,
            systemImage: "tram",
            xpReward: 750
        ) { ctx in
            ctx.modeCompletionDates[.tram]
        },
        AchievementDefinition(
            id: "demi_reseau",
            title: String(localized: "Half Network", comment: "Achievement title: complete 50% of network"),
            description: String(localized: "Complete 50% of the network", comment: "Achievement description: complete 50% of network"),
            group: .completionist,
            systemImage: "chart.pie",
            xpReward: 2000
        ) { ctx in
            ctx.networkHalfDate
        },
    ]

    // MARK: - Variety (6)

    static let variety: [AchievementDefinition] = [
        AchievementDefinition(
            id: "touche_a_tout",
            title: String(localized: "Jack of All Trades", comment: "Achievement title: use 3 modes in one day"),
            description: String(localized: "Use 3 transport modes in one day", comment: "Achievement description: use 3 modes in one day"),
            group: .variety,
            systemImage: "shuffle",
            xpReward: 100
        ) { ctx in
            ctx.firstMultiModeDayDate
        },
        AchievementDefinition(
            id: "polyvalent",
            title: String(localized: "Versatile", comment: "Achievement title: use every transport mode"),
            description: String(localized: "Use every transport mode", comment: "Achievement description: use every transport mode"),
            group: .variety,
            systemImage: "rectangle.grid.2x2",
            xpReward: 500
        ) { ctx in
            guard !ctx.linesByMode.isEmpty else { return nil }
            let availableModes = Set(ctx.linesByMode.keys)
            guard ctx.modesUsed.isSuperset(of: availableModes) else { return nil }
            return ctx.modeFirstUsedDates.values.max()
        },
        AchievementDefinition(
            id: "noctambule",
            title: String(localized: "Night Owl", comment: "Achievement title: travel on Noctilien line"),
            description: String(localized: "Travel on a Noctilien line", comment: "Achievement description: travel on Noctilien line"),
            group: .variety,
            systemImage: "moon.stars",
            xpReward: 75
        ) { ctx in
            ctx.firstNoctilienDate
        },
        AchievementDefinition(
            id: "funambule",
            title: String(localized: "Funambulist", comment: "Achievement title: travel by funicular"),
            description: String(localized: "Travel by funicular", comment: "Achievement description: travel by funicular"),
            group: .variety,
            systemImage: "cablecar",
            xpReward: 75
        ) { ctx in
            ctx.modeFirstUsedDates[.funicular]
        },
        AchievementDefinition(
            id: "aerien",
            title: String(localized: "Airborne", comment: "Achievement title: travel by cable car"),
            description: String(localized: "Travel by cable car", comment: "Achievement description: travel by cable car"),
            group: .variety,
            systemImage: "cablecar.fill",
            xpReward: 75
        ) { ctx in
            ctx.modeFirstUsedDates[.cableway]
        },
        AchievementDefinition(
            id: "dilettante",
            title: String(localized: "Dilettante", comment: "Achievement title: travel on 10 different lines"),
            description: String(
                localized: "Travel on 10 different lines",
                comment: "Achievement description: travel on 10 different lines"
            ),
            group: .variety,
            systemImage: "arrow.triangle.branch",
            xpReward: 150
        ) { ctx in
            ctx.nthUniqueLineDates.count >= 10 ? ctx.nthUniqueLineDates[9] : nil
        },
    ]

    // MARK: - Dedication (6)

    static let dedication: [AchievementDefinition] = [
        AchievementDefinition(
            id: "regulier",
            title: String(localized: "Regular", comment: "Achievement title: 7-day streak"),
            description: String(localized: "7-day streak", comment: "Achievement description: 7-day streak"),
            group: .dedication,
            systemImage: "calendar",
            xpReward: 100
        ) { ctx in
            ctx.streakMilestoneDates[7]
        },
        AchievementDefinition(
            id: "infatigable",
            title: String(localized: "Tireless", comment: "Achievement title: 30-day streak"),
            description: String(localized: "30-day streak", comment: "Achievement description: 30-day streak"),
            group: .dedication,
            systemImage: "calendar.badge.clock",
            xpReward: 500
        ) { ctx in
            ctx.streakMilestoneDates[30]
        },
        AchievementDefinition(
            id: "centurion",
            title: String(localized: "Centurion", comment: "Achievement title: record 100 travels"),
            description: String(localized: "Record 100 travels", comment: "Achievement description: record 100 travels"),
            group: .dedication,
            systemImage: "repeat.circle",
            xpReward: 250
        ) { ctx in
            ctx.sortedTravelDates.count >= 100 ? ctx.sortedTravelDates[99] : nil
        },
        AchievementDefinition(
            id: "marathonien",
            title: String(localized: "Marathoner", comment: "Achievement title: record 500 travels"),
            description: String(localized: "Record 500 travels", comment: "Achievement description: record 500 travels"),
            group: .dedication,
            systemImage: "figure.run",
            xpReward: 750
        ) { ctx in
            ctx.sortedTravelDates.count >= 500 ? ctx.sortedTravelDates[499] : nil
        },
        AchievementDefinition(
            id: "veteran",
            title: String(localized: "Veteran", comment: "Achievement title: 1 year since first travel"),
            description: String(localized: "1 year since first travel", comment: "Achievement description: 1 year since first travel"),
            group: .dedication,
            systemImage: "star.circle",
            xpReward: 500
        ) { ctx in
            guard let first = ctx.firstTravelDate else { return nil }
            guard let oneYear = Calendar.current.date(byAdding: .year, value: 1, to: first) else { return nil }
            return Date() >= oneYear ? oneYear : nil
        },
        AchievementDefinition(
            id: "leve_tot",
            title: String(localized: "Early Bird", comment: "Achievement title: travel before 6 AM"),
            description: String(localized: "Travel before 6 AM", comment: "Achievement description: travel before 6 AM"),
            group: .dedication,
            systemImage: "sunrise",
            xpReward: 50
        ) { ctx in
            let cal = Calendar.current
            for date in ctx.travelDates {
                let hour = cal.component(.hour, from: date)
                if hour < 6 { return date }
            }
            return nil
        },
    ]
}
