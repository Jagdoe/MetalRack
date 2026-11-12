import Foundation
import StoreKit
import CryptoKit

@objc(MRStoreProduct)
public final class StoreProduct: NSObject {
    @objc public let productIdentifier: String
    @objc public let displayPrice: String
    fileprivate let product: Product
    init(_ product: Product) {
        self.product = product
        productIdentifier = product.id
        displayPrice = product.displayPrice
    }
}

@objc(MRStoreResponse)
public final class StoreResponse: NSObject {
    @objc public let products: [StoreProduct]
    @objc public let invalidProductIdentifiers: [String]
    init(products: [Product], identifiers: Set<String>) {
        self.products = products.map(StoreProduct.init)
        invalidProductIdentifiers = identifiers.subtracting(products.map(\.id)).sorted()
    }
}

@objc(MRStoreTransaction)
public final class StoreTransaction: NSObject {
    @objc public let productIdentifier: String
    @objc public let transactionIdentifier: String?
    @objc public let error: NSError?
    @objc public let status: String
    init(productID: String, transactionID: UInt64? = nil, status: String, error: Error? = nil) {
        productIdentifier = productID
        transactionIdentifier = transactionID.map(String.init)
        self.status = status
        self.error = error as NSError?
    }
}

/// Objective-C entry points always run on the application's main thread.
/// Deliver verified transactions before finishing; updates and direct purchase
/// results share one delivery path so a transaction cannot grant twice.
@MainActor @objc(MRStoreService)
public final class StoreService: NSObject {
    @objc public static let shared = StoreService()
    private override init() { super.init() }
    private var listener: Task<Void, Never>?
    private var delivering: Set<UInt64> = []
    private var delivered: Set<UInt64> = []
    private var undelivered: [UInt64: Transaction] = [:]
    private var delivery: ((StoreTransaction) -> Bool)?
    private var notification: ((StoreTransaction) -> Void)?

    @objc(startObservingWithDelivery:notification:)
    public func startObserving(delivery: @escaping (StoreTransaction) -> Bool,
                               notification: @escaping (StoreTransaction) -> Void) {
        self.delivery = delivery
        self.notification = notification
        if listener == nil {
            listener = Task { [weak self] in
                for await result in Transaction.updates {
                    guard let self else { return }
                    await self.receive(result)
                }
            }
        }
        Task { [weak self] in
            guard let self else { return }
            // Keep receipts already verified in this process until delivery
            // succeeds. StoreKit's unfinished enumeration can lag the direct
            // purchase result while its transaction record is being updated.
            for transaction in Array(self.undelivered.values) {
                await self.receive(.verified(transaction))
            }
            for await result in Transaction.unfinished {
                await self.receive(result)
            }
        }
    }

    deinit { listener?.cancel() }

    @objc(loadProducts:completion:)
    public func loadProducts(_ identifiers: Set<String>, completion: @escaping (StoreResponse?, NSError?) -> Void) {
        Task {
            do { completion(StoreResponse(products: try await Product.products(for: identifiers), identifiers: identifiers), nil) }
            catch { completion(nil, error as NSError) }
        }
    }

    @objc(purchaseProduct:)
    public func purchase(_ item: StoreProduct) {
        guard AppStore.canMakePayments else { return }
        Task {
            do {
                switch try await item.product.purchase() {
                case .success(let result): await receive(result)
                case .pending:
                    notification?(StoreTransaction(productID: item.productIdentifier, status: "pending"))
                case .userCancelled:
                    notification?(StoreTransaction(productID: item.productIdentifier, status: "cancelled"))
                @unknown default: break
                }
            } catch StoreKitError.userCancelled {
                notification?(StoreTransaction(productID: item.productIdentifier, status: "cancelled"))
            } catch {
                notification?(StoreTransaction(productID: item.productIdentifier, status: "failed", error: error))
            }
        }
    }

    private func receive(_ result: VerificationResult<Transaction>) async {
        switch result {
        case .unverified(let transaction, let error):
            notification?(StoreTransaction(productID: transaction.productID, transactionID: transaction.id, status: "failed", error: error))
        case .verified(let transaction):
            guard transaction.revocationDate == nil, !transaction.isUpgraded else {
                await transaction.finish()
                return
            }
            guard !delivering.contains(transaction.id) else { return }
            undelivered[transaction.id] = transaction
            delivering.insert(transaction.id)
            defer { delivering.remove(transaction.id) }
            let event = StoreTransaction(productID: transaction.productID, transactionID: transaction.id, status: "purchased")
            if delivered.contains(transaction.id) || delivery?(event) == true {
                delivered.insert(transaction.id)
                undelivered.removeValue(forKey: transaction.id)
                await transaction.finish()
                notification?(event)
            }
        }
    }
}

@objc(MRLegacyIdentifierDigest)
public final class LegacyIdentifierDigest: NSObject {
    /// Preserve existing server/device identifiers. MD5 is used only for the
    /// established identifier/cache format, never authentication or verification.
    @objc public static func digest(_ data: Data) -> String {
        Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
