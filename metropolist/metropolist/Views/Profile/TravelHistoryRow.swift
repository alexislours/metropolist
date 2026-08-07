import SwiftUI
import TransitModels

struct TravelHistoryRow: View {
    let travel: Travel
    let line: TransitLine?
    let fromName: String
    let toName: String

    private var mode: TransitMode? {
        line.flatMap { TransitMode(rawValue: $0.mode) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Line badge + mode + date
            HStack {
                if let line {
                    LineBadge(line: line)
                } else {
                    Text(String(localized: "Removed line", comment: "Travel history: line no longer exists"))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if let mode {
                    Text(mode.label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(travel.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Station itinerary
            HStack(alignment: .top, spacing: 10) {
                // Dot connector
                VStack(spacing: 2) {
                    Circle()
                        .fill(line.map { Color(hex: $0.color) } ?? .secondary)
                        .frame(width: 8, height: 8)

                    RoundedRectangle(cornerRadius: 1)
                        .fill(line.map { Color(hex: $0.color) } ?? .secondary)
                        .opacity(0.4)
                        .frame(width: 2, height: 16)

                    Circle()
                        .fill(line.map { Color(hex: $0.color) } ?? .secondary)
                        .frame(width: 8, height: 8)
                }
                .padding(.top, 4)

                VStack(alignment: .leading, spacing: 12) {
                    Text(fromName)
                        .font(.subheadline)
                        .lineLimit(1)

                    Text(toName)
                        .font(.subheadline)
                        .lineLimit(1)
                }
            }

            // Stops count
            Label(
                String(localized: "\(travel.stopsCompleted) stops", comment: "Travel history: stops traveled count"),
                systemImage: "mappin.and.ellipse"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel({
            var parts: [String] = []
            if let line {
                parts.append(line.shortName)
            }
            if let mode {
                parts.append(mode.label)
            }
            parts.append(fromName)
            parts.append(String(localized: "to", comment: "Travel history accessibility: route separator"))
            parts.append(toName)
            parts.append(String(
                localized: "\(travel.stopsCompleted) stops",
                comment: "Travel history accessibility: stops count"
            ))
            parts.append(travel.createdAt.formatted(.dateTime.month(.abbreviated).day()))
            return parts.joined(separator: ", ")
        }())
    }
}
