import SwiftUI
import UIKit

struct CafadeShareDrink: Identifiable, Equatable {
    let id: String
    let name: String
    let value: String
    let time: String
}

struct CafadeShareSnapshot: Equatable {
    let date: Date
    let estimate: CaffeineEstimate
    let drinks: [CafadeShareDrink]
    let halfLifeHours: Int

    init(date: Date, estimate: CaffeineEstimate, events: [IntakeEvent], halfLifeHours: Int) {
        self.date = date
        self.estimate = estimate
        self.drinks = events
            .sorted(by: { $0.consumedAt > $1.consumedAt })
            .prefix(4)
            .map {
                CafadeShareDrink(
                    id: $0.id.uuidString,
                    name: CaffeineCatalog.displayName(for: $0),
                    value: CaffeineCatalog.value(for: $0).displayText,
                    time: CaffeineFormatter.time($0.consumedAt)
                )
            }
        self.halfLifeHours = halfLifeHours
    }
}

struct ShareCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    let snapshot: CafadeShareSnapshot

    @State private var renderedImage: UIImage?
    @State private var showingShareSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                CafadeBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("A SMALL MOMENT TO SHARE")
                                .font(.caption.weight(.semibold))
                                .tracking(1.7)
                                .foregroundStyle(CafadePalette.saffron)
                            Text("Your day, in one card.")
                                .font(.system(size: 31, weight: .regular, design: .serif))
                                .foregroundStyle(CafadePalette.ink)
                            Text("Export the shape of your caffeine day as an image.")
                                .font(.subheadline)
                                .foregroundStyle(CafadePalette.mist)
                        }

                        CafadeShareCardPreview(snapshot: snapshot)
                            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                            .shadow(color: CafadePalette.ink.opacity(0.14), radius: 20, y: 12)

                        Button {
                            renderAndShare()
                        } label: {
                            Label("SHARE THIS CARD", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(CafadePrimaryButtonStyle())

                        Text("Cafade shares only the card image you choose. Your log stays on this device unless you share it.")
                            .font(.caption)
                            .foregroundStyle(CafadePalette.mist)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(20)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Share your day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingShareSheet, onDismiss: { renderedImage = nil }) {
            if let renderedImage {
                CafadeActivityView(activityItems: [renderedImage])
            }
        }
    }

    private func renderAndShare() {
        let renderer = ImageRenderer(
            content: CafadeShareCard(snapshot: snapshot)
                .frame(width: 1080, height: 1350)
        )
        renderedImage = renderer.uiImage
        showingShareSheet = renderedImage != nil
    }
}

private struct CafadeShareCardPreview: View {
    let snapshot: CafadeShareSnapshot

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            CafadeShareCard(snapshot: snapshot)
                .frame(width: 1080, height: 1350)
                .scaleEffect(width / 1080)
                .frame(width: width, height: width * 1.25)
        }
        .aspectRatio(0.8, contentMode: .fit)
    }
}

struct CafadeShareCard: View {
    let snapshot: CafadeShareSnapshot

