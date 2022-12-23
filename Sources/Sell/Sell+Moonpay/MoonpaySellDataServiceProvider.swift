import Foundation
import Moonpay

public enum MoonpaySellDataServiceProviderError: Error {
    case unsupportedRegion
}

public class MoonpaySellDataServiceProvider: SellDataServiceProvider {
    
    // MARK: - Type aliases

    public typealias Currency = MoonpayCurrency
    public typealias Transaction = MoonpayTransaction
    public typealias Fiat = MoonpayFiat

    // MARK: - Properties

    private let moonpayAPI: Moonpay.Provider
    private(set) var ipAddressesResponse: Moonpay.Provider.IpAddressResponse?
    
    // MARK: - Initializer

    public init(moonpayAPI: Moonpay.Provider, ipAddressesResponse: Moonpay.Provider.IpAddressResponse? = nil) {
        self.moonpayAPI = moonpayAPI
        self.ipAddressesResponse = ipAddressesResponse
    }
    
    // MARK: - Methods

    func isAvailable() async throws -> Bool {
        guard let ipAddressesResponse else {
            let resp = try await moonpayAPI.ipAddresses()
            ipAddressesResponse = resp
            return resp.isSellAllowed
        }
        return ipAddressesResponse.isSellAllowed
    }

    func fiat() async throws -> Fiat {
        func fiatByApha3(alpha3: String) throws -> Fiat {
            if moonpayAPI.UKAlpha3Code() == alpha3 {
                return .gbp
            } else if moonpayAPI.bankTransferAvailableAlpha3Codes().contains(alpha3) {
                return .eur
            } else if moonpayAPI.USAlpha3Code() == alpha3 {
                return .usd
            }
            throw MoonpaySellDataServiceProviderError.unsupportedRegion
        }
        guard let ipAddressesResponse else {
            let resp = try await moonpayAPI.ipAddresses()
            ipAddressesResponse = resp
            return try fiatByApha3(alpha3: resp.alpha3)
        }
        return try fiatByApha3(alpha3: ipAddressesResponse.alpha3)
    }

    func currencies() async throws -> [Currency] {
        let currencies = try await moonpayAPI.getAllSupportedCurrencies()
        return currencies.map { cur in
            MoonpayCurrency(
                id: cur.id,
                name: cur.name,
                code: cur.code,
                precision: cur.precision ?? 0,
                minSellAmount: cur.minSellAmount ?? 0,
                maxSellAmount: cur.maxSellAmount ?? 0,
                isSuspended: cur.isSuspended ?? false
            )
        }
    }

    public func sellTransactions(externalTransactionId: String) async throws -> [Transaction] {
        try await moonpayAPI.sellTransactions(externalTransactionId: externalTransactionId)
    }

    public func detailSellTransaction(id: String) async throws -> Transaction {
        try await moonpayAPI.sellTransaction(id: id)
    }

    public func deleteSellTransaction(id: String) async throws {
        try await moonpayAPI.deleteSellTransaction(id: id)
    }
}

extension MoonpaySellDataServiceProvider {
    public struct MoonpayCurrency: ProviderCurrency, Codable {
        public var id: String
        public var name: String
        public var code: String
        public var precision: Int
        public var minSellAmount: Double?
        public var maxSellAmount: Double?
        public var isSuspended: Bool
    }
    
    public enum MoonpayFiat: String, ProviderFiat {
        public var code: String {
            rawValue.uppercased()
        }
        
        case gbp
        case eur
        case usd
    }

    public struct MoonpayTransaction: Codable, ProviderTransaction {
        public var id: String
        public var createdAt: String
        public var updatedAt: String
        public var baseCurrencyAmount: Double
        public var quoteCurrencyAmount: Double?
        public var feeAmount: Double?
        public var extraFeeAmount: Double?
        public var status: MoonpayTransaction.Status
        public var failureReason: String?
        public var refundWalletAddress: String?
        public var depositHash: String?
        public var depositWalletId: String
        public var quoteCurrencyId: String
        public var baseCurrencyId: String
        public var depositWallet: DepositWallet?
        public var usdRate: Double?
        public var eurRate: Double?
        public var gbpRate: Double?
    }
}

extension MoonpaySellDataServiceProvider.MoonpayTransaction {
    public enum Status: String, Codable, Hashable {
        case waitingForDeposit
        case pending
        case failed
        case completed
    }

    public struct DepositWallet: Codable, Equatable, Hashable {
        public var walletAddress: String
    }
}
