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
    static let coffee = Color(red: 0.72, green: 0.29, blue: 0.055)
    static let coffeeLight = Color(red: 1.00, green: 0.67, blue: 0.29)
    static let coffeeGlow = Color(red: 1.00, green: 0.82, blue: 0.55)
    static let plumShadow = Color(red: 0.34, green: 0.30, blue: 0.56)
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
    @State private var motionPhase: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let orbWidth = min(proxy.size.width * 0.88, 318)
            let orbHeight = min(proxy.size.height * 0.90, 160)

            ZStack {
                CafadeLiquidOrbShape(phase: motionPhase + 0.08)
                    .fill(CafadePalette.plumShadow.opacity(0.22))
                    .frame(width: orbWidth * 0.96, height: orbHeight * 0.82)
                    .blur(radius: 15)
                    .offset(x: 12, y: 15)

                CafadeLiquidOrbShape(phase: motionPhase)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: CafadePalette.coffeeGlow.opacity(0.98), location: 0),
                                .init(color: CafadePalette.coffeeLight.opacity(0.98), location: 0.26),
                                .init(color: CafadePalette.saffron.opacity(0.96), location: 0.54),
                                .init(color: CafadePalette.coffee.opacity(0.72), location: 0.82),
                                .init(color: CafadePalette.plumShadow.opacity(0.28), location: 1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        CafadeLiquidOrbShape(phase: motionPhase)
                            .fill(
                                RadialGradient(
                                    colors: [Color.white.opacity(0.48), .clear],
                                    center: .topLeading,
                                    startRadius: 0,
                                    endRadius: orbWidth * 0.62
                                )
                            )
                    }
                    .overlay {
                        CafadeLiquidOrbShape(phase: motionPhase + 0.12)
                            .fill(
                                RadialGradient(
                                    colors: [.clear, CafadePalette.plumShadow.opacity(0.24)],
                                    center: .bottomTrailing,
                                    startRadius: orbWidth * 0.10,
                                    endRadius: orbWidth * 0.72
                                )
                            )
                    }
                    .overlay {
                        CafadeLiquidOrbShape(phase: motionPhase + 0.06)
                            .fill(
                                RadialGradient(
                                    colors: [CafadePalette.coffeeGlow.opacity(0.48), .clear],
                                    center: .bottomLeading,
                                    startRadius: 0,
                                    endRadius: orbWidth * 0.62
                                )
                            )
                    }
                    .overlay {
                        CafadeLiquidSurface(phase: motionPhase + 0.04)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.25),
                                        CafadePalette.coffeeGlow.opacity(0.12),
                                        .clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .blendMode(.screen)
                    }
                    .overlay {
                        CafadeLiquidSheen(phase: motionPhase)
                            .stroke(Color.white.opacity(0.52), lineWidth: 1.15)
                            .blur(radius: 0.15)
                    }
                    .overlay {
                        CafadeLiquidOrbShape(phase: motionPhase + 0.18)
                            .stroke(Color.white.opacity(0.74), lineWidth: 1.25)
                            .padding(6)
                    }
                    .overlay {
                        CafadeLiquidOrbShape(phase: motionPhase + 0.24)
                            .stroke(CafadePalette.coffeeGlow.opacity(0.68), lineWidth: 1.15)
                            .padding(14)
                    }
                    .overlay {
                        Capsule()
                            .fill(Color.white.opacity(0.22))
                            .frame(width: orbWidth * 0.22, height: 11)
                            .blur(radius: 5)
                            .rotationEffect(.degrees(-16))
                            .offset(x: -orbWidth * 0.22, y: -orbHeight * 0.22)
                    }
                    .frame(width: orbWidth, height: orbHeight)
                    .shadow(color: CafadePalette.coffee.opacity(0.28), radius: 18, y: 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(
                x: 1 + sin(motionPhase * .pi * 2) * 0.018,
                y: 1 - sin(motionPhase * .pi * 2) * 0.010
            )
            .rotationEffect(.degrees(-7 + sin(motionPhase * .pi * 2) * 1.1))
            .offset(y: sin(motionPhase * .pi * 1.45) * 2.5)
            .opacity(estimate.typicalMg > 0 ? 0.92 : 0.48)
        }
        .accessibilityHidden(true)
        .task(id: "\(estimate.typicalMg)-\(reduceMotion)") {
            motionPhase = 0
            guard !reduceMotion, estimate.typicalMg > 0 else { return }
            withAnimation(.easeInOut(duration: 3.8).repeatForever(autoreverses: true)) {
                motionPhase = 1
            }
        }
    }
}

