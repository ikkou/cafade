import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var entitlements: EntitlementService
    @State private var selectedOptionID = EntitlementService.SubscriptionOption.previewYearly.id
    @State private var showingMessage = false

    private var selectedOption: EntitlementService.SubscriptionOption? {
        entitlements.displayOptions.first { $0.id == selectedOptionID }
            ?? entitlements.displayOptions.first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CafadeBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        benefits
                        plans
                        actionButtons
                        legal
                    }
                    .padding(22)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Not now") { dismiss() }
                        .foregroundStyle(CafadePalette.mist)
                }
            }
        }
        .task {
            await entitlements.loadOfferings()
        }
        .onChange(of: entitlements.lastMessage) { _, newValue in
            showingMessage = newValue != nil
        }
        .alert("Cafade Pro", isPresented: $showingMessage) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(entitlements.lastMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SEE YOUR PATTERNS")
                .font(.caption.weight(.semibold))
                .tracking(1.9)
                .foregroundStyle(CafadePalette.saffron)
            Text("Let your pattern grow.")
                .font(.system(size: 38, weight: .medium, design: .serif))
                .foregroundStyle(CafadePalette.paper)
            Text("Cafade Pro gives your quiet daily log a longer memory.")
                .font(.body)
                .foregroundStyle(CafadePalette.mist)
        }
    }

    private var benefits: some View {
        CafadeGlassCard(tint: CafadePalette.lavender.opacity(0.08)) {
            VStack(alignment: .leading, spacing: 15) {
                benefitRow("30-day and longer history", symbol: "calendar")
                benefitRow("Weekly caffeine patterns", symbol: "waveform.path.ecg")
                benefitRow("Sleep comparison", symbol: "moon.stars")
                benefitRow("What-if previews for your last drink", symbol: "arrow.trianglehead.2.clockwise.rotate.90")
            }
        }
    }

    private func benefitRow(_ text: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(CafadePalette.mint)
                .frame(width: 24)
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(CafadePalette.paper)
            Spacer()
            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(CafadePalette.saffron)
        }
    }

    private var plans: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CHOOSE YOUR RHYTHM")
                .font(.caption.weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(CafadePalette.saffron)
            ForEach(entitlements.displayOptions) { option in
                Button {
                    selectedOptionID = option.id
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: selectedOptionID == option.id ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(selectedOptionID == option.id ? CafadePalette.saffron : CafadePalette.mist)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.title)
                                .font(.caption.weight(.semibold))
                                .tracking(1.1)
                                .foregroundStyle(CafadePalette.saffron)
                            Text(option.price)
                                .font(.title3.monospacedDigit().weight(.semibold))
                                .foregroundStyle(CafadePalette.paper)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(option.periodLabel)
                                .font(.caption)
                                .foregroundStyle(CafadePalette.mist)
                            if option.hasIntroductoryOffer {
                                Text("7-day trial*")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(CafadePalette.mint)
                            }
                        }
                    }
                    .padding(16)
                    .background(selectedOptionID == option.id ? CafadePalette.saffron.opacity(0.12) : CafadePalette.paper.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(selectedOptionID == option.id ? CafadePalette.saffron.opacity(0.8) : CafadePalette.line, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                guard let selectedOption else { return }
                Task {
                    await entitlements.purchase(option: selectedOption)
                    if entitlements.isPro { dismiss() }
                }
            } label: {
                Text(entitlements.state.isBusy ? "Connecting…" : "Start Pro")
            }
            .buttonStyle(CafadePrimaryButtonStyle())
            .disabled(entitlements.state.isBusy || !entitlements.isConfigured)
            .opacity(entitlements.isConfigured ? 1 : 0.55)

            Button {
                Task { await entitlements.restorePurchases() }
            } label: {
                Text(entitlements.state == .restoring ? "Restoring…" : "Restore purchases")
            }
            .buttonStyle(CafadeSecondaryButtonStyle())
            .disabled(entitlements.state.isBusy)

            if !entitlements.isConfigured {
                Text("Subscription products will appear here after the RevenueCat public SDK key and App Store products are connected.")
                    .font(.caption)
                    .foregroundStyle(CafadePalette.mist)
                    .multilineTextAlignment(.center)
            }

            if entitlements.isConfigured && entitlements.displayOptions.contains(where: \.hasIntroductoryOffer) {
                Text("* Free trials are for eligible new subscribers. Apple shows the final terms before purchase.")
                    .font(.caption2)
                    .foregroundStyle(CafadePalette.mist)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var legal: some View {
        HStack(spacing: 14) {
            Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            Text("•")
            Link("Privacy", destination: URL(string: "https://cafade.oneshotstar.com/privacy/")!)
        }
        .font(.caption)
        .foregroundStyle(CafadePalette.mist)
        .frame(maxWidth: .infinity)
    }
}
