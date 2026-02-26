import SwiftUI
import TransitModels

struct LineBadge: View {
    let line: TransitLine

    var body: some View {
        Text(line.shortName)
            .font(.caption2.bold())
            .foregroundStyle(Color(hex: line.textColor))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .frame(minWidth: 32, minHeight: 24)
            .background(Color(hex: line.color), in: RoundedRectangle(cornerRadius: 4))
            .accessibilityLabel(Text(line.shortName))
    }
}
