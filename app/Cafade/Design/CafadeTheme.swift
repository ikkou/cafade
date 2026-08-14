import SwiftUI

enum CafadePalette {
    // The visual language is intentionally editorial: warm paper, near-black ink,
    // and a small set of translucent fruit-toned accents.
    static let background = Color(red: 0.972, green: 0.962, blue: 0.938)
    static let surface = Color(red: 0.995, green: 0.988, blue: 0.972)
    static let surfaceMuted = Color(red: 0.944, green: 0.934, blue: 0.912)
    static let ink = Color(red: 0.095, green: 0.091, blue: 0.085)
    static let paper = ink
    static let mist = Color(red: 0.40, green: 0.38, blue: 0.35)
    static let saffron = Color(red: 0.91, green: 0.43, blue: 0.12)
    static let mint = Color(red: 0.22, green: 0.47, blue: 0.30)
    static let sky = Color(red: 0.28, green: 0.40, blue: 0.70)
    static let coral = Color(red: 0.83, green: 0.26, blue: 0.12)
    static let lavender = Color(red: 0.46, green: 0.39, blue: 0.67)
    static let line = ink.opacity(0.12)

    // Compatibility names used by the first implementation.
    static let midnight = background
    static let deepNavy = surfaceMuted
}

struct CafadeBackground: View {
    var body: some View {
        ZStack {
            CafadePalette.background
            LinearGradient(
                colors: [CafadePalette.surface.opacity(0.52), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(CafadePalette.saffron.opacity(0.10))
                .frame(width: 330, height: 330)
                .blur(radius: 78)
                .offset(x: 154, y: -288)
            Circle()
                .fill(CafadePalette.lavender.opacity(0.11))
                .frame(width: 380, height: 380)
                .blur(radius: 96)
                .offset(x: -178, y: 320)
        }
        .ignoresSafeArea()
    }
}

struct CafadeGlassCard<Content: View>: View {
    private let content: Content
    private let tint: Color?

    init(tint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.tint = tint
    }

    var body: some View {
        content
            .padding(18)
            .background(CafadePalette.surface.opacity(0.84), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(CafadePalette.line, lineWidth: 1)
            }
            .shadow(color: CafadePalette.ink.opacity(0.055), radius: 16, y: 8)
            .modifier(CafadeGlassModifier(tint: tint))
    }
}

private struct CafadeGlassModifier: ViewModifier {
    let tint: Color?

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(
                .regular.tint((tint ?? CafadePalette.surface).opacity(0.34)),
                in: .rect(cornerRadius: 22)
            )
        } else {
            content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}

struct CafadeSectionLabel: View {
    let eyebrow: String
    let title: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(eyebrow.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(1.8)
                .foregroundStyle(CafadePalette.saffron)
            Text(title)
                .font(.system(size: 24, weight: .regular, design: .serif))
                .foregroundStyle(CafadePalette.ink)
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(CafadePalette.mist)
            }
        }
    }
}

struct CafadePill: View {
    let title: String
    var color: Color = CafadePalette.mist

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.11), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.16), lineWidth: 1))
    }
}

struct CafadeCaffeineOrb: View {
    let estimate: CaffeineEstimate
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var motionPhase = 0.0

    var body: some View {
        ZStack {
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [CafadePalette.saffron.opacity(0.82), CafadePalette.coral.opacity(0.68), CafadePalette.lavender.opacity(0.44)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Ellipse()
                        .stroke(CafadePalette.surface.opacity(0.7), lineWidth: 1)
                        .padding(5)
                }
                .shadow(color: CafadePalette.saffron.opacity(0.28), radius: 18, y: 8)
            Ellipse()
                .stroke(CafadePalette.surface.opacity(0.55), lineWidth: 1)
                .padding(16)
            Circle()
                .fill(CafadePalette.surface.opacity(0.82))
                .frame(width: 9, height: 9)
        }
        .scaleEffect(
            x: 1 + CGFloat(sin(motionPhase)) * 0.035,
            y: 1 - CGFloat(sin(motionPhase)) * 0.018
        )
        .rotationEffect(.degrees(-8 + sin(motionPhase) * 1.8))
        .offset(y: CGFloat(sin(motionPhase * 0.72)) * 2.5)
        .opacity(estimate.typicalMg > 0 ? 0.72 : 0.12)
        .accessibilityHidden(true)
        .task(id: estimate.typicalMg) {
            guard !reduceMotion, estimate.typicalMg > 0 else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                motionPhase = 1
            }
        }
    }
}

