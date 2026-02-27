import SwiftUI

enum WidgetColors {
    static let levelColors: [Color] = [.blue, .green, .purple, .orange, .red, .yellow]

    static func levelColor(for levelNumber: Int) -> Color {
        let index = (levelNumber - 1) % levelColors.count
        return levelColors[max(0, index)]
    }

    static func levelGradient(for levelNumber: Int) -> LinearGradient {
        let base = levelColor(for: levelNumber)
        return LinearGradient(
            colors: [base, base.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static let networkGradient = LinearGradient(
        colors: [.teal, .cyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let bronzeColor = Color(red: 0.80, green: 0.50, blue: 0.20)
    static let silverColor = Color.gray
    static let goldColor = Color.yellow
}
