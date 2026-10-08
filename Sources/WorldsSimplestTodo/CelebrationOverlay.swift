import SwiftUI

struct CelebrationOverlay: View {
    private struct Spark {
        let burst: Int
        let angle: Double
        let speed: Double
        let size: Double
        let delay: Double
        let colorIndex: Int
    }

    private static let colors: [Color] = [
        .pink, .orange, .yellow, .green, .cyan, .blue, .purple
    ]

    let burstID: Int
    private let sparks: [Spark]
    @State private var startedAt: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(burstID: Int) {
        self.burstID = burstID
        sparks = Self.makeSparks(seed: burstID)
        _startedAt = State(initialValue: Date())
    }

    var body: some View {
        Group {
            if reduceMotion {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 74, weight: .semibold))
                    .foregroundStyle(.green)
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    Canvas { context, size in
                        drawFireworks(
                            in: &context,
                            size: size,
                            elapsed: timeline.date.timeIntervalSince(startedAt)
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawFireworks(
        in context: inout GraphicsContext,
        size: CGSize,
        elapsed: TimeInterval
    ) {
        let origins = [
            CGPoint(x: size.width * 0.24, y: size.height * 0.42),
            CGPoint(x: size.width * 0.50, y: size.height * 0.31),
            CGPoint(x: size.width * 0.76, y: size.height * 0.42)
        ]

        for burst in origins.indices {
            let delay = Double(burst) * 0.08
            let localTime = elapsed - delay
            guard localTime >= 0, localTime < 0.7 else { continue }

            let radius = 18 + localTime * 120
            let opacity = max(0, 0.55 * (1 - localTime / 0.7))
            let ring = CGRect(
                x: origins[burst].x - radius,
                y: origins[burst].y - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.stroke(
                Path(ellipseIn: ring),
                with: .color(Self.colors[(burst * 2 + burstID) % Self.colors.count].opacity(opacity)),
                lineWidth: 2
            )
        }

        for spark in sparks {
            let localTime = elapsed - spark.delay
            let duration = 1.15
            guard localTime >= 0, localTime < duration else { continue }

            let progress = localTime / duration
            let origin = origins[spark.burst]
            let distance = spark.speed * localTime
            let x = origin.x + cos(spark.angle) * distance
            let y = origin.y + sin(spark.angle) * distance + 92 * localTime * localTime
            let opacity = pow(1 - progress, 1.5)
            let diameter = spark.size * (0.75 + 0.25 * (1 - progress))
            let rect = CGRect(
                x: x - diameter / 2,
                y: y - diameter / 2,
                width: diameter,
                height: diameter
            )

            context.fill(
                Path(ellipseIn: rect),
                with: .color(Self.colors[spark.colorIndex].opacity(opacity))
            )
        }
    }

    private static func makeSparks(seed: Int) -> [Spark] {
        var state = UInt64(truncatingIfNeeded: seed) &+ 0x9E3779B97F4A7C15

        func nextValue() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 11) / Double(UInt64.max >> 11)
        }

        return (0..<3).flatMap { burst in
            (0..<26).map { index in
                let baseAngle = Double(index) / 26.0 * Double.pi * 2
                let jitter = (nextValue() - 0.5) * 0.16
                return Spark(
                    burst: burst,
                    angle: baseAngle + jitter,
                    speed: 82 + nextValue() * 92,
                    size: 4 + nextValue() * 5,
                    delay: Double(burst) * 0.08 + nextValue() * 0.04,
                    colorIndex: Int(nextValue() * Double(colors.count)) % colors.count
                )
            }
        }
    }
}
