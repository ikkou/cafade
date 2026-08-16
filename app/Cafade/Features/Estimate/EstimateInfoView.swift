import SwiftData
import SwiftUI

struct EstimateInfoView: View {
    @Query private var settings: [UserSettings]

    private var halfLife: Int { settings.first?.halfLifeHours ?? 4 }

    var body: some View {
        ZStack {
            CafadeBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    halfLifeCard
                    explanation
                    sourceSection
                    disclaimer
                }
                .padding(20)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("How the estimate works")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THE MODEL")
                .font(.caption.weight(.semibold))
                .tracking(1.8)
                .foregroundStyle(CafadePalette.accentText)
            Text("Caffeine leaves the body gradually.")
                .font(.system(.title, design: .serif).weight(.medium))
                .foregroundStyle(CafadePalette.paper)
            Text("Cafade keeps the math simple enough to understand and useful enough to guide a decision.")
                .font(.subheadline)
                .foregroundStyle(CafadePalette.mist)
        }
    }

    private var halfLifeCard: some View {
        CafadeGlassCard(tint: CafadePalette.saffron.opacity(0.08)) {
            VStack(alignment: .leading, spacing: 16) {
                ViewThatFits(in: .horizontal) {
                    HStack {
                        halfLifeLabel
                        Spacer()
                        halfLifeValue
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        halfLifeLabel
                        halfLifeValue
                    }
                }
                HalfLifeStepsView(halfLifeHours: halfLife)
                Text("After each half-life, the estimated amount is reduced by half.")
                    .font(.caption)
                    .foregroundStyle(CafadePalette.mist)
            }
        }
    }

    private var halfLifeLabel: some View {
        Text("YOUR SELECTED HALF-LIFE")
            .font(.caption.weight(.semibold))
            .tracking(1.3)
            .foregroundStyle(CafadePalette.accentText)
    }

    private var halfLifeValue: some View {
        Text("\(halfLife) hours")
            .font(.headline.monospacedDigit())
            .foregroundStyle(CafadePalette.paper)
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 15) {
            ExplanationRow(number: "01", title: "Each drink starts its own curve", detail: "Cafade keeps every logged drink and its consumed time separate.")
            ExplanationRow(number: "02", title: "The curves are added together", detail: "The current estimate is the sum of all caffeine still remaining from your entries.")
            ExplanationRow(number: "03", title: "Your model is a setting, not a diagnosis", detail: "Choose 2, 4, 6, or 8 hours to see how the estimate changes. It does not measure your personal metabolism.")
            ExplanationRow(number: "04", title: "Absorption is not modeled", detail: "The curve starts at the time you log a drink. It estimates caffeine amount, not blood concentration or alertness.")
        }
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("READ THE SOURCES")
                .font(.caption.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(CafadePalette.accentText)

            Text("A typical adult caffeine half-life is often reported around 3–7 hours, but it can vary with the person and context. These references explain the range and the factors behind it.")
                .font(.caption)
                .foregroundStyle(CafadePalette.mist)

            VStack(spacing: 0) {
                sourceLink(
                    title: "Daily caffeine consumption for most adults",
                    detail: "U.S. FDA · context for the general 400 mg/day reference",
                    url: CaffeineCalculator.dailyReferenceURL
                )
                Divider().overlay(CafadePalette.line)
                sourceLink(
                    title: "Caffeine & cardiovascular disease",
                    detail: "American Heart Association · scientific statement summary",
                    url: CaffeineCalculator.cardiovascularStatementURL
                )
                Divider().overlay(CafadePalette.line)
                sourceLink(
                    title: "The Safety of Ingested Caffeine",
                    detail: "NCBI / peer-reviewed review",
                    url: URL(string: "https://pmc.ncbi.nlm.nih.gov/articles/PMC5445139/")!
                )
                Divider().overlay(CafadePalette.line)
                sourceLink(
                    title: "Caffeine: compound overview",
                    detail: "NIH PubChem reference",
                    url: URL(string: "https://pubchem.ncbi.nlm.nih.gov/compound/caffeine")!
                )
            }
            .padding(.horizontal, 16)
            .background(CafadePalette.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(CafadePalette.line, lineWidth: 1)
            }
        }
    }

    private func sourceLink(title: String, detail: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.up.right.square")
                    .font(.title3)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .foregroundStyle(CafadePalette.sky)
                    .frame(width: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(CafadePalette.ink)
                        .multilineTextAlignment(.leading)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(CafadePalette.mist)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .foregroundStyle(CafadePalette.mist)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var disclaimer: some View {
        Text("This is an estimate, not a measurement or medical advice. Caffeine values can vary by product, size, recipe, preparation, and person.")
            .font(.caption)
            .foregroundStyle(CafadePalette.mist)
            .padding(16)
            .background(CafadePalette.coral.opacity(0.10), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(CafadePalette.coral.opacity(0.25), lineWidth: 1))
    }
}

private struct HalfLifeStepsView: View {
    let halfLifeHours: Int
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 9) {
                    ForEach(Array([100, 50, 25, 13].enumerated()), id: \.offset) { index, value in
                        HStack {
                            Text(index == 0 ? "Now" : "After \(index) half-life\(index == 1 ? "" : "s")")
                            Spacer()
                            Text("\(value)%")
                                .monospacedDigit()
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(CafadePalette.paper)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ForEach(Array([100, 50, 25, 13].enumerated()), id: \.offset) { index, value in
                        VStack(spacing: 7) {
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(CafadePalette.paper.opacity(0.08))
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(index == 0 ? CafadePalette.saffron : CafadePalette.saffron.opacity(0.72))
                                    .frame(height: max(12, CGFloat(value) / 100 * 66))
                            }
                            .frame(height: 70)
                            Text(index == 0 ? "Now" : "\(index)×")
                                .font(.caption2)
                                .foregroundStyle(CafadePalette.mist)
                            Text("\(value)%")
                                .font(.caption2.monospacedDigit().weight(.semibold))
                                .foregroundStyle(CafadePalette.paper)
                        }
                        if index < 3 { Spacer(minLength: 0) }
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("After one half-life, 50 percent remains. After two, 25 percent remains.")
    }
}

private struct ExplanationRow: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Text(number)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(CafadePalette.accentText)
                .frame(minWidth: 28, alignment: .leading)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CafadePalette.paper)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(CafadePalette.mist)
            }
        }
    }
}
