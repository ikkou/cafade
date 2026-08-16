import SwiftUI
import UIKit
import Photos

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
    let totalDrinkCount: Int
    let totalLoggedMg: Int
    let curveValues: [Double]
    let hasCarryover: Bool
    let halfLifeHours: Int

    init(date: Date, estimate: CaffeineEstimate, events: [IntakeEvent], halfLifeHours: Int) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
        let dayEvents = events.filter { $0.consumedAt >= dayStart && $0.consumedAt < dayEnd }
        let dayMidpoint = dayStart.addingTimeInterval(dayEnd.timeIntervalSince(dayStart) / 2)
        let curve = CaffeineCalculator.timeline(
            events: events,
            centeredAt: dayMidpoint,
            halfLifeHours: halfLifeHours,
            points: 49,
            spanHours: dayEnd.timeIntervalSince(dayStart) / 3600
        )
        self.date = date
        self.estimate = estimate
        self.drinks = dayEvents
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
        self.totalDrinkCount = dayEvents.count
        self.totalLoggedMg = dayEvents.reduce(0) { $0 + $1.caffeineMg }
        self.curveValues = curve.map(\.estimate.typicalMg)
        self.hasCarryover = CaffeineCalculator
            .estimate(events: events, at: dayStart, halfLifeHours: halfLifeHours)
            .typicalMg >= 0.5
        self.halfLifeHours = halfLifeHours
    }
}

private struct ShareImagePayload: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ShareCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let snapshot: CafadeShareSnapshot

    @State private var sharePayload: ShareImagePayload?
    @State private var cardImage: UIImage?
    @State private var isRendering = true
    @State private var showingSavedAlert = false
    @State private var showingPhotoPermissionAlert = false
    @State private var saveErrorMessage: String?

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
                                .foregroundStyle(CafadePalette.accentText)
                            Text("Your day, in one card.")
                                .font(.system(.title, design: .serif).weight(.regular))
                                .foregroundStyle(CafadePalette.ink)
                            Text("Export the shape of your caffeine day as an image.")
                                .font(.subheadline)
                                .foregroundStyle(CafadePalette.mist)
                        }

                        CafadeShareCardPreview(snapshot: snapshot)
                            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                            .shadow(color: CafadePalette.ink.opacity(0.14), radius: 20, y: 12)

                        Button {
                            prepareShare()
                        } label: {
                            Label("SHARE THIS CARD", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(CafadePrimaryButtonStyle())
                        .disabled(cardImage == nil)
                        .opacity(cardImage == nil ? 0.55 : 1)

                        Button {
                            saveCardImage()
                        } label: {
                            Label("SAVE IMAGE", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(CafadeSecondaryButtonStyle())
                        .disabled(cardImage == nil)
                        .opacity(cardImage == nil ? 0.55 : 1)

                        if isRendering {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Preparing your card…")
                            }
                            .font(.caption)
                            .foregroundStyle(CafadePalette.mist)
                            .frame(maxWidth: .infinity, alignment: .center)
                        }

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
        .sheet(item: $sharePayload) { payload in
            CafadeActivityView(activityItems: [payload.image])
        }
        .alert("Saved to Photos", isPresented: $showingSavedAlert) {
            Button("Done", role: .cancel) { }
        } message: {
            Text("Your Cafade card is ready in Photos.")
        }
        .alert("Photos access is off", isPresented: $showingPhotoPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("Not now", role: .cancel) { }
        } message: {
            Text("Allow Cafade to add images in iPhone Settings before saving a card.")
        }
        .alert(
            "Could not save card",
            isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { saveErrorMessage = nil }
        } message: {
            Text(saveErrorMessage ?? "Please try again.")
        }
        .task(id: snapshot) {
            renderCardIfNeeded()
        }
    }

    @MainActor
    private func makeCardImage() -> UIImage? {
        let renderer = ImageRenderer(
            content: CafadeShareCard(snapshot: snapshot)
                .frame(width: 1080, height: CafadeShareCard.canvasHeight(for: snapshot))
        )
        return renderer.uiImage
    }

    private func prepareShare() {
        guard let image = cardImage else {
            saveErrorMessage = "The card is still being prepared. Please try again in a moment."
            return
        }
        sharePayload = ShareImagePayload(image: image)
    }

    private func saveCardImage() {
        guard let image = cardImage else {
            saveErrorMessage = "The card is still being prepared. Please try again in a moment."
            return
        }

        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .authorized, .limited:
            saveImageToPhotos(image)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                guard status == .authorized || status == .limited else {
                    Task { @MainActor in
                        showingPhotoPermissionAlert = true
                    }
                    return
                }
                saveImageToPhotos(image)
            }
        case .denied, .restricted:
            showingPhotoPermissionAlert = true
        @unknown default:
            showingPhotoPermissionAlert = true
        }
    }

    private func saveImageToPhotos(_ image: UIImage) {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        } completionHandler: { success, error in
            Task { @MainActor in
                if success {
                    showingSavedAlert = true
                } else {
                    saveErrorMessage = error?.localizedDescription
                        ?? "Cafade could not add the image to Photos."
                }
            }
        }
    }

    @MainActor
    private func renderCardIfNeeded() {
        guard cardImage == nil else {
            isRendering = false
            return
        }
        isRendering = true
        cardImage = makeCardImage()
        isRendering = false
        if cardImage == nil {
            saveErrorMessage = "Cafade could not render this card. Please close it and try again."
        }
    }
}

