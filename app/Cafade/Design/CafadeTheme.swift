import SwiftUI

enum CafadePalette {
    static let midnight = Color(red: 0.055, green: 0.075, blue: 0.12)
    static let deepNavy = Color(red: 0.085, green: 0.12, blue: 0.18)
    static let ink = Color(red: 0.12, green: 0.14, blue: 0.18)
    static let paper = Color(red: 0.96, green: 0.95, blue: 0.91)
    static let mist = Color(red: 0.78, green: 0.82, blue: 0.84)
    static let saffron = Color(red: 0.98, green: 0.69, blue: 0.24)
    static let mint = Color(red: 0.42, green: 0.82, blue: 0.70)
    static let sky = Color(red: 0.40, green: 0.68, blue: 0.96)
    static let coral = Color(red: 0.96, green: 0.43, blue: 0.35)
    static let lavender = Color(red: 0.70, green: 0.60, blue: 0.95)
    static let line = Color.white.opacity(0.12)
}

struct CafadeBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [CafadePalette.midnight, CafadePalette.deepNavy],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(CafadePalette.saffron.opacity(0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: 130, y: -260)
            Circle()
                .fill(CafadePalette.sky.opacity(0.09))
                .frame(width: 330, height: 330)
                .blur(radius: 90)
                .offset(x: -190, y: 300)
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
            .padding(20)
            .background(CafadePalette.deepNavy.opacity(0.38), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(CafadePalette.line, lineWidth: 1)
            }
            .modifier(CafadeGlassModifier(tint: tint))
    }
}

private struct CafadeGlassModifier: ViewModifier {
    let tint: Color?

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            if let tint {
                content.glassEffect(.regular.tint(tint), in: .rect(cornerRadius: 26))
            } else {
                content.glassEffect(.regular, in: .rect(cornerRadius: 26))
            }
        } else {
            content
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
                .font(.system(.title3, design: .serif).weight(.medium))
                .foregroundStyle(CafadePalette.paper)
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
            .background(color.opacity(0.13), in: Capsule())
    }
}

struct CafadePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(CafadePalette.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(CafadePalette.saffron, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

struct CafadeSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.medium))
            .foregroundStyle(CafadePalette.paper)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(CafadePalette.paper.opacity(0.08), in: Capsule())
            .overlay(Capsule().stroke(CafadePalette.line, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct CaffeineValueLabel: View {
    let estimate: CaffeineEstimate
    var size: CGFloat = 54

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 7) {
            Text(estimate.shortDisplayText)
                .font(.system(size: size, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(CafadePalette.paper)
            Text("mg")
                .font(.system(size: size * 0.34, weight: .semibold, design: .rounded))
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
                        Gradient(colors: [CafadePalette.saffron.opacity(0.30), CafadePalette.saffron.opacity(0.01)]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )
                context.stroke(
                    line,
                    with: .linearGradient(
                        Gradient(colors: [CafadePalette.saffron, CafadePalette.coral]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width, y: 0)
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
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
                    with: .color(CafadePalette.paper.opacity(0.24)),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 5])
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: nowPoint.x - 5, y: nowPoint.y - 5, width: 10, height: 10)),
                    with: .color(CafadePalette.paper)
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: nowPoint.x - 3, y: nowPoint.y - 3, width: 6, height: 6)),
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
            with: .color(CafadePalette.paper.opacity(0.12)),
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
                .foregroundStyle(CafadePalette.paper)
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
