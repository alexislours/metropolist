import SwiftUI

struct EnhancedStopRow: View {
    let name: String
    let isCompleted: Bool
    let isTerminus: Bool
    let connectionCount: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isCompleted ? .green : .secondary)
                .font(.body)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(isTerminus ? .semibold : .regular)
                    .lineLimit(1)

                if connectionCount > 0 {
                    Label(
                        String(localized: "\(connectionCount) connections", comment: "Stop row: transfer connections count"),
                        systemImage: "arrow.triangle.branch"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 36, alignment: .leading)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}