private struct CafadeLiquidOrbShape: Shape {
    var phase: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radiusX = rect.width * 0.5
        let radiusY = rect.height * 0.5
        let count = 14
        let profile: [CGFloat] = [
            0.98, 1.03, 1.02, 0.96, 0.91, 0.97, 1.06,
            1.10, 1.06, 1.00, 1.04, 1.08, 1.04, 0.99
        ]
        let phaseAngle = phase * 2 * .pi
        let points = (0..<count).map { index in
            let theta = CGFloat(index) / CGFloat(count) * 2 * .pi - .pi / 2
            let wobble = 1
                + (profile[index] - 1)
                + sin(theta * 2 + phaseAngle) * 0.032
                + cos(theta * 3 - phaseAngle * 0.72) * 0.018
            let xBias = 1 + sin(theta + 0.42) * 0.028
            let yWobble = 1
                + sin(theta * 2 - phaseAngle * 0.8) * 0.026
                + cos(theta - 0.2) * 0.018
            return CGPoint(
                x: center.x + cos(theta) * radiusX * wobble * xBias,
                y: center.y + sin(theta) * radiusY * yWobble
            )
        }

        var path = Path()
        let first = midpoint(points[count - 1], points[0])
        path.move(to: first)
        for index in 0..<count {
            let current = points[index]
            let next = points[(index + 1) % count]
            path.addQuadCurve(to: midpoint(current, next), control: current)
        }
        path.closeSubpath()
        return path
    }

    private func midpoint(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
        CGPoint(x: (lhs.x + rhs.x) * 0.5, y: (lhs.y + rhs.y) * 0.5)
    }
}

private struct CafadeLiquidSurface: Shape {
    var phase: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let drift = sin(phase * 2 * .pi) * rect.height * 0.025
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.10, y: rect.height * 0.40 + drift))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.87, y: rect.height * 0.29 - drift),
            control1: CGPoint(x: rect.width * 0.30, y: rect.height * 0.09 - drift),
            control2: CGPoint(x: rect.width * 0.67, y: rect.height * 0.49 + drift)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.10, y: rect.height * 0.40 + drift),
            control1: CGPoint(x: rect.width * 0.67, y: rect.height * 0.54 + drift),
            control2: CGPoint(x: rect.width * 0.28, y: rect.height * 0.62 - drift)
        )
        path.closeSubpath()
        return path
    }
}

private struct CafadeLiquidSheen: Shape {
    var phase: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let drift = sin(phase * 2 * .pi) * rect.height * 0.035
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.10, y: rect.height * 0.36 + drift))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.87, y: rect.height * 0.26 - drift),
            control1: CGPoint(x: rect.width * 0.30, y: rect.height * 0.13 - drift),
            control2: CGPoint(x: rect.width * 0.68, y: rect.height * 0.48 + drift)
        )
        return path
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
                        Gradient(colors: [CafadePalette.coffeeLight.opacity(0.42), CafadePalette.saffron.opacity(0.18), CafadePalette.lavender.opacity(0.18), .clear]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: size.width, y: size.height)
                    )
                )
                context.stroke(
                    line,
                    with: .linearGradient(
                        Gradient(colors: [CafadePalette.coffee, CafadePalette.saffron, CafadePalette.coral]),
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
