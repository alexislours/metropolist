import SwiftUI

struct WidgetProgressRing: View {
    let progress: Double
    let gradient: LinearGradient
    var lineWidth: CGFloat = 7
    var size: CGFloat = 68

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)
        }
    }

    private var clampedProgress: Double {
        min(1.0, max(0, progress))
    }
}
