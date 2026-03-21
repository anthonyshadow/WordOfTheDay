import XCTest
@testable import LinguaDaily

final class RevenueCatSubscriptionServiceTests: XCTestCase {
    func testFetchSubscriptionStateReturnsFreeWhenRevenueCatIsNotConfigured() async throws {
        let service = RevenueCatSubscriptionService(apiKey: nil)

        let state = try await service.fetchSubscriptionState()

        XCTAssertEqual(state, SubscriptionState(tier: .free, isTrial: false, expiresAt: nil))
    }

    func testFetchSubscriptionStateLogsInAuthenticatedUserAndMapsPremiumTrial() async throws {
        let expirationDate = Date(timeIntervalSince1970: 1_800_000_000)
        let client = MockRevenueCatClient()
        client.fetchSnapshotResult = .success(
            RevenueCatCustomerSnapshot(
                activeEntitlements: [
                    RevenueCatEntitlementSnapshot(isTrial: true, expirationDate: expirationDate)
                ],
                latestExpirationDate: expirationDate
            )
        )
        let session = TestData.session()
        let service = RevenueCatSubscriptionService(
            apiKey: nil,
            sessionProvider: { session },
            client: client
        )

        let state = try await service.fetchSubscriptionState()

        XCTAssertEqual(client.loggedInUserIDs, [session.userID.uuidString])
        XCTAssertEqual(state, SubscriptionState(tier: .premium, isTrial: true, expiresAt: expirationDate))
    }

    func testFetchSubscriptionStateLogsOutWhenNoAuthenticatedUserExists() async throws {
        let client = MockRevenueCatClient()
        let service = RevenueCatSubscriptionService(
            apiKey: nil,
            sessionProvider: { nil },
            client: client
        )

        let state = try await service.fetchSubscriptionState()

        XCTAssertEqual(client.logOutCallCount, 1)
        XCTAssertEqual(state, SubscriptionState(tier: .free, isTrial: false, expiresAt: nil))
        XCTAssertEqual(client.fetchSnapshotCallCount, 0)
    }

    func testRestorePurchasesRequiresAuthenticatedUser() async {
        let client = MockRevenueCatClient()
        let service = RevenueCatSubscriptionService(
            apiKey: nil,
            sessionProvider: { nil },
            client: client
        )

        do {
            _ = try await service.restorePurchases()
            XCTFail("Expected restore purchases to require auth")
        } catch let error as AppError {
            XCTAssertEqual(error, .auth("Sign in before managing subscriptions."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPurchaseMonthlyMapsReturnedPremiumState() async throws {
        let expirationDate = Date(timeIntervalSince1970: 1_900_000_000)
        let client = MockRevenueCatClient()
        client.purchaseResult = .success(
            RevenueCatCustomerSnapshot(
                activeEntitlements: [
                    RevenueCatEntitlementSnapshot(isTrial: false, expirationDate: expirationDate)
                ],
                latestExpirationDate: expirationDate
            )
        )
        let service = RevenueCatSubscriptionService(
            apiKey: nil,
            sessionProvider: { TestData.session() },
            client: client
        )

        let state = try await service.purchaseMonthly()

        XCTAssertEqual(client.purchasedPackages, [.monthly])
        XCTAssertEqual(state, SubscriptionState(tier: .premium, isTrial: false, expiresAt: expirationDate))
    }
}

private final class MockRevenueCatClient: RevenueCatClientProtocol {
    var fetchSnapshotResult: Result<RevenueCatCustomerSnapshot, Error> = .success(
        RevenueCatCustomerSnapshot(activeEntitlements: [], latestExpirationDate: nil)
    )
    var purchaseResult: Result<RevenueCatCustomerSnapshot, Error> = .success(
        RevenueCatCustomerSnapshot(activeEntitlements: [], latestExpirationDate: nil)
    )
    var restoreResult: Result<RevenueCatCustomerSnapshot, Error> = .success(
        RevenueCatCustomerSnapshot(activeEntitlements: [], latestExpirationDate: nil)
    )

    private(set) var loggedInUserIDs: [String] = []
    private(set) var logOutCallCount = 0
    private(set) var fetchSnapshotCallCount = 0
    private(set) var purchasedPackages: [RevenueCatPackageKind] = []
    private(set) var restoreCallCount = 0

    func logIn(_ appUserID: String) async throws {
        loggedInUserIDs.append(appUserID)
    }

    func logOut() async throws {
        logOutCallCount += 1
    }

    func fetchCustomerSnapshot() async throws -> RevenueCatCustomerSnapshot {
        fetchSnapshotCallCount += 1
        return try fetchSnapshotResult.get()
    }

    func purchase(package: RevenueCatPackageKind) async throws -> RevenueCatCustomerSnapshot {
        purchasedPackages.append(package)
        return try purchaseResult.get()
    }

    func restorePurchases() async throws -> RevenueCatCustomerSnapshot {
        restoreCallCount += 1
        return try restoreResult.get()
    }
}
