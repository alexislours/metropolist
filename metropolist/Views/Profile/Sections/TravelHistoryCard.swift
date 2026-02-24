import SwiftUI
import TransitModels

struct TravelHistoryCard: View {
    let travels: [Travel]
    let travelLines: [String: TransitLine]
    let stationNames: [String: String]
    let historySource: TravelHistorySource
    private var displayedTravels: [Travel] {
        Array(travels.prefix(5))
    }

    var body: some View {
        CardSection(title: String(localized: "Recent Travels", comment: "Recent travels section header")) {
            if travels.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tram")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    Text(String(localized: "No travels recorded", comment: "Travel history: empty state title"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(String(localized: "Tap + to get started", comment: "Travel history: empty state hint"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(displayedTravels, id: \.id) { travel in
                        NavigationLink(value: GamificationDestination.travelDetail(travel.id)) {
                            TravelHistoryRow(
                                travel: travel,
                                line: travelLines[travel.lineSourceID],
                                fromName: stationNames[travel.fromStationSourceID] ?? travel.fromStationSourceID,
                                toName: stationNames[travel.toStationSourceID] ?? travel.toStationSourceID
                            )
                        }
                        .buttonStyle(.plain)

                        if travel.id != displayedTravels.last?.id {
                            Divider()
                                .padding(.vertical, 6)
                        }
                    }

                    Divider()
                        .padding(.vertical, 6)

                    NavigationLink(value: GamificationDestination.travelHistory(historySource)) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.subheadline)

                            Text(String(localized: "View All", comment: "Travel history: view all link"))
                                .font(.subheadline.weight(.medium))

                            Spacer()

                            Text(String(localized: "\(travels.count) travels", comment: "Travel history: total travels count"))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(Color.accentColor)
                        .padding(.vertical, 6)
                    }
                }
            }
        }
    }
}
