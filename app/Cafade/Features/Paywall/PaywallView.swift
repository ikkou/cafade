import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var entitlements: EntitlementService
    @State private var selectedOptionID: String?
    @State private var showingMessage = false

    private var selectedOption: EntitlementService.SubscriptionOption? {
        guard let selectedOptionID else { return nil }
        return entitlements.options.first { $0.id == selectedOptionID }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CafadeBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        benefits
                        planContent
                        restoreButton
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
            if entitlements.options.isEmpty {
                await entitlements.refresh()
            }
            selectDefaultOption()
        }
        .onChange(of: entitlements.options.map(\.id)) { _, _ in
            selectDefaultOption()
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
                .foregroundStyle(CafadePalette.accentText)
            Text("Let your pattern grow.")
                .font(.system(.largeTitle, design: .serif).weight(.medium))
                .foregroundStyle(CafadePalette.paper)
            Text("Cafade Pro gives your daily log a longer memory as your history grows.")
                .font(.body)
                .foregroundStyle(CafadePalette.mist)
        }
    }

    private var benefits: some View {
        CafadeGlassCard(tint: CafadePalette.lavender.opacity(0.08)) {
            VStack(alignment: .leading, spacing: 15) {
                benefitRow("30- and 90-day history", symbol: "calendar")
                benefitRow("Rolling caffeine patterns", symbol: "waveform.path.ecg")
                benefitRow("Sleep comparison", symbol: "moon.stars")
                benefitRow("What-if previews for your last drink", symbol: "arrow.trianglehead.2.clockwise.rotate.90")
            }
        }
    }

    private func benefitRow(_ text: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .foregroundStyle(CafadePalette.mint)
                .frame(width: 32)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(CafadePalette.paper)
            Spacer(minLength: 8)
            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .foregroundStyle(CafadePalette.accentText)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var planContent: some View {
        if !entitlements.isConfigured {
            unavailableCard(
                title: "Subscriptions unavailable",
                detail: "This build is missing its RevenueCat public SDK key."
            )
        } else if entitlements.state == .loading || entitlements.state == .idle {
            CafadeGlassCard {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Loading subscription plans…")
                        .font(.subheadline)
                        .foregroundStyle(CafadePalette.mist)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else if let message = entitlements.state.failureMessage {
            unavailableCard(title: "Plans could not load", detail: message, showsRetry: true)
        } else if entitlements.options.isEmpty {
            unavailableCard(
                title: "No plans available",
                detail: "Check your connection and try again.",
                showsRetry: true
            )
        } else {
            plans
            purchaseButton
        }
    }

    private var plans: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CHOOSE YOUR PLAN")
                .font(.caption.weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(CafadePalette.accentText)
            ForEach(entitlements.options) { option in
                Button {
                    selectedOptionID = option.id
                } label: {
                    planRow(option)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedOptionID == option.id ? .isSelected : [])
                .accessibilityValue(selectedOptionID == option.id ? "Selected" : "Not selected")
            }
        }
    }

    private func planRow(_ option: EntitlementService.SubscriptionOption) -> some View {
        let isSelected = selectedOptionID == option.id
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                selectionIcon(isSelected)
                planName(option)
                Spacer(minLength: 10)
                planTerms(option)
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    selectionIcon(isSelected)
                    planName(option)
                }
                planTerms(option)
            }
        }
        .padding(16)
        .background(
            isSelected ? CafadePalette.saffron.opacity(0.12) : CafadePalette.surface.opacity(0.82),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? CafadePalette.accentText.opacity(0.8) : CafadePalette.line, lineWidth: 1)
        }
    }

    private func selectionIcon(_ isSelected: Bool) -> some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .foregroundStyle(isSelected ? CafadePalette.accentText : CafadePalette.mist)
    }

    private func planName(_ option: EntitlementService.SubscriptionOption) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(option.title)
                .font(.caption.weight(.semibold))
                .tracking(1.1)
                .foregroundStyle(CafadePalette.accentText)
            Text(option.price)
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(CafadePalette.paper)
        }
    }

    private func planTerms(_ option: EntitlementService.SubscriptionOption) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(option.periodLabel)
                .font(.caption)
                .foregroundStyle(CafadePalette.mist)
            if let trial = option.eligibleTrialLabel {
                Text("\(trial) free trial")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CafadePalette.mint)
            }
        }
    }

    private var purchaseButton: some View {
        VStack(spacing: 10) {
            Button {
                guard let selectedOption else { return }
                Task {
                    await entitlements.purchase(option: selectedOption)
                    if entitlements.isPro { dismiss() }
                }
            } label: {
                Text(purchaseButtonTitle)
            }
            .buttonStyle(CafadePrimaryButtonStyle())
            .disabled(entitlements.state.isBusy || selectedOption == nil)
            .opacity(selectedOption == nil ? 0.55 : 1)

            if let selectedOption {
                Text(selectedOption.renewalDescription)
                    .font(.caption)
                    .foregroundStyle(CafadePalette.mist)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var purchaseButtonTitle: String {
        if entitlements.state == .purchasing { return "Connecting…" }
        if let trial = selectedOption?.eligibleTrialLabel {
            return "Start \(trial) free trial"
        }
        return "Continue with Cafade Pro"
    }

    private var restoreButton: some View {
        Button {
            Task { await entitlements.restorePurchases() }
        } label: {
            Text(entitlements.state == .restoring ? "Restoring…" : "Restore purchases")
        }
        .buttonStyle(CafadeSecondaryButtonStyle())
        .disabled(entitlements.state.isBusy || !entitlements.isConfigured)
    }

    private func unavailableCard(title: String, detail: String, showsRetry: Bool = false) -> some View {
        CafadeGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(CafadePalette.paper)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(CafadePalette.mist)
                if showsRetry {
                    Button("Try again") {
                        Task { await entitlements.refresh() }
                    }
                    .buttonStyle(CafadeSecondaryButtonStyle())
                }
            }
        }
    }

    private var legal: some View {
        HStack(spacing: 14) {
            Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            Text("•")
            Link("Privacy", destination: URL(string: "https://cafade.oneshotstar.com/privacy/")!)
        }
        .font(.caption)
        .foregroundStyle(CafadePalette.mist)
        .frame(maxWidth: .infinity)
    }

    private func selectDefaultOption() {
        if let selectedOptionID,
           entitlements.options.contains(where: { $0.id == selectedOptionID }) {
            return
        }
        selectedOptionID = entitlements.options.first(where: { $0.title == "YEARLY" })?.id
            ?? entitlements.options.first?.id
    }
}
