import SwiftUI

// MARK: - Rankings Card

struct RankingsCard: View {
    let topStations: [RankedStation]
    let topLines: [RankedLine]

    var body: some View {
        CardSection(title: String(localized: "RANKINGS", comment: "Statistics: rankings section header")) {
            if topStations.isEmpty, topLines.isEmpty {
                Text(String(localized: "No data yet", comment: "Statistics: empty rankings"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 16) {
                    if !topStations.isEmpty {
                        TopStationsSection(stations: topStations)
                    }

                    if !topStations.isEmpty, !topLines.isEmpty {
                        Divider()
                    }

                    if !topLines.isEmpty {
                        TopLinesSection(lines: topLines)
                    }
                }
            }
        }
    }
}

// MARK: - Top Stations

private struct TopStationsSection: View {
    let stations: [RankedStation]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Most visited stops", comment: "Statistics: top stations subtitle"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(Array(stations.enumerated()), id: \.element.id) { index, station in
                HStack {
                    Text("\(index + 1).")
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .leading)

                    Text(station.name)
                        .font(.subheadline)
                        .lineLimit(1)

                    Spacer()

                    Text(String(
                        localized: "\(station.visitCount) visits",
                        comment: "Statistics: station visit count"
                    ))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Top Lines

private struct TopLinesSection: View {
    let lines: [RankedLine]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Most used lines", comment: "Statistics: top lines subtitle"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                HStack(spacing: 8) {
                    Text("\(index + 1).")
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .leading)

                    Text(line.shortName)
                        .font(.caption2.bold())
                        .foregroundStyle(Color(hex: line.textColor))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .frame(minWidth: 32, minHeight: 24)
                        .background(Color(hex: line.color), in: RoundedRectangle(cornerRadius: 4))

                    Text(line.mode.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(String(
                        localized: "\(line.travelCount) travels",
                        comment: "Statistics: line travel count"
                    ))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Geographic Coverage Card

struct GeographicCoverageCard: View {
    let departmentCoverage: [DepartmentCoverage]
    let fareZoneCoverage: [FareZoneCoverage]

    var body: some View {
        CardSection(title: String(localized: "GEOGRAPHIC COVERAGE", comment: "Statistics: geographic section header")) {
            if departmentCoverage.isEmpty, fareZoneCoverage.isEmpty {
                Text(String(localized: "No data yet", comment: "Statistics: empty geographic"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 16) {
                    if !departmentCoverage.isEmpty {
                        DepartmentSection(departments: departmentCoverage)
                    }

                    if !departmentCoverage.isEmpty, !fareZoneCoverage.isEmpty {
                        Divider()
                    }

                    if !fareZoneCoverage.isEmpty {
                        FareZoneSection(zones: fareZoneCoverage)
                    }
                }
            }
        }
    }
}

// MARK: - Department Section

private struct DepartmentSection: View {
    let departments: [DepartmentCoverage]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Departments", comment: "Statistics: department coverage subtitle"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(departments) { dept in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(dept.label)
                            .font(.subheadline)

                        Spacer()

                        Text("\(dept.visited)/\(dept.total)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)

                        Text("\(Int((dept.percentage * 100).rounded()))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }

                    ProgressView(value: dept.percentage)
                        .tint(dept.percentage >= 1.0 ? .yellow : .blue)
                }
            }
        }
    }
}

// MARK: - Fare Zone Section

private struct FareZoneSection: View {
    let zones: [FareZoneCoverage]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Fare zones", comment: "Statistics: fare zone coverage subtitle"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(zones) { zone in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(String(localized: "Zone \(zone.zone)", comment: "Statistics: fare zone number"))
                            .font(.subheadline)

                        Spacer()

                        Text("\(zone.visited)/\(zone.total)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)

                        Text("\(Int((zone.percentage * 100).rounded()))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }

                    ProgressView(value: zone.percentage)
                        .tint(zone.percentage >= 1.0 ? .yellow : .green)
                }
            }
        }
    }
}
