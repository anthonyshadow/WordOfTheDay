import Foundation
import RevenueCat

enum RevenueCatPackageKind: Equatable {
    case monthly
    case yearly
}

struct RevenueCatEntitlementSnapshot: Equatable {
    let isTrial: Bool
    let expirationDate: Date?
}

struct RevenueCatCustomerSnapshot: Equatable {
    let activeEntitlements: [RevenueCatEntitlementSnapshot]
    let latestExpirationDate: Date?

    init(
        activeEntitlements: [RevenueCatEntitlementSnapshot],
        latestExpirationDate: Date?
    ) {
        self.activeEntitlements = activeEntitlements
        self.latestExpirationDate = latestExpirationDate
    }

    init(customerInfo: CustomerInfo) {
        self.activeEntitlements = customerInfo.entitlements.active.values.map { entitlement in
            RevenueCatEntitlementSnapshot(
                isTrial: entitlement.periodType == .trial,
                expirationDate: entitlement.expirationDate
            )
        }
        self.latestExpirationDate = customerInfo.latestExpirationDate
    }
}

protocol RevenueCatClientProtocol {
    func logIn(_ appUserID: String) async throws
    func logOut() async throws
    func fetchCustomerSnapshot() async throws -> RevenueCatCustomerSnapshot
    func purchase(package: RevenueCatPackageKind) async throws -> RevenueCatCustomerSnapshot
    func restorePurchases() async throws -> RevenueCatCustomerSnapshot
}

private final class LiveRevenueCatClient: RevenueCatClientProtocol {
    private static let lock = NSLock()

    private let purchases: Purchases

    init(apiKey: String) {
        self.purchases = Self.makePurchases(apiKey: apiKey)
    }

    func logIn(_ appUserID: String) async throws {
        _ = try await purchases.logIn(appUserID)
    }

    func logOut() async throws {
        _ = try await purchases.logOut()
    }

    func fetchCustomerSnapshot() async throws -> RevenueCatCustomerSnapshot {
        RevenueCatCustomerSnapshot(customerInfo: try await purchases.customerInfo())
    }

    func purchase(package kind: RevenueCatPackageKind) async throws -> RevenueCatCustomerSnapshot {
        let offerings = try await purchases.offerings()
        let package = try Self.selectPackage(in: offerings, matching: kind)
        let result = try await purchases.purchase(package: package)

        if result.userCancelled {
            throw CancellationError()
        }

        return RevenueCatCustomerSnapshot(customerInfo: result.customerInfo)
    }

    func restorePurchases() async throws -> RevenueCatCustomerSnapshot {
        RevenueCatCustomerSnapshot(customerInfo: try await purchases.restorePurchases())
    }

    private static func makePurchases(apiKey: String) -> Purchases {
        lock.lock()
        defer { lock.unlock() }

        if Purchases.isConfigured {
            return Purchases.shared
        }

        return Purchases.configure(withAPIKey: apiKey)
    }

    private static func selectPackage(in offerings: Offerings, matching kind: RevenueCatPackageKind) throws -> Package {
        let availablePackages = (offerings.current?.availablePackages ?? offerings.all.values.first?.availablePackages) ?? []

        guard !availablePackages.isEmpty else {
            throw AppError.validation("Subscriptions are not available right now.")
        }

        let preferredType: PackageType = kind == .monthly ? .monthly : .annual
        if let preferredPackage = availablePackages.first(where: { $0.packageType == preferredType }) {
            return preferredPackage
        }

        let fallbackOrder: [PackageType] = kind == .monthly
            ? [.weekly, .twoMonth, .threeMonth, .sixMonth, .annual, .lifetime, .custom, .unknown]
            : [.sixMonth, .threeMonth, .twoMonth, .monthly, .weekly, .lifetime, .custom, .unknown]

        for packageType in fallbackOrder {
            if let fallbackPackage = availablePackages.first(where: { $0.packageType == packageType }) {
                return fallbackPackage
            }
        }

        return availablePackages[0]
    }
}

