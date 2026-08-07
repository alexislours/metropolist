import SwiftUI
import TransitModels

struct TravelJourneyCard: View {
    let travel: Travel
    let journeyStops: [TransitLineStop]
    let stationNames: [String: String]
    let completedStopIDs: Set<String>
    let lineColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Journey", comment: "Travel detail: journey section header"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            LazyVStack(spacing: 0) {
                if journeyStops.isEmpty {
                    simpleItinerary
                } else {
                    ForEach(Array(journeyStops.enumerated()), id: \.element.order) { index, stop in
                        stopRow(stop, index: index)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary, lineWidth: 1))
        }
    }

    private func stopRow(_ stop: TransitLineStop, index: Int) -> some View {
        let isEndpoint = stop.stationSourceID == travel.fromStationSourceID
            || stop.stationSourceID == travel.toStationSourceID
        let isFirst = index == 0
        let isLast = index == journeyStops.count - 1
        let name = stationNames[stop.stationSourceID] ?? stop.stationSourceID

        return NavigationLink(value: StationDestination(stationSourceID: stop.stationSourceID)) {
            HStack(spacing: 12) {
                ZStack {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(isFirst ? .clear : lineColor)
                            .frame(width: 3)
                        Rectangle()
                            .fill(isLast ? .clear : lineColor)
                            .frame(width: 3)
                    }

                    Circle()
                        .fill(isEndpoint ? lineColor : lineColor.opacity(0.3))
                        .frame(width: isEndpoint ? 12 : 6, height: isEndpoint ? 12 : 6)
                        .overlay {
                            if isEndpoint {
                                Circle()
                                    .strokeBorder(.white, lineWidth: 2)
                            }
                        }
                }
                .frame(width: 20)

                Text(name)
                    .font(isEndpoint ? .subheadline.weight(.semibold) : .subheadline)
                    .foregroundStyle(isEndpoint ? .primary : .secondary)

                Spacer()

                if completedStopIDs.contains(stop.stationSourceID) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(height: isEndpoint ? 36 : 28)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var simpleItinerary: some View {
        let fromName = stationNames[travel.fromStationSourceID] ?? travel.fromStationSourceID
        let toName = stationNames[travel.toStationSourceID] ?? travel.toStationSourceID

        VStack(spacing: 0) {
            NavigationLink(value: StationDestination(stationSourceID: travel.fromStationSourceID)) {
                HStack(spacing: 12) {
                    ZStack {
                        VStack(spacing: 0) {
                            Rectangle().fill(.clear).frame(width: 3)
                            Rectangle().fill(lineColor).frame(width: 3)
                        }
                        Circle().fill(lineColor).frame(width: 12, height: 12)
                            .overlay { Circle().strokeBorder(.white, lineWidth: 2) }
                    }
                    .frame(width: 20)

                    Text(fromName)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .frame(height: 36)
            }
            .buttonStyle(.plain)

            if travel.stopsCompleted > 2 {
                HStack(spacing: 12) {
                    ZStack {
                        Rectangle().fill(lineColor).frame(width: 3)
                        Circle().fill(lineColor.opacity(0.3)).frame(width: 6, height: 6)
                    }
                    .frame(width: 20)

                    Text(String(
                        localized: "\(travel.stopsCompleted - 2) intermediate stops",
                        comment: "Travel detail: intermediate stops count"
                    ))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(height: 24)
            }

            NavigationLink(value: StationDestination(stationSourceID: travel.toStationSourceID)) {
                HStack(spacing: 12) {
                    ZStack {
                        VStack(spacing: 0) {
                            Rectangle().fill(lineColor).frame(width: 3)
                            Rectangle().fill(.clear).frame(width: 3)
                        }
                        Circle().fill(lineColor).frame(width: 12, height: 12)
                            .overlay { Circle().strokeBorder(.white, lineWidth: 2) }
                    }
                    .frame(width: 20)

                    Text(toName)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .frame(height: 36)
            }
            .buttonStyle(.plain)
        }
    }
}
