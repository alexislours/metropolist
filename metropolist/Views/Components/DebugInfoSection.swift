import SwiftUI

struct DebugInfoSection: View {
    let items: [(label: String, value: String)]

    var body: some View {
        CardSection {
            DisclosureGroup("Debug") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.label)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(item.value)
                                .font(.caption.monospaced())
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                        }
                        if index < items.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.top, 8)
            }
            .font(.subheadline.weight(.medium))
            .tint(.primary)
        }
    }
}
