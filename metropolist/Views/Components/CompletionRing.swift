import SwiftUI

struct CompletionRing: View {
    let completed: Int
    let total: Int
    var size: CGFloat = 32
    var showPercentage: Bool = false
    var tint: Color?

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    private var percentageText: String {
        guard total > 0 else { return "0%" }
        let pct = Int((Double(completed) / Double(total) * 100).rounded())
        return "\(pct)%"
    }

    private var strokeWidth: CGFloat {
        max(3, size * 0.06)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: strokeWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    resolvedColor,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if size >= 60 {
                if showPercentage {
                    Text(percentageText)
                        .font(.system(size: size * 0.24, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                } else {
                    VStack(spacing: 0) {
                        Text("\(completed)")
                            .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        Text("/ \(total)")
                            .font(.system(size: size * 0.15, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    private var resolvedColor: Color {
        if let tint { return tint }
        if progress >= 1.0 { return .yellow }
        if progress >= 0.5 { return .green }
        return .blue
    }
}
