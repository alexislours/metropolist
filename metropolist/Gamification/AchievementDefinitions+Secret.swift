import Foundation

extension AchievementDefinitions {
    // MARK: - Secret (Hidden)

    static let secret: [AchievementDefinition] = [
        AchievementDefinition(
            id: "secret_inception",
            title: String(localized: "Inception", comment: "Achievement title: travel through Bir-Hakeim on Line 6"),
            description: String(
                localized: "Travel through Bir-Hakeim station on Line 6",
                comment: "Achievement description: travel through Bir-Hakeim on Line 6"
            ),
            group: .secret,
            systemImage: "film",
            xpReward: 150,
            isHidden: true
        ) { ctx in
            ctx.firstBirHakeimLine6Date
        },
        AchievementDefinition(
            id: "secret_dernier_metro",
            title: String(localized: "The Last Metro", comment: "Achievement title: travel after midnight on a weekday"),
            description: String(
                localized: "Travel after midnight and before 3 AM on a weekday",
                comment: "Achievement description: travel after midnight on a weekday"
            ),
            group: .secret,
            systemImage: "moon.zzz",
            xpReward: 100,
            isHidden: true
        ) { ctx in
            ctx.firstWeekdayLateNightTravelDate
        },
        AchievementDefinition(
            id: "secret_grand_paris",
            title: String(localized: "Greater Paris", comment: "Achievement title: visit all 8 IDF departments"),
            description: String(
                localized: "Visit at least one station in each Île-de-France department",
                comment: "Achievement description: visit all 8 IDF departments"
            ),
            group: .secret,
            systemImage: "map.circle",
            xpReward: 1000,
            isHidden: true
        ) { ctx in
            ctx.allDepartmentsCoveredDate
        },
        AchievementDefinition(
            id: "secret_fantome_opera",
            title: String(localized: "The Phantom of the Opera", comment: "Achievement title: travel at Opéra between 11 PM and 3 AM"),
            description: String(
                localized: "Travel at Opéra station between 11 PM and 3 AM",
                comment: "Achievement description: travel at Opéra between 11 PM and 3 AM"
            ),
            group: .secret,
            systemImage: "theatermasks",
            xpReward: 200,
            isHidden: true
        ) { ctx in
            ctx.firstOperaNightTravelDate
        },
        AchievementDefinition(
            id: "secret_survivant_13",
            title: String(localized: "Line 13 Survivor", comment: "Achievement title: travel on Line 13 during rush hour"),
            description: String(
                localized: "Travel on Line 13 between 8 AM and 9 AM",
                comment: "Achievement description: travel on Line 13 during rush hour"
            ),
            group: .secret,
            systemImage: "person.3.fill",
            xpReward: 200,
            isHidden: true
        ) { ctx in
            ctx.firstLine13RushHourDate
        },
        AchievementDefinition(
            id: "secret_fou_du_bus",
            title: String(localized: "Bus Fanatic", comment: "Achievement title: discover 50 bus lines"),
            description: String(
                localized: "Discover 50 bus lines",
                comment: "Achievement description: discover 50 bus lines"
            ),
            group: .secret,
            systemImage: "bus.fill",
            xpReward: 1000,
            isHidden: true
        ) { ctx in
            ctx.nthUniqueBusLineDates.count >= 50 ? ctx.nthUniqueBusLineDates[49] : nil
        },
    ]
}
