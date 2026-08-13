import Combine
import Foundation
import RevenueCat

@MainActor
final class EntitlementService: ObservableObject {
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
    }

    struct SubscriptionOption: Identifiable {
        fileprivate let package: Package?

        let id: String
        let title: String
        let price: String
        let hasIntroductoryOffer: Bool
        let periodLabel: String

        fileprivate init(package: Package) {
            self.package = package
            id = package.identifier
            price = package.storeProduct.localizedPriceString
            hasIntroductoryOffer = package.storeProduct.introductoryDiscount != nil

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
        }

        fileprivate init(
            id: String,
            title: String,
            price: String,
            periodLabel: String
        ) {
            package = nil
            self.id = id
            self.title = title
            self.price = price
            self.periodLabel = periodLabel
            hasIntroductoryOffer = true
        }

        static let previewMonthly = Self(
            id: "cafade_pro_monthly",
            title: "MONTHLY",
            price: "$2.99",
            periodLabel: "per month"
        )

        static let previewYearly = Self(
            id: "cafade_pro_yearly",
            title: "YEARLY",
            price: "$29.99",
            periodLabel: "per year"
        )
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

        guard isConfigured else { return }
        Purchases.configure(withAPIKey: normalizedKey)
    }

    var displayOptions: [SubscriptionOption] {
        options.isEmpty ? [.previewMonthly, .previewYearly] : options
    }

    func loadOfferings() async {
        guard isConfigured else {
            state = .notConfigured
            return
        }

        state = .loading
        lastMessage = nil
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let currentOffering = offerings.current else {
                state = .failed("No active subscription offering is available.")
                return
            }
            options = currentOffering.availablePackages
                .sorted { lhs, rhs in
                    if lhs.packageType == .annual && rhs.packageType != .annual { return true }
                    if lhs.packageType != .annual && rhs.packageType == .annual { return false }
                    return lhs.identifier < rhs.identifier
                }
                .map(SubscriptionOption.init(package:))
            state = options.isEmpty ? .failed("No subscription plans are available.") : .ready
            await refreshCustomerInfo()
        } catch is CancellationError {
            return
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func purchase(option: SubscriptionOption) async {
        guard isConfigured, let package = option.package else {
            state = .notConfigured
            lastMessage = "Subscription products will be available after RevenueCat is connected."
            return
        }

        state = .purchasing
        lastMessage = nil
        do {
            let result = try await Purchases.shared.purchase(package: package)
            apply(customerInfo: result.customerInfo)
            if result.userCancelled {
                state = .ready
                lastMessage = "Purchase canceled."
            } else {
                state = .purchased
                lastMessage = isPro ? "Cafade Pro is active." : "Purchase completed."
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
            lastMessage = "Purchase restoration will be available after RevenueCat is connected."
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
            state = .ready
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