    var body: some View {
        ZStack {
            CafadePalette.background

            LinearGradient(
                colors: [CafadePalette.surface.opacity(0.8), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(CafadePalette.saffron.opacity(0.12))
                .frame(width: 420)
                .blur(radius: 65)
                .offset(x: 260, y: -510)

            Circle()
                .fill(CafadePalette.lavender.opacity(0.12))
                .frame(width: 440)
                .blur(radius: 72)
                .offset(x: -260, y: 490)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CAFADE")
                            .font(.system(size: 25, weight: .semibold, design: .serif))
                            .tracking(4.2)
                            .foregroundStyle(CafadePalette.ink)
                        Text(snapshot.date.formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased())
                            .font(.system(size: 17, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(CafadePalette.saffron)
                    }
                    Spacer()
                    Text("YOUR DAY")
                        .font(.system(size: 15, weight: .semibold))
                        .tracking(2.3)
                        .foregroundStyle(CafadePalette.mist)
                }

                Text("YOUR CAFFEINE,\nIN MOTION")
                    .font(.system(size: 54, weight: .regular, design: .serif))
                    .foregroundStyle(CafadePalette.ink)
                    .lineSpacing(-2)
                    .padding(.top, 88)

                ZStack {
                    CafadeCaffeineOrb(estimate: snapshot.estimate)
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)
                        .padding(.horizontal, 46)
                    VStack(spacing: 7) {
                        HStack(alignment: .lastTextBaseline, spacing: 9) {
                            Text(snapshot.estimate.shortDisplayText)
                                .font(.system(size: 78, weight: .regular, design: .serif))
                                .monospacedDigit()
                                .foregroundStyle(Color.white)
                            Text("mg")
                                .font(.system(size: 30, weight: .medium, design: .serif))
                                .foregroundStyle(Color.white.opacity(0.9))
                        }
                        Text(snapshot.estimate.maxMg < 1 ? "waiting for your first log" : "remaining now · fading slowly")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.9))
                    }
                }
                .padding(.top, 42)

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("TODAY'S CURVE")
                            .font(.system(size: 16, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(CafadePalette.saffron)
                        Spacer()
                        Text("HALF-LIFE \(snapshot.halfLifeHours)H")
                            .font(.system(size: 15, weight: .semibold))
                            .tracking(1.1)
                            .foregroundStyle(CafadePalette.mist)
                    }

                    CafadeShareSparkline(estimate: snapshot.estimate)
                        .frame(height: 112)

                    HStack(spacing: 12) {
                        shareStat(label: "LOGGED", value: "\(snapshot.drinks.count) drinks", tint: CafadePalette.mint)
                        shareStat(label: "NOW", value: "\(snapshot.estimate.shortDisplayText) mg", tint: CafadePalette.sky)
                    }
                }
                .padding(.top, 54)

                if !snapshot.drinks.isEmpty {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("IN THE LOG")
                            .font(.system(size: 15, weight: .semibold))
                            .tracking(1.9)
                            .foregroundStyle(CafadePalette.mist)
                        ForEach(snapshot.drinks) { drink in
                            HStack {
                                Text(drink.name)
                                    .lineLimit(1)
                                Spacer()
                                Text(drink.value)
                                Text(drink.time)
                                    .foregroundStyle(CafadePalette.mist)
                            }
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(CafadePalette.ink)
                        }
                    }
                    .padding(.top, 46)
                }

                Spacer(minLength: 20)

                HStack {
                    Text("KNOW WHAT YOU DRANK. SEE WHAT REMAINS.")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(1.3)
                        .foregroundStyle(CafadePalette.mist)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(CafadePalette.saffron)
                }
            }
            .padding(64)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cafade share card for \(snapshot.date.formatted(date: .long, time: .omitted))")
    }

    private func shareStat(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 20, weight: .medium, design: .serif))
                .foregroundStyle(CafadePalette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(CafadePalette.surface.opacity(0.66), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(CafadePalette.line, lineWidth: 1)
        }
    }
}

private struct CafadeShareSparkline: View {
    let estimate: CaffeineEstimate

    var body: some View {
        Canvas { context, size in
            let intensity = min(max(estimate.typicalMg / 180, 0.22), 1)
            let values: [CGFloat] = [0.18, 0.43, 0.82, 0.66, 0.53, 0.43, CGFloat(0.18 + intensity * 0.42)]
            let points = values.enumerated().map { index, value in
                CGPoint(
                    x: size.width * CGFloat(index) / CGFloat(values.count - 1),
                    y: size.height * (1 - value)
                )
            }
            var line = Path()
            var area = Path()
            for (index, point) in points.enumerated() {
                if index == 0 {
                    line.move(to: point)
                    area.move(to: CGPoint(x: point.x, y: size.height))
                    area.addLine(to: point)
                } else {
                    line.addLine(to: point)
                    area.addLine(to: point)
                }
            }
            if let last = points.last {
                area.addLine(to: CGPoint(x: last.x, y: size.height))
                area.closeSubpath()
            }
            context.fill(
                area,
                with: .linearGradient(
                    Gradient(colors: [CafadePalette.saffron.opacity(0.34), CafadePalette.lavender.opacity(0.12), .clear]),
                    startPoint: .zero,
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
                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
            )
            if let last = points.last {
                context.fill(
                    Path(ellipseIn: CGRect(x: last.x - 7, y: last.y - 7, width: 14, height: 14)),
                    with: .color(CafadePalette.surface)
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: last.x - 4, y: last.y - 4, width: 8, height: 8)),
                    with: .color(CafadePalette.saffron)
                )
            }
        }
    }
}

private struct CafadeActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
