import SwiftUI

struct LineProgressRow: View {
    let meta: LineMetadata
    let progress: LineProgress?

    var body: some View {
        HStack(spacing: 8) {
            // Mini line badge
            Text(meta.shortName)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color(hex: meta.textColor))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .frame(minWidth: 28, minHeight: 18)
                .background(Color(hex: meta.color), in: RoundedRectangle(cornerRadius: 3))

            if let tier = progress?.badge, tier != .locked {
                Image(systemName: tier.systemImage)
                    .font(.system(size: 10))
                    .foregroundStyle(tier.color)
            }

            // Progress bar
            ProgressView(value: progress?.fraction ?? 0)
                .tint(Color(hex: meta.color))

            Text("\(progress?.completedStops ?? 0)/\(progress?.totalStops ?? 0)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 40, alignment: .trailing)
        }
    }
}
