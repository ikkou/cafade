import AppIntents
import SwiftUI
import WidgetKit

struct CafadeWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: CafadeWidgetSnapshot
}

struct CafadeWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CafadeWidgetEntry {
        let now = Date()
        var snapshot = CafadeWidgetSnapshot.empty
        snapshot.record(
            CafadeWidgetEvent(
                id: UUID(),
                name: "Cold brew",
                catalogItemID: nil,
                caffeineMg: 120,
                minMg: nil,
                maxMg: nil,
                valueKindRaw: "approximate",
                sourceKindRaw: "custom",
                consumedAt: now.addingTimeInterval(-2.5 * 3_600)
            ),
            now: now
        )
        return CafadeWidgetEntry(date: now, snapshot: snapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (CafadeWidgetEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            completion(CafadeWidgetEntry(date: .now, snapshot: CafadeWidgetStore.loadSnapshot()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CafadeWidgetEntry>) -> Void) {
        let now = Date()
        let snapshot = CafadeWidgetStore.loadSnapshot()
        let entries = (0...12).map { step in
            CafadeWidgetEntry(
                date: now.addingTimeInterval(Double(step) * 15 * 60),
                snapshot: snapshot
            )
        }
        let nextRefresh = now.addingTimeInterval(13 * 15 * 60)
        completion(Timeline(entries: entries, policy: .after(nextRefresh)))
    }
}

@main
struct CafadeWidgetBundle: WidgetBundle {
    var body: some Widget {
        CafadeCurrentEstimateWidget()
    }
}

struct CafadeCurrentEstimateWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: CafadeWidgetConstants.kind, provider: CafadeWidgetProvider()) { entry in
            CafadeWidgetView(entry: entry)
        }
        .configurationDisplayName("Current Estimate")
        .description("See your caffeine fade and log a recent drink without opening Cafade.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

private struct CafadeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CafadeWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumLayout
            default:
                smallLayout
            }
        }
        .padding(16)
        .containerBackground(for: .widget) {
            CafadeWidgetBackground()
        }
        .accessibilityElement(children: .contain)
    }

    private var estimate: CafadeWidgetEstimate {
        entry.snapshot.estimate(at: entry.date)
    }

    private var quickDrinks: [CafadeWidgetQuickDrink] {
        Array(entry.snapshot.quickDrinks.prefix(3))
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            widgetLabel
            Spacer(minLength: 6)
            estimateLabel
            Spacer(minLength: 10)
            if let drink = quickDrinks.first {
                quickLogButton(drink, compact: true)
            }
        }
    }

    private var mediumLayout: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                widgetLabel
                Spacer(minLength: 8)
                estimateLabel
                Spacer(minLength: 4)
                Text("As of \(entry.date, style: .time)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(CafadeWidgetPalette.secondaryInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(CafadeWidgetPalette.ink.opacity(0.10))
                .frame(width: 1)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 7) {
                Text("LOG AGAIN")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(CafadeWidgetPalette.secondaryInk)

                ForEach(quickDrinks) { drink in
                    quickLogButton(drink, compact: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var widgetLabel: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(CafadeWidgetPalette.amber)
                Circle()
                    .stroke(.white.opacity(0.72), lineWidth: 1)
                    .padding(2)
            }
            .frame(width: 17, height: 17)

            Text("CURRENT ESTIMATE")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.05)
                .lineLimit(1)
        }
        .foregroundStyle(CafadeWidgetPalette.ink)
        .accessibilityHidden(true)
    }

    private var estimateLabel: some View {
        VStack(alignment: .leading, spacing: -2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(estimate.amountText)
                    .font(.system(size: 38, weight: .regular, design: .serif))
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                Text("mg")
                    .font(.system(size: 14, weight: .medium, design: .serif))
            }
            Text(estimateStatusText)
                .font(.system(size: 11, weight: .medium, design: .serif))
                .foregroundStyle(CafadeWidgetPalette.secondaryInk)
        }
        .foregroundStyle(CafadeWidgetPalette.ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current estimate, \(estimate.accessibilityText), \(estimateAccessibilityStatus)")
    }

    private var estimateStatusText: String {
        estimate.maxMg < 0.5 ? "clear for now" : "now · fading slowly"
    }

    private var estimateAccessibilityStatus: String {
        estimate.maxMg < 0.5 ? "clear for now" : "fading slowly"
    }

    private func quickLogButton(_ drink: CafadeWidgetQuickDrink, compact: Bool) -> some View {
        Button(intent: LogCaffeineFromWidgetIntent(drinkID: drink.id)) {
            HStack(spacing: compact ? 7 : 8) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: compact ? 22 : 24, height: compact ? 22 : 24)
                    .background(CafadeWidgetPalette.ink, in: Circle())
                    .foregroundStyle(CafadeWidgetPalette.paper)

                Text(drink.name)
                    .font(.system(size: compact ? 11 : 10, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 2)

                Text("\(drink.caffeineMg) mg")
                    .font(.system(size: compact ? 10 : 9, weight: .bold, design: .rounded))
                    .foregroundStyle(CafadeWidgetPalette.secondaryInk)
            }
            .foregroundStyle(CafadeWidgetPalette.ink)
            .padding(.horizontal, compact ? 8 : 7)
            .frame(maxWidth: .infinity, minHeight: compact ? 40 : 34)
            .background(.white.opacity(0.58), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(CafadeWidgetPalette.ink.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log \(drink.name), \(drink.caffeineMg) milligrams, now")
    }
}

private struct CafadeWidgetBackground: View {
    var body: some View {
        ZStack {
            CafadeWidgetPalette.paper

            RadialGradient(
                colors: [CafadeWidgetPalette.amber.opacity(0.42), .clear],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 150
            )

            RadialGradient(
                colors: [CafadeWidgetPalette.lavender.opacity(0.34), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 170
            )

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [CafadeWidgetPalette.amber.opacity(0.32), .white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 145, height: 76)
                .blur(radius: 9)
                .rotationEffect(.degrees(-18))
                .offset(x: -72, y: 80)
        }
    }
}

private enum CafadeWidgetPalette {
    static let paper = Color(red: 0.976, green: 0.957, blue: 0.928)
    static let ink = Color(red: 0.105, green: 0.094, blue: 0.085)
    static let secondaryInk = Color(red: 0.31, green: 0.28, blue: 0.25)
    static let amber = Color(red: 0.93, green: 0.43, blue: 0.07)
    static let lavender = Color(red: 0.40, green: 0.42, blue: 0.68)
}
