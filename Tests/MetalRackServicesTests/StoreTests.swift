import XCTest
import StoreKit
#if !SWIFT_PACKAGE
import StoreKitTest
#endif
import MetalRackServices

@MainActor
final class StoreTests: XCTestCase {
    func testLegacyIdentifierVectors() {
        XCTAssertEqual(LegacyIdentifierDigest.digest(Data()), "d41d8cd98f00b204e9800998ecf8427e")
        XCTAssertEqual(LegacyIdentifierDigest.digest(Data("abc".utf8)), "900150983cd24fb0d6963f7d28e17f72")
        XCTAssertEqual(LegacyIdentifierDigest.digest(Data("message digest".utf8)), "f96b697d7cb7938d525a2f31aaf161d0")
    }

    #if !SWIFT_PACKAGE
    func testVerifiedPurchaseAndPendingApprovalDeliverOnce() async throws {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: StoreTests.self)
        #endif
        let session = try SKTestSession(contentsOf: bundle.url(forResource: "Store", withExtension: "storekit")!)
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let service = StoreService.shared
        defer { service.startObserving(delivery: { _ in false }, notification: { _ in }) }
        let identifier = "gnomes0_currency_0"
        let response: StoreResponse = try await withCheckedThrowingContinuation { continuation in
            service.loadProducts([identifier, "missing-product"]) { response, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: response!) }
            }
        }
        XCTAssertEqual(response.products.map(\.productIdentifier), [identifier])
        XCTAssertEqual(response.invalidProductIdentifiers, ["missing-product"])
        let product = try XCTUnwrap(response.products.first)
        let deferred = expectation(description: "delivery waits until the application is ready")
        var notifiedDeferred = false
        service.startObserving(delivery: { _ in
            if !notifiedDeferred { notifiedDeferred = true; deferred.fulfill() }
            return false
        }, notification: { _ in })
        service.purchase(product)
        await fulfillment(of: [deferred], timeout: 15)
        var deliveries: [String] = []
        let first = expectation(description: "verified direct purchase")
        let second = expectation(description: "approved pending purchase")
        let pendingNotice = expectation(description: "pending approval")
        let failureNotice = expectation(description: "failed purchase")
        let cancellationNotice = expectation(description: "cancelled purchase")
        service.startObserving(delivery: { transaction in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(transaction.productIdentifier, identifier)
            deliveries.append(transaction.transactionIdentifier!)
            if deliveries.count == 1 { first.fulfill() } else { second.fulfill() }
            return true
        }, notification: { transaction in
            if transaction.status == "pending" { pendingNotice.fulfill() }
            if transaction.status == "failed" { XCTAssertNotNil(transaction.error); failureNotice.fulfill() }
            if transaction.status == "cancelled" { XCTAssertNil(transaction.error); cancellationNotice.fulfill() }
        })
        // Replacing the callback replays the unfinished verified purchase.
        await fulfillment(of: [first], timeout: 15)
        session.askToBuyEnabled = true
        service.purchase(product)
        await fulfillment(of: [pendingNotice], timeout: 15)
        let pending = try XCTUnwrap(session.allTransactions().last)
        XCTAssertEqual(deliveries.count, 1, "Pending purchases grant no currency")
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        await fulfillment(of: [second], timeout: 15)
        XCTAssertEqual(Set(deliveries).count, 2, "Each verified transaction is delivered exactly once")
        // Both the updates listener and explicit unfinished replay are active.
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(deliveries.count, 2)
        session.askToBuyEnabled = false
        try await session.setSimulatedError(.purchase(.productUnavailable), forAPI: .purchase)
        service.purchase(product)
        await fulfillment(of: [failureNotice], timeout: 15)
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        service.purchase(product)
        await fulfillment(of: [cancellationNotice], timeout: 15)
        XCTAssertEqual(deliveries.count, 2, "Failures and cancellations never deliver currency")
    }
    #endif
}
