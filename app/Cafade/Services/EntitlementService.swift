import Combine
import Foundation
import RevenueCat

@MainActor
final class EntitlementService: NSObject, ObservableObject {
    enum State: Equatable {
        case notConfigured
        case idle
        case loading
        case ready
        case purchasing
        case restoring
        case purchased
        case restored
        case noPurchases
        case failed(String)

        var isBusy: Bool {
            switch self {
            case .loading, .purchasing, .restoring:
                true
            default:
                false
            }
        }

        var failureMessage: String? {
            if case .failed(let message) = self { return message }
            return nil
        }
    }

    struct SubscriptionOption: Identifiable {
        fileprivate let package: Package?

        let id: String
        let productIdentifier: String
        let title: String
        let price: String
        let periodLabel: String
        let eligibleTrialLabel: String?

        var renewalDescription: String {
            if let eligibleTrialLabel {
                return "\(eligibleTrialLabel) free, then \(price) \(periodLabel). Auto-renews until canceled."
            }
            return "\(price) \(periodLabel). Auto-renews until canceled."
        }

        fileprivate init(package: Package, eligibility: IntroEligibilityStatus) {
            self.package = package
            id = package.identifier
            productIdentifier = package.storeProduct.productIdentifier
            price = package.storeProduct.localizedPriceString

            switch package.packageType {
            case .annual:
                title = "YEARLY"
                periodLabel = "per year"
            case .monthly:
                title = "MONTHLY"
                periodLabel = "per month"
            default:
                let identifier = package.identifier.lowercased()
                if identifier.contains("year") || identifier.contains("annual") {
                    title = "YEARLY"
                    periodLabel = "per year"
                } else {
                    title = "MONTHLY"
                    periodLabel = "per month"
                }
            }

            if eligibility == .eligible,
               let discount = package.storeProduct.introductoryDiscount,
               discount.paymentMode == .freeTrial {
                eligibleTrialLabel = Self.periodLabel(discount.subscriptionPeriod)
            } else {
                eligibleTrialLabel = nil
            }
        }

        private static func periodLabel(_ period: SubscriptionPeriod) -> String {
            let unit: String
            switch period.unit {
            case .day: unit = "day"
            case .week: unit = "week"
            case .month: unit = "month"
            case .year: unit = "year"
            @unknown default: unit = "period"
            }
            return "\(period.value)-\(unit)"
        }
    }

    static let entitlementID = "pro"

    @Published private(set) var state: State
    @Published private(set) var options: [SubscriptionOption] = []
    @Published private(set) var isPro = false
    @Published private(set) var lastMessage: String?

    let isConfigured: Bool

    init(apiKey: String? = Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String) {
        let normalizedKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        isConfigured = !normalizedKey.isEmpty
        state = isConfigured ? .idle : .notConfigured
        super.init()

        guard isConfigured else { return }
        Purchases.configure(withAPIKey: normalizedKey)
        Purchases.shared.delegate = self
    }

    func refresh() async {
        _ = await refreshCustomerInfo()
        await loadOfferings(refreshEntitlement: false)
    }

    func loadOfferings(refreshEntitlement: Bool = true) async {
        guard isConfigured else {
            options = []
            state = .notConfigured
            return
        }

        if refreshEntitlement {
            _ = await refreshCustomerInfo()
        }

        state = .loading
        lastMessage = nil
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let currentOffering = offerings.current else {
                options = []
                state = .failed("No active subscription offering is available. Check your connection and try again.")
                return
            }

            let packages = currentOffering.availablePackages.sorted { lhs, rhs in
                if lhs.packageType == .annual && rhs.packageType != .annual { return true }
                if lhs.packageType != .annual && rhs.packageType == .annual { return false }
                return lhs.identifier < rhs.identifier
            }
            let productIDs = packages.map(\.storeProduct.productIdentifier)
            let eligibility = await Purchases.shared.checkTrialOrIntroDiscountEligibility(
                productIdentifiers: productIDs
            )
            options = packages.map { package in
                SubscriptionOption(
                    package: package,
                    eligibility: eligibility[package.storeProduct.productIdentifier]?.status ?? .unknown
                )
            }
            state = options.isEmpty
                ? .failed("No subscription plans are available. Check your connection and try again.")
                : .ready
        } catch is CancellationError {
            return
        } catch {
            options = []
            state = .failed("Subscription plans could not be loaded. Check your connection and try again.")
        }
    }

    func purchase(option: SubscriptionOption) async {
        guard isConfigured else {
            state = .notConfigured
            lastMessage = "Subscriptions are not configured in this build."
            return
        }
        guard let package = option.package else {
            state = .failed("This subscription plan is not available. Try loading the plans again.")
            return
        }

        state = .purchasing
        lastMessage = nil
        do {
            let result = try await Purchases.shared.purchase(package: package)
            apply(customerInfo: result.customerInfo)
            if result.userCancelled {
                state = .ready
            } else {
                state = .purchased
                lastMessage = isPro ? "Cafade Pro is active." : "The purchase finished, but Pro is not active yet. Try Restore Purchases."
            }
        } catch is CancellationError {
            state = .ready
        } catch {
            state = .failed(error.localizedDescription)
            lastMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        guard isConfigured else {
            state = .notConfigured
            lastMessage = "Subscriptions are not configured in this build."
            return
        }

        state = .restoring
        lastMessage = nil
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            apply(customerInfo: customerInfo)
            if isPro {
                state = .restored
                lastMessage = "Cafade Pro has been restored."
            } else {
                state = .noPurchases
                lastMessage = "No previous Cafade Pro purchase was found."
            }
        } catch is CancellationError {
            state = options.isEmpty ? .idle : .ready
        } catch {
            state = .failed(error.localizedDescription)
            lastMessage = error.localizedDescription
        }
    }

    @discardableResult
    func refreshCustomerInfo() async -> Bool? {
        guard isConfigured else { return false }
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            apply(customerInfo: customerInfo)
            return isPro
        } catch is CancellationError {
            return nil
        } catch {
            return isPro ? true : nil
        }
    }

    private func apply(customerInfo: CustomerInfo) {
        isPro = customerInfo.entitlements.all[Self.entitlementID]?.isActive == true
    }
}

extension EntitlementService: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor [weak self] in
            self?.apply(customerInfo: customerInfo)
        }
    }
}
