import Charts
import SwiftUI

// MARK: - Activity Chart Card

struct ActivityChartCard: View {
    let travelsPerWeek: [WeeklyTravelCount]

    var body: some View {
        CardSection(title: String(localized: "ACTIVITY", comment: "Statistics: activity chart section header")) {
            if travelsPerWeek.isEmpty {
                Text(String(localized: "No travels recorded", comment: "Statistics: empty activity chart"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "Travels per week", comment: "Statistics: activity chart subtitle"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Chart(travelsPerWeek) { week in
                        BarMark(
                            x: .value(
                                String(localized: "Week", comment: "Statistics: chart axis label week"),
                                week.id, unit: .weekOfYear
                            ),
                            y: .value(
                                String(localized: "Travels", comment: "Statistics: chart axis label travels"),
                                week.count
                            )
                        )
                        .foregroundStyle(.blue.gradient)
                        .cornerRadius(4)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { value in
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(date, format: .dateTime.day().month(.abbreviated))
                                }
                            }
                            AxisGridLine()
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(height: 180)
                }
            }
        }
    }
}

// MARK: - Time Pattern Card

struct TimePatternCard: View {
    let busiestDay: DayOfWeekStat?
    let busiestHour: HourOfDayStat?

    var body: some View {
        CardSection(title: String(localized: "TIME PATTERNS", comment: "Statistics: time patterns section header")) {
            if busiestDay == nil, busiestHour == nil {
                Text(String(localized: "No travels recorded", comment: "Statistics: empty time patterns"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 16) {
                    if let day = busiestDay {
                        DayOfWeekChart(stat: day)
                    }

                    if busiestDay != nil, busiestHour != nil {
                        Divider()
                    }

                    if let hour = busiestHour {
                        HourOfDayChart(stat: hour)
                    }
                }
            }
        }
    }
}

// MARK: - Day of Week Chart

private struct DayOfWeekChart: View {
    let stat: DayOfWeekStat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(String(
                    localized: "Busiest day: \(stat.dayName)",
                    comment: "Statistics: busiest day of week"
                ))
                .font(.subheadline.weight(.medium))
            } icon: {
                Image(systemName: "calendar")
                    .foregroundStyle(.blue)
            }

            Chart(stat.allDays) { day in
                BarMark(
                    x: .value(
                        String(localized: "Day", comment: "Statistics: chart axis label day"),
                        String(day.dayName.prefix(3))
                    ),
                    y: .value(
                        String(localized: "Travels", comment: "Statistics: chart axis label travels"),
                        day.count
                    )
                )
                .foregroundStyle(day.dayIndex == stat.dayIndex ? Color.blue : Color.blue.opacity(0.3))
                .cornerRadius(4)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 120)
        }
    }
}

// MARK: - Hour of Day Chart

private struct HourOfDayChart: View {
    let stat: HourOfDayStat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(String(
                    localized: "Peak hour: \(stat.hour):00",
                    comment: "Statistics: busiest hour of day"
                ))
                .font(.subheadline.weight(.medium))
            } icon: {
                Image(systemName: "clock")
                    .foregroundStyle(.orange)
            }

            Chart(stat.allHours) { hourData in
                BarMark(
                    x: .value(
                        String(localized: "Hour", comment: "Statistics: chart axis label hour"),
                        hourData.hour
                    ),
                    y: .value(
                        String(localized: "Travels", comment: "Statistics: chart axis label travels"),
                        hourData.count
                    )
                )
                .foregroundStyle(hourData.hour == stat.hour ? Color.orange : Color.orange.opacity(0.3))
                .cornerRadius(2)
            }
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                    if let hour = value.as(Int.self) {
                        AxisValueLabel {
                            Text("\(hour)h")
                        }
                    }
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 120)
        }
    }
}
