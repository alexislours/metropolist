import SwiftUI

struct ConfettiView: View {
    let isActive: Bool
    let color: Color

    @State private var particles: [Particle] = []
    @State private var startTime: Date?
    @State private var cleanupTask: Task<Void, Never>?

    private static let particleCount = 80
    private static let lifetime: TimeInterval = 3.0

    var body: some View {
        TimelineView(.animation(paused: !isActive && particles.isEmpty)) { timeline in
            Canvas { context, size in
                let now = timeline.date
                guard let start = startTime else { return }
                let elapsed = now.timeIntervalSince(start)

                for particle in particles {
                    let age = elapsed - particle.delay
                    guard age > 0, age < Self.lifetime else { continue }

                    let progress = age / Self.lifetime
                    let gravity = 400.0 * age * age * 0.5

                    let posX = particle.startX * size.width + particle.velocityX * age
                    let posY = particle.startY * size.height + particle.velocityY * age + gravity

                    guard posY < size.height + 20 else { continue }

                    let opacity = 1.0 - max(0, (progress - 0.6) / 0.4)
                    let rotation = Angle.degrees(particle.rotationSpeed * age)
                    let wobble = sin(age * particle.wobbleFrequency) * particle.wobbleAmplitude

                    let point = CGPoint(x: posX + wobble, y: posY)

                    context.opacity = opacity * particle.opacity
                    context.translateBy(x: point.x, y: point.y)
                    context.rotate(by: rotation)

                    let rect = CGRect(
                        x: -particle.size / 2,
                        y: -particle.size / 2,
                        width: particle.size,
                        height: particle.size
                    )

                    switch particle.shape {
                    case .rect:
                        context.fill(Path(rect), with: .color(particle.color))
                    case .circle:
                        context.fill(Path(ellipseIn: rect), with: .color(particle.color))
                    case .strip:
                        let stripRect = CGRect(
                            x: -particle.size * 0.15,
                            y: -particle.size / 2,
                            width: particle.size * 0.3,
                            height: particle.size
                        )
                        context.fill(Path(stripRect), with: .color(particle.color))
                    }

                    context.rotate(by: -rotation)
                    context.translateBy(x: -point.x, y: -point.y)
                    context.opacity = 1
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, active in
            if active {
                emit()
            }
        }
        .onDisappear {
            cleanupTask?.cancel()
        }
    }

    private func emit() {
        startTime = Date()
        // Mix base color with festive accents for variety
        let accentColors: [Color] = [.yellow, .white, .orange]
        particles = (0 ..< Self.particleCount).map { index in
            let particleColor: Color = if index % 5 == 0 {
                accentColors[index % accentColors.count]
            } else {
                color
            }
            return Particle(color: particleColor)
        }

        // Clear particles after lifetime
        cleanupTask?.cancel()
        cleanupTask = Task {
            try? await Task.sleep(for: .seconds(Self.lifetime + 0.5))
            guard !Task.isCancelled else { return }
            particles = []
            startTime = nil
        }
    }
}

private struct Particle: Identifiable {
    let id = UUID()
    let startX: Double
    let startY: Double
    let velocityX: Double
    let velocityY: Double
    let rotationSpeed: Double
    let wobbleFrequency: Double
    let wobbleAmplitude: Double
    let size: Double
    let shape: Shape
    let color: Color
    let opacity: Double
    let delay: TimeInterval

    enum Shape: CaseIterable {
        case rect, circle, strip
    }

    init(color: Color) {
        self.color = color
        startX = Double.random(in: 0.1 ... 0.9)
        startY = Double.random(in: -0.1 ... 0.1)
        velocityX = Double.random(in: -80 ... 80)
        velocityY = Double.random(in: -350 ... -150)
        rotationSpeed = Double.random(in: -360 ... 360)
        wobbleFrequency = Double.random(in: 3 ... 8)
        wobbleAmplitude = Double.random(in: 5 ... 15)
        size = Double.random(in: 6 ... 12)
        shape = Shape.allCases.randomElement() ?? .rect
        opacity = Double.random(in: 0.7 ... 1.0)
        delay = Double.random(in: 0 ... 0.3)
    }
}