private struct CafadeShareCardPreview: View {
    let snapshot: CafadeShareSnapshot

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = CafadeShareCard.canvasHeight(for: snapshot)
            CafadeShareCard(snapshot: snapshot)
                .frame(width: 1080, height: height)
                .scaleEffect(width / 1080, anchor: .topLeading)
                .frame(width: width, height: width * height / 1080, alignment: .topLeading)
                .clipped()
        }
        .aspectRatio(1080 / CafadeShareCard.canvasHeight(for: snapshot), contentMode: .fit)
    }
}

struct CafadeShareCard: View {
    let snapshot: CafadeShareSnapshot

    static func canvasHeight(for snapshot: CafadeShareSnapshot) -> CGFloat {
        guard !snapshot.drinks.isEmpty else { return 1_080 }

        var height = 1_050 + CGFloat(snapshot.drinks.count) * 42
        if snapshot.totalDrinkCount > snapshot.drinks.count {
            height += 30
        }
        if snapshot.hasCarryover {
            height += 30
        }
        return min(max(height, 1_120), 1_280)
    }

    private var orbTextColor: Color {
        snapshot.estimate.typicalMg > 0 ? .white : CafadePalette.ink
    }

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
                        Text(CaffeineFormatter.fullDay(snapshot.date).uppercased())
                            .font(.system(size: 17, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(CafadePalette.accentText)
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
                    .padding(.top, 50)

                ZStack {
                    CafadeCaffeineOrb(
                        estimate: snapshot.estimate,
                        isActive: false,
                        maxOrbWidth: 760,
                        maxOrbHeight: 250
                    )
                        .frame(maxWidth: .infinity)
                    .frame(height: 260)
                        .padding(.horizontal, 40)
                    VStack(spacing: 7) {
                        let estimateFontSize: CGFloat = snapshot.estimate.shortDisplayText.count > 8 ? 58 : 72
                        HStack(alignment: .lastTextBaseline, spacing: 9) {
                            Text(snapshot.estimate.shortDisplayText)
                                .font(.system(size: estimateFontSize, weight: .regular, design: .serif))
                                .monospacedDigit()
                                .foregroundStyle(orbTextColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                            Text("mg")
                                .font(.system(size: 28, weight: .medium, design: .serif))
                                .foregroundStyle(orbTextColor.opacity(0.9))
                        }
                        .frame(maxWidth: .infinity)
                        Text(snapshot.estimate.maxMg < 1 ? "waiting for your first log" : "remaining now · fading slowly")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(orbTextColor.opacity(0.9))
                    }
                }
                .padding(.top, 24)

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("TODAY'S CURVE")
                            .font(.system(size: 16, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(CafadePalette.accentText)
                        Spacer()
                        Text("HALF-LIFE \(snapshot.halfLifeHours)H")
                            .font(.system(size: 15, weight: .semibold))
                            .tracking(1.1)
                            .foregroundStyle(CafadePalette.mist)
                    }

                    CafadeShareSparkline(values: snapshot.curveValues)
                        .frame(height: 100)

                    HStack(spacing: 12) {
                        shareStat(
                            label: "LOGGED",
                            value: "\(snapshot.totalDrinkCount) drink\(snapshot.totalDrinkCount == 1 ? "" : "s") · \(snapshot.totalLoggedMg) mg",
                            tint: CafadePalette.mint
                        )
                        shareStat(label: "NOW", value: "\(snapshot.estimate.shortDisplayText) mg", tint: CafadePalette.sky)
                    }
                }
                .padding(.top, 32)

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
                        if snapshot.totalDrinkCount > snapshot.drinks.count {
                            Text("+ \(snapshot.totalDrinkCount - snapshot.drinks.count) more in the log")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(CafadePalette.mist)
                        }
                        if snapshot.hasCarryover {
                            Label("Curve includes caffeine carried over from earlier logs", systemImage: "arrow.turn.down.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(CafadePalette.mist)
                        }
                    }
                    .padding(.top, 32)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("READY FOR YOUR FIRST LOG")
                            .font(.system(size: 15, weight: .semibold))
                            .tracking(1.9)
                            .foregroundStyle(CafadePalette.mist)
                        Text("Your first drink will draw the shape of this day.")
                            .font(.system(size: 17, weight: .medium, design: .serif))
                            .foregroundStyle(CafadePalette.ink)
                    }
                    .padding(.top, 32)
                }

                Spacer(minLength: 12)

                HStack {
                    Text("KNOW WHAT YOU DRANK. SEE WHAT REMAINS.")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1.3)
                        .foregroundStyle(CafadePalette.mist)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(CafadePalette.accentText)
                }
            }
            .padding(60)
        }
        .frame(width: 1080, height: Self.canvasHeight(for: snapshot), alignment: .topLeading)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Cafade share card for \(CaffeineFormatter.longDate(snapshot.date)). "
                + "\(snapshot.totalDrinkCount) drinks, \(snapshot.totalLoggedMg) milligrams logged, "
                + "\(snapshot.estimate.displayText) estimated remaining now"
                + (snapshot.hasCarryover ? ", including carryover from earlier logs" : "")
        )
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
    let values: [Double]

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }
            let maximum = max(values.max() ?? 0, 1)
            let points = values.enumerated().map { index, value in
                CGPoint(
                    x: size.width * CGFloat(index) / CGFloat(values.count - 1),
                    y: size.height - size.height * CGFloat(value / maximum) * 0.88
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
