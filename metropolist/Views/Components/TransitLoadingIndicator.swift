import SwiftUI
import UIKit

struct TransitLoadingIndicator: View {
    var tint: Color = .blue

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            ProgressView()
                .tint(tint)
        } else {
            TransitDotsView(tint: tint)
                .frame(width: 56, height: 10)
        }
    }
}

// MARK: - UIKit bridge

private struct TransitDotsView: UIViewRepresentable {
    let tint: Color

    func makeUIView(context _: Context) -> TransitDotsUIView {
        TransitDotsUIView(tint: UIColor(tint))
    }

    func updateUIView(_ uiView: TransitDotsUIView, context _: Context) {
        uiView.applyTint(UIColor(tint))
    }

    static func dismantleUIView(_ uiView: TransitDotsUIView, coordinator _: ()) {
        uiView.stopAnimations()
    }
}

// MARK: - Core Animation implementation

private final class TransitDotsUIView: UIView {
    private let dotSize: CGFloat = 8
    private let lineLength: CGFloat = 16
    private let lineThickness: CGFloat = 2
    private let dotCount = 3

    private var dotLayers: [CALayer] = []
    private var lineLayers: [CALayer] = []

    init(tint: UIColor) {
        super.init(frame: .zero)
        buildLayers(tint: tint)
        startAnimations()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    func applyTint(_ color: UIColor) {
        for dot in dotLayers {
            dot.backgroundColor = color.cgColor
        }
        for line in lineLayers {
            line.backgroundColor = color.withAlphaComponent(0.2).cgColor
        }
    }

    private func buildLayers(tint: UIColor) {
        let viewHeight = dotSize * 1.2
        let centerY = viewHeight / 2
        var offsetX: CGFloat = 0

        for index in 0 ..< dotCount {
            if index > 0 {
                let line = CALayer()
                line.frame = CGRect(x: offsetX, y: centerY - lineThickness / 2, width: lineLength, height: lineThickness)
                line.cornerRadius = lineThickness / 2
                line.backgroundColor = tint.withAlphaComponent(0.2).cgColor
                layer.addSublayer(line)
                lineLayers.append(line)
                offsetX += lineLength
            }

            let dot = CALayer()
            dot.frame = CGRect(x: offsetX, y: centerY - dotSize / 2, width: dotSize, height: dotSize)
            dot.cornerRadius = dotSize / 2
            dot.backgroundColor = tint.cgColor
            dot.opacity = 0.3
            layer.addSublayer(dot)
            dotLayers.append(dot)
            offsetX += dotSize
        }
    }

    private func startAnimations() {
        let pulseDuration: CFTimeInterval = 0.3
        let stagger: CFTimeInterval = 0.35
        let cycleDuration = stagger * CFTimeInterval(dotCount)

        for (index, dot) in dotLayers.enumerated() {
            let opacity = CABasicAnimation(keyPath: "opacity")
            opacity.fromValue = 0.3
            opacity.toValue = 1.0
            opacity.duration = pulseDuration
            opacity.autoreverses = true
            opacity.timingFunction = CAMediaTimingFunction(name: .easeIn)

            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 1.0
            scale.toValue = 1.2
            scale.duration = pulseDuration
            scale.autoreverses = true
            scale.timingFunction = CAMediaTimingFunction(name: .easeIn)

            let group = CAAnimationGroup()
            group.animations = [opacity, scale]
            group.duration = cycleDuration
            group.repeatCount = .greatestFiniteMagnitude
            group.beginTime = CACurrentMediaTime() + Double(index) * stagger

            dot.add(group, forKey: "pulse")
        }
    }

    func stopAnimations() {
        for dot in dotLayers {
            dot.removeAllAnimations()
        }
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil {
            stopAnimations()
        } else if dotLayers.first?.animation(forKey: "pulse") == nil {
            startAnimations()
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: dotSize * CGFloat(dotCount) + lineLength * CGFloat(dotCount - 1),
            height: dotSize * 1.2
        )
    }
}