struct CafadePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(CafadePalette.surface)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(CafadePalette.ink, in: Capsule())
            .shadow(color: CafadePalette.ink.opacity(0.16), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

struct CafadeSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.medium))
            .foregroundStyle(CafadePalette.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(CafadePalette.surface.opacity(0.62), in: Capsule())
            .overlay(Capsule().stroke(CafadePalette.line, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

struct CaffeineValueLabel: View {
    let estimate: CaffeineEstimate
    var size: CGFloat = 54

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 7) {
            Text(estimate.shortDisplayText)
                .font(.system(size: size, weight: .regular, design: .serif))
                .monospacedDigit()
                .foregroundStyle(CafadePalette.ink)
            Text("mg")
                .font(.system(size: size * 0.34, weight: .medium, design: .serif))
                .foregroundStyle(CafadePalette.saffron)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Estimated caffeine remaining")
        .accessibilityValue(estimate.displayText)
    }
}

struct CaffeineCurveView: View {
    let events: [IntakeEvent]
    let now: Date
    let halfLifeHours: Int
    var reduceMotion: Bool = false

    var body: some View {
        let points = CaffeineCalculator.timeline(
            events: events,
            centeredAt: now,
            halfLifeHours: halfLifeHours
        )

        VStack(spacing: 10) {
            Canvas { context, size in
                guard let maxValue = points.map(\.estimate.maxMg).max(), maxValue > 0 else {
                    drawEmpty(context: &context, size: size)
                    return
                }

                let yMax = max(maxValue * 1.15, 20)
                let coordinate: (Int) -> CGPoint = { index in
                    let x = size.width * CGFloat(index) / CGFloat(max(points.count - 1, 1))
                    let y = size.height - size.height * CGFloat(points[index].estimate.typicalMg / yMax)
                    return CGPoint(x: x, y: y)
                }

                var area = Path()
                var line = Path()
                for index in points.indices {
                    let point = coordinate(index)
                    if index == points.startIndex {
                        line.move(to: point)
                        area.move(to: CGPoint(x: point.x, y: size.height))
                        area.addLine(to: point)
                    } else {
                        line.addLine(to: point)
                        area.addLine(to: point)
                    }
                }
                if let last = points.indices.last {
                    let point = coordinate(last)
                    area.addLine(to: CGPoint(x: point.x, y: size.height))
                    area.closeSubpath()
                }

                context.fill(
                    area,
                    with: .linearGradient(
                        Gradient(colors: [CafadePalette.saffron.opacity(0.36), CafadePalette.lavender.opacity(0.16), .clear]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: size.width, y: size.height)
                    )
                )
                context.stroke(
                    line,
                    with: .linearGradient(
                        Gradient(colors: [CafadePalette.saffron, CafadePalette.coral]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width, y: 0)
                    ),
                    style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
                )

                let nowIndex = points.enumerated().min {
                    abs($0.element.date.timeIntervalSince(now)) < abs($1.element.date.timeIntervalSince(now))
                }?.offset ?? 0
                let nowPoint = coordinate(nowIndex)
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: nowPoint.x, y: 0))
                        path.addLine(to: CGPoint(x: nowPoint.x, y: size.height))
                    },
                    with: .color(CafadePalette.ink.opacity(0.24)),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 5])
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: nowPoint.x - 6, y: nowPoint.y - 6, width: 12, height: 12)),
                    with: .color(CafadePalette.surface)
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: nowPoint.x - 3.5, y: nowPoint.y - 3.5, width: 7, height: 7)),
                    with: .color(CafadePalette.saffron)
                )
            }
            .frame(height: 160)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: events.count)

            HStack {
                Text("12h ago")
                Spacer()
                Text("Now")
                    .foregroundStyle(CafadePalette.saffron)
                Spacer()
                Text("in 12h")
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(CafadePalette.mist)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Caffeine fade curve for the last and next twelve hours")
        .accessibilityValue(CaffeineCalculator.estimate(events: events, at: now, halfLifeHours: halfLifeHours).displayText)
    }

    private func drawEmpty(context: inout GraphicsContext, size: CGSize) {
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: 0, y: size.height * 0.72))
                path.addLine(to: CGPoint(x: size.width, y: size.height * 0.72))
            },
            with: .color(CafadePalette.line),
            style: StrokeStyle(lineWidth: 1, dash: [3, 5])
        )
    }
}

struct CafadeEmptyState: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(CafadePalette.saffron)
            Text(title)
                .font(.headline)
                .foregroundStyle(CafadePalette.ink)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(CafadePalette.mist)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }
}