final class RevenueCatSubscriptionService: SubscriptionServiceProtocol {
    private enum SyncState: Equatable {
        case unknown
        case anonymous
        case authenticated(String)
    }

    private actor SessionStateStore {
        private var state: SyncState = .unknown

        func currentState() -> SyncState {
            state
        }

        func setState(_ newState: SyncState) {
            state = newState
        }
    }

    private let client: RevenueCatClientProtocol?
    private let sessionProvider: @MainActor @Sendable () -> AuthSession?
    private let sessionStateStore = SessionStateStore()

    init(
        apiKey: String?,
        sessionProvider: @escaping @MainActor @Sendable () -> AuthSession? = { nil },
        client: RevenueCatClientProtocol? = nil
    ) {
        self.sessionProvider = sessionProvider

        if let client {
            self.client = client
        } else if let apiKey, !apiKey.isEmpty {
            self.client = LiveRevenueCatClient(apiKey: apiKey)
        } else {
            self.client = nil
        }
    }

    func fetchSubscriptionState() async throws -> SubscriptionState {
        guard let client else {
            return Self.freeTierState
        }

        do {
            let currentUserID = await sessionProvider()?.userID.uuidString
            try await syncRevenueCatSessionIfNeeded(currentUserID: currentUserID)

            guard currentUserID != nil else {
                return Self.freeTierState
            }

            return Self.mapSubscriptionState(from: try await client.fetchCustomerSnapshot())
        } catch let error as CancellationError {
            throw error
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.unknown(error.localizedDescription)
        }
    }

    func purchaseMonthly() async throws -> SubscriptionState {
        try await purchase(package: .monthly)
    }

    func purchaseYearly() async throws -> SubscriptionState {
        try await purchase(package: .yearly)
    }

    func restorePurchases() async throws -> SubscriptionState {
        guard let client else {
            throw AppError.validation("Subscriptions are not configured yet.")
        }

        do {
            let currentUserID = try await authenticatedUserID()
            try await syncRevenueCatSessionIfNeeded(currentUserID: currentUserID)
            return Self.mapSubscriptionState(from: try await client.restorePurchases())
        } catch let error as CancellationError {
            throw error
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.unknown(error.localizedDescription)
        }
    }

    private func purchase(package kind: RevenueCatPackageKind) async throws -> SubscriptionState {
        guard let client else {
            throw AppError.validation("Subscriptions are not configured yet.")
        }

        do {
            let currentUserID = try await authenticatedUserID()
            try await syncRevenueCatSessionIfNeeded(currentUserID: currentUserID)
            return Self.mapSubscriptionState(from: try await client.purchase(package: kind))
        } catch let error as CancellationError {
            throw error
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.unknown(error.localizedDescription)
        }
    }

    private func authenticatedUserID() async throws -> String {
        guard let currentUserID = await sessionProvider()?.userID.uuidString else {
            throw AppError.auth("Sign in before managing subscriptions.")
        }

        return currentUserID
    }

    private func syncRevenueCatSessionIfNeeded(currentUserID: String?) async throws {
        guard let client else {
            return
        }

        let desiredState: SyncState = currentUserID.map(SyncState.authenticated) ?? .anonymous
        let currentState = await sessionStateStore.currentState()

        guard currentState != desiredState else {
            return
        }

        switch desiredState {
        case let .authenticated(userID):
            try await client.logIn(userID)
        case .anonymous:
            try await client.logOut()
        case .unknown:
            return
        }

        await sessionStateStore.setState(desiredState)
    }

    static func mapSubscriptionState(from snapshot: RevenueCatCustomerSnapshot) -> SubscriptionState {
        guard let entitlement = snapshot.activeEntitlements.first else {
            return SubscriptionState(
                tier: .free,
                isTrial: false,
                expiresAt: snapshot.latestExpirationDate
            )
        }

        return SubscriptionState(
            tier: .premium,
            isTrial: entitlement.isTrial,
            expiresAt: entitlement.expirationDate ?? snapshot.latestExpirationDate
        )
    }

    private static let freeTierState = SubscriptionState(tier: .free, isTrial: false, expiresAt: nil)
}
