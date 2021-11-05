//
//  TradeOgreAPI.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 10/27/21.
//

import Combine
import Foundation

extension String {
    var asDouble: Double {
        if let double = Double(self) {
            return double
        }
        let fmt = NumberFormatter()
        if let fmtDouble = fmt.number(from: self) {
            return fmtDouble.doubleValue
        }
        fmt.numberStyle = .currency
        if let fmtDouble = fmt.number(from: self) {
            return fmtDouble.doubleValue
        }
        return 0.0
    }
    var asPrice: TradeOgreAPI.Price {
        return self.asDouble
    }
    var asVolume: TradeOgreAPI.Volume {
        return self.asDouble
    }
}

/// Type-erased protocol
// TODO: Expand this definition to be useful?
protocol TradeOgreClientType {
    
}

/// Namespacing class for TradeOgre network services.
public class TradeOgreAPI {
    /// A currency identifier (.e.g `"BTC"`).
    public typealias Currency = String
    public typealias Price = Double
    public typealias Volume = Double
    public enum Action {
        case buy
        case sell
    }
    /// A market, defined by a pair of `Currency`. `base` is the "pricing standard", while `other` is the asset which is being priced against `base`; e.g. `"BTC-XMR"` represents the market of buying or selling XMR priced in BTC.
    public struct CurrencyPair : Codable {
        let base: Currency
        let other: Currency
        init?(key: String) {
            var splits = key.split(separator: "-")
            guard splits.count == 2,
                let o = splits.popLast(),
                let b = splits.popLast() else {
                return nil
            }
            self.base = Currency(b)
            self.other = Currency(o)
        }
        init(base: Currency, other: Currency) {
            self.base = base
            self.other = other
        }
        var asString: String {
            return "\(self.base)-\(self.other)"
        }
    }
    // TODO: Better error management
    public enum TradeOgreError : Error {
        case serverError(URLError)
        case authenticationError
        case miscError(Error)
        case unknownError(String)
    }
    
    private init() { // Block construction
        
    }
    
    /// TradeOgre v1 client. See https://tradeogre.com/help/api for API details
    public class V1 : TradeOgreClientType {
        /// Specific market data over the last 24 hours.
        public struct MarketData : Codable {
            let initialprice: Price
            let price: Price
            let high: Price
            let low: Price
            let volume: Volume
            let bid: Price
            let ask: Price
            var priceDelta: Price {
                return self.price - self.initialprice
            }
            var priceDeltaPercent: Double {
                return (self.price - self.initialprice) / self.initialprice
            }
        }
        /// Market pricing, volume movement, and more as defined by a `currencyPair` and `marketData` from the past 24 hours.
        public struct Market {
            let currencyPair: CurrencyPair
            let marketData: MarketData
        }
        /// An order submitted to the market represented by `currencyPair` by the current account, uniquely identified by `uuid`.
        public struct PendingOrder {
            let currencyPair: CurrencyPair
            let uuid: UUID
            let date: Date
            let action: Action
            let price: Price
            let volume: Volume
        }
        /// A BUY order in a market's order book.
        public struct BuyOrder {
            let price: Price
            let volume: Volume
        }
        /// A SELL order in a market's order book.
        public struct SellOrder {
            let price: Price
            let volume: Volume
        }
        /// BUY and SELL orders for the market defined by `currencyPair`.
        public struct OrderBook {
            let currencyPair: CurrencyPair
            let buys: [BuyOrder]
            let sells: [SellOrder]
        }
        /// Current balance of `currency` for the account.
        public struct Balance {
            let currency: Currency
            let balance: Volume
        }
        /// A historical order that was updated or filled on `date`.
        public struct PastOrder {
            let date: Date
            let action: Action
            let price: Price
            let volume: Volume
        }
        /// All historical orders for the market defined by `currencyPair`.
        public struct PastOrders {
            let currencyPair: CurrencyPair
            let pastOrders: [PastOrder]
        }
        /// A pair of cryptographic keys identifying an account. To generate and manage keys, see https://tradeogre.com/help/api and https://tradeogre.com/account/settings
        public struct APIKeys {
            let `public`: String
            let `private`: String
        }
        
        /// Shared helper result struct.
        private struct MarketResult : Codable {
            let initialprice: String
            let price: String
            let high: String
            let low: String
            let volume: String
            let bid: String
            let ask: String
            var asMarketData: MarketData {
                return MarketData(initialprice: self.initialprice.asPrice,
                                  price: self.price.asPrice,
                                  high: self.high.asPrice,
                                  low: self.low.asPrice,
                                  volume: self.volume.asVolume,
                                  bid: self.bid.asPrice,
                                  ask: self.ask.asPrice)
            }
        }
        
        /// Base HTTP URL for V1 API calls.
        private static let baseURL = URL(string: "https://tradeogre.com/api/v1")!
        fileprivate let urlSession: URLSession
        fileprivate(set) public var account: Account?
        fileprivate(set) public var order: Order?
        
        init(urlSession: URLSession = .shared, credentials: APIKeys? = nil) {
            self.urlSession = urlSession
            if let keys = credentials {
                _ = authenticate(credentials: keys)
            }
        }
        
        /// Authenticate this client with the given `credentials`.
        func authenticate(credentials: APIKeys) -> Self {
            self.account = Account(credentials: credentials, urlSession: self.urlSession)
            self.order = Order(credentials: credentials, urlSession: self.urlSession)
            return self
        }
        
        /// Remove account-level access for this client.
        func unauthenticate() -> Self {
            self.account = nil
            self.order = nil
            return self
        }
        
        /// Helper for appending URL components.
        fileprivate static func url(for exts: String...) -> URL {
            return exts.reduce(self.baseURL) { (url, ext) -> URL in
                url.appendingPathComponent(ext)
            }
        }
        
        /// Helper for URL request responses, decoding data and wrapping errors.
        fileprivate static func handleResponse<T: Decodable>(_ dataOrNil: Data?, _ responseOrNil: URLResponse?, _ errorOrNil: Error?) -> Result<T, TradeOgreError> {
            if let urlError = errorOrNil as? URLError {
                return .failure(.serverError(urlError))
            }
            else if let error = errorOrNil {
                return .failure(.miscError(error))
            }
            else if let response = responseOrNil as? HTTPURLResponse {
                guard response.statusCode == 200 else {
                    return .failure(.serverError(.init(URLError.Code.badServerResponse)))
                }
                guard let data = dataOrNil else {
                    return .failure(.serverError(.init(URLError.Code.badServerResponse)))
                }
                do {
                    return .success(try JSONDecoder().decode(T.self, from: data))
                }
                catch let err {
                    return .failure(.miscError(err))
                }
            }
            else {
                return .failure(.unknownError("Request did not yield an error, but did not provide a HTTPURLResponse object."))
            }
        }
        
        /// Helper to kick off a request and convert that URL request to a `Future`.
        fileprivate static func request<ResultType: Decodable>(url: URL, urlSession: URLSession = .shared) -> Future<ResultType, TradeOgreError> {
            return Future { promise in
                urlSession.dataTask(with: url) { dataOrNil, responseOrNil, errorOrNil in
                    promise(self.handleResponse(dataOrNil, responseOrNil, errorOrNil))
                }
            }
        }
        
        /// Helper to kick off a request, map the received data to a more usable format, and convert that request to a `Future`.
        fileprivate static func request<ServerType: Decodable, ResultType>(url: URL, urlSession: URLSession = .shared, transform: @escaping (ServerType) -> ResultType) -> Future<ResultType, TradeOgreError> {
            return Future { promise in
                urlSession.dataTask(with: url) { dataOrNil, responseOrNil, errorOrNil in
                    let result: Result<ServerType, TradeOgreError> = self.handleResponse(dataOrNil, responseOrNil, errorOrNil)
                    switch result {
                    case .success(let serverResult):
                        promise(.success(transform(serverResult)))
                    case .failure(let error):
                        promise(.failure(error))
                    }
                }
                .resume()
            }
        }
        
        /// Retrieve a listing of all markets and basic information including current price, volume, high, low, bid and ask.
        public static func markets(urlSession: URLSession = .shared) -> Future<[Market], TradeOgreError> {
            let marketsURL = self.url(for: "markets")
            return self.request(url: marketsURL, urlSession: urlSession) { (marketEntries: [[String : MarketResult]]) -> [Market] in
                return marketEntries.flatMap { (elem: [String : MarketResult]) -> [Market] in
                    return elem.compactMap { (kv) -> Market? in
                        let (key, value) = kv
                        guard let curPair = CurrencyPair(key: key) else { return nil }
                        return Market(currencyPair: curPair,
                                      marketData: value.asMarketData)
                    }
                }
            }
        }
        
        /// Retrieve a listing of all markets and basic information including current price, volume, high, low, bid and ask.
        public func markets() -> Future<[Market], TradeOgreError> {
            return V1.markets(urlSession: self.urlSession)
        }
        
        /// Retrieve the ticker for `currencyPair`, volume, high, and low are in the last 24 hours, initialprice is the price from 24 hours ago.
        public static func ticker(currencyPair: CurrencyPair, urlSession: URLSession = .shared) -> Future<Market, TradeOgreError> {
            let tickerURL = self.url(for: "ticker", currencyPair.asString)
            return self.request(url: tickerURL, urlSession: urlSession) { (marketResult: MarketResult) -> Market in
                .init(currencyPair: currencyPair, marketData: marketResult.asMarketData)
            }
        }
        
        /// Retrieve the ticker for `currencyPair`, volume, high, and low are in the last 24 hours, initialprice is the price from 24 hours ago.
        public func ticker(currencyPair: CurrencyPair) -> Future<Market, TradeOgreError> {
            return V1.ticker(currencyPair: currencyPair, urlSession: self.urlSession)
        }
        
        /// Retrieve the current order book for `currencyPair` such as BTC-XMR.
        public static func orders(currencyPair: CurrencyPair, urlSession: URLSession = .shared) -> Future<OrderBook, TradeOgreError> {
            struct OrdersResult : Decodable {
                let success: String
                let buy: [String : String]
                let sell: [String : String]
            }
            let ordersURL = self.url(for: "orders", currencyPair.asString)
            return self.request(url: ordersURL, urlSession: urlSession) { (orderResults: OrdersResult) -> OrderBook in
                .init(currencyPair: currencyPair,
                    buys: orderResults.buy.map({ (p) -> BuyOrder in
                       let (k, v) = p
                       return BuyOrder(price: k.asPrice,
                                       volume: v.asVolume)
                    }),
                    sells: orderResults.sell.map({ (p) -> SellOrder in
                       let (k, v) = p
                       return SellOrder(price: k.asPrice,
                                        volume: v.asVolume)
                    }))
            }
        }
        
        /// Retrieve the current order book for `currencyPair` such as BTC-XMR.
        public func orders(currencyPair: CurrencyPair) -> Future<OrderBook, TradeOgreError> {
            return V1.orders(currencyPair: currencyPair, urlSession: self.urlSession)
        }
        
        /// Retrieve the history of the last trades on `currencyPair` limited to 100 of the most recent trades.
        public static func history(currencyPair: CurrencyPair, urlSession: URLSession = .shared) -> Future<PastOrders, TradeOgreError> {
            enum HistoryAction : String, Decodable {
                case buy
                case sell
                var asAction: Action {
                    switch self {
                    case .buy:
                        return .buy
                    case .sell:
                        return .sell
                    }
                }
            }
            struct HistoryResult : Decodable {
                let date: Int64
                let type: HistoryAction
                let price: String
                let quantity: String
            }
            let historyURL = self.url(for: "history", currencyPair.asString)
            return self.request(url: historyURL, urlSession: urlSession) { (history: [HistoryResult]) -> PastOrders in
                .init(currencyPair: currencyPair, pastOrders: history.map {
                        PastOrder(date: .init(timeIntervalSince1970: Double($0.date)), action: $0.type.asAction, price: $0.price.asPrice, volume: $0.quantity.asVolume)
                    })
            }
        }
        
        /// Retrieve the history of the last trades on `currencyPair` limited to 100 of the most recent trades.
        public func history(currencyPair: CurrencyPair) -> Future<PastOrders, TradeOgreError> {
            return V1.history(currencyPair: currencyPair, urlSession: self.urlSession)
        }
        
        /// Sub-object to interact with account-scoped authenticated API endpoints.
        public class Account {
            fileprivate let credentials: APIKeys
            fileprivate let urlSession: URLSession
            fileprivate init(credentials: APIKeys, urlSession: URLSession = .shared) {
                self.credentials = credentials
                self.urlSession = urlSession
            }
            
            fileprivate static func url(for exts: String...) -> URL {
                return exts.reduce(V1.url(for: "account")) { (url, ext) -> URL in
                    url.appendingPathComponent(ext)
                }
            }
            
            @discardableResult fileprivate static func applyAPIKeys(apiKeys: APIKeys, to request: URLRequest) -> URLRequest {
                var req = request
                let unpw = "\(apiKeys.public):\(apiKeys.private)"
                let unpwd = unpw.data(using: .utf8)!
                let unpwde = unpwd.base64EncodedString()
                req.addValue("Basic \(unpwde)",
                                 forHTTPHeaderField: "Authorization")
                return req
            }
            
            /// Retrieve all balances for your account.
            public static func balances(credentials: APIKeys, urlSession: URLSession = .shared) -> Future<[Balance], TradeOgreError> {
                struct BalancesResult : Decodable {
                    let success: Bool
                    let balances: [String : String]
                }
                let balancesURL = self.url(for: "balances")
                var balancesRequest = URLRequest(url: balancesURL)
                balancesRequest.httpMethod = "GET"
                balancesRequest = self.applyAPIKeys(apiKeys: credentials, to: balancesRequest)
                return Future { promise in
                    urlSession.dataTask(with: balancesRequest) { dataOrNil, responseOrNil, errorOrNil in
                        let result: Result<BalancesResult, TradeOgreError> = V1.handleResponse(dataOrNil, responseOrNil, errorOrNil)
                        switch result {
                        case .success(let balancesResult):
                            promise(.success(balancesResult.balances.compactMap { (p) -> Balance? in
                                let (key, value) = p
                                let v = value.asVolume
                                guard v >= 0.0000001 else { return nil }
                                return Balance(currency: Currency(key),
                                               balance: v)
                            }))
                        case .failure(let error):
                            promise(.failure(error))
                        }
                    }
                    .resume()
                }
            }
            
            /// Retrieve all balances for your account.
            public func balances() -> Future<[Balance], TradeOgreError> {
                return Account.balances(credentials: self.credentials, urlSession: self.urlSession)
            }
            
            /// Get the balance of a specific currency for you account. The total balance is returned and the available balance is what can be used in orders or withdrawn.
            public static func balance(for currency: Currency, credentials: APIKeys, urlSession: URLSession = .shared) -> Future<Balance, TradeOgreError> {
                struct BalanceResult : Decodable {
                    let success: Bool
                    let balance: String
                    let available: String
                }
                let balanceURL = self.url(for: "balance")
                var balanceRequest = URLRequest(url: balanceURL)
                balanceRequest.httpMethod = "POST"
                balanceRequest.httpBody = "currency=\(currency)".data(using: .ascii)
                balanceRequest = self.applyAPIKeys(apiKeys: credentials, to: balanceRequest)
                return Future { promise in
                    urlSession.dataTask(with: balanceRequest) { dataOrNil, responseOrNil, errorOrNil in
                        let result: Result<BalanceResult, TradeOgreError> = V1.handleResponse(dataOrNil, responseOrNil, errorOrNil)
                        switch result {
                        case .success(let balanceResult):
                            promise(.success(.init(currency: currency, balance: balanceResult.balance.asVolume)))
                        case .failure(let error):
                            promise(.failure(error))
                        }
                    }
                    .resume()
                }
            }
            
            /// Get the balance of a specific currency for you account. The total balance is returned and the available balance is what can be used in orders or withdrawn.
            public func balance(for currency: Currency) -> Future<Balance, TradeOgreError> {
                return Account.balance(for: currency, credentials: self.credentials, urlSession: self.urlSession)
            }
            
            /// Retrieve the active orders under your account.
            public static func orders(for market: CurrencyPair? = nil, credentials: APIKeys, urlSession: URLSession = .shared) -> Future<[PendingOrder], TradeOgreError> {
                struct OrdersResult : Decodable {
                    let market: String
                    let uuid: String
                    let date: Int64
                    let type: String
                    let price: String
                    let quantity: String
                }
                let ordersURL = self.url(for: "orders")
                var ordersRequest = URLRequest(url: ordersURL)
                ordersRequest.httpMethod = "POST"
                if let market = market {
                    ordersRequest.httpBody = "market=\(market.asString)".data(using: .ascii)
                }
                ordersRequest = self.applyAPIKeys(apiKeys: credentials, to: ordersRequest)
                return Future { promise in
                    urlSession.dataTask(with: ordersRequest) { dataOrNil, responseOrNil, errorOrNil in
                        let result: Result<[OrdersResult], TradeOgreError> = V1.handleResponse(dataOrNil, responseOrNil, errorOrNil)
                        switch result {
                        case .success(let ordersResults):
                            let pendingOrders = ordersResults.compactMap { ordersResult -> PendingOrder? in
                                guard let curPair = CurrencyPair(key: ordersResult.market),
                                    let uuid = UUID(uuidString: ordersResult.uuid)
                                else {
                                    return nil
                                }
                                return PendingOrder(currencyPair: curPair,
                                                    uuid: uuid,
                                                    date: .init(timeIntervalSince1970: Double(ordersResult.date)),
                                                    action: ordersResult.type == "buy" ? .buy : .sell,
                                                    price: ordersResult.price.asPrice,
                                                    volume: ordersResult.quantity.asVolume)
                            }
                            promise(.success(pendingOrders))
                        case .failure(let error):
                            promise(.failure(error))
                        }
                    }
                    .resume()
                }
            }
            
            /// Retrieve the active orders under your account.
            public func orders(for market: CurrencyPair? = nil) -> Future<[PendingOrder], TradeOgreError> {
                return Account.orders(for: market, credentials: self.credentials, urlSession: self.urlSession)
            }
        }
        
        /// Sub-object to interact with order-scoped authenticated API endpoints.
        public class Order {
            fileprivate let credentials: APIKeys
            fileprivate let urlSession: URLSession
            fileprivate init(credentials: APIKeys, urlSession: URLSession = .shared) {
                self.credentials = credentials
                self.urlSession = urlSession
            }
            
            fileprivate static func url(for exts: String...) -> URL {
                return exts.reduce(V1.url(for: "order")) { (url, ext) -> URL in
                    url.appendingPathComponent(ext)
                }
            }
            
            @discardableResult fileprivate static func applyAPIKeys(apiKeys: APIKeys, to request: URLRequest) -> URLRequest {
                var req = request
                let unpw = "\(apiKeys.public):\(apiKeys.private)"
                let unpwd = unpw.data(using: .utf8)!
                let unpwde = unpwd.base64EncodedString()
                req.addValue("Basic \(unpwde)",
                                 forHTTPHeaderField: "Authorization")
                return req
            }
            
            private static func string(price: Price) -> String {
                let fmt = NumberFormatter()
                fmt.minimumSignificantDigits = 2
                fmt.maximumSignificantDigits = 12
                return fmt.string(for: price) ?? "0.0"
            }
            
            private static func string(volume: Volume) -> String {
                return self.string(price: volume)
            }
            
            private static func string(uuid: UUID) -> String {
                return uuid.uuidString.lowercased()
            }
            
            /// Submit a buy order to the order book for a market. If your order is successful but not fully fulfilled, the order is placed onto the order book and you will receive a uuid for the order.
            public static func buy(market: CurrencyPair, quantity: Volume, price: Price, credentials: APIKeys, urlSession: URLSession = .shared) -> Future<UUID, TradeOgreError> {
                struct BuyResult : Decodable {
                    let success: Bool
                    let uuid: String
                    let bnewbalavail: String
                    let snewbalavail: String
                }
                let buyURL = self.url(for: "buy")
                var buyRequest = URLRequest(url: buyURL)
                buyRequest.httpMethod = "POST"
                buyRequest.httpBody = "market=\(market.asString)&quantity=\(self.string(volume: quantity))&price=\(self.string(price: price))".data(using: .utf8)
                buyRequest = self.applyAPIKeys(apiKeys: credentials, to: buyRequest)
                return Future { promise in
                    urlSession.dataTask(with: buyRequest) { dataOrNil, responseOrNil, errorOrNil in
                        let result: Result<BuyResult, TradeOgreError> = V1.handleResponse(dataOrNil, responseOrNil, errorOrNil)
                        switch result {
                        case .success(let buyResult):
                            if let uuid = UUID(uuidString: buyResult.uuid) {
                                promise(.success(uuid))
                            }
                            else {
                                promise(.failure(TradeOgreError.unknownError("Could not process provided UUID")))
                            }
                        case .failure(let error):
                            promise(.failure(error))
                        }
                    }
                    .resume()
                }
            }
            
            /// Submit a buy order to the order book for a market. If your order is successful but not fully fulfilled, the order is placed onto the order book and you will receive a uuid for the order.
            public func buy(market: CurrencyPair, quantity: Volume, price: Price) -> Future<UUID, TradeOgreError> {
                return Order.buy(market: market, quantity: quantity, price: price, credentials: self.credentials, urlSession: self.urlSession)
            }
            
            /// Submit a sell order to the order book for a market. If your order is successful but not fully fulfilled, the order is placed onto the order book and you will receive a uuid for the order.
            public static func sell(market: CurrencyPair, quantity: Volume, price: Price, credentials: APIKeys, urlSession: URLSession = .shared) -> Future<UUID, TradeOgreError> {
                struct SellResult : Decodable {
                    let success: Bool
                    let uuid: String
                    let bnewbalavail: String
                    let snewbalavail: String
                }
                let sellURL = self.url(for: "sell")
                var sellRequest = URLRequest(url: sellURL)
                sellRequest.httpMethod = "POST"
                sellRequest.httpBody = "market=\(market.asString)&quantity=\(self.string(volume: quantity))&price=\(self.string(price: price))".data(using: .utf8)
                sellRequest = self.applyAPIKeys(apiKeys: credentials, to: sellRequest)
                return Future { promise in
                    urlSession.dataTask(with: sellRequest) { dataOrNil, responseOrNil, errorOrNil in
                        let result: Result<SellResult, TradeOgreError> = V1.handleResponse(dataOrNil, responseOrNil, errorOrNil)
                        switch result {
                        case .success(let buyResult):
                            if let uuid = UUID(uuidString: buyResult.uuid) {
                                promise(.success(uuid))
                            }
                            else {
                                promise(.failure(TradeOgreError.unknownError("Could not process provided UUID")))
                            }
                        case .failure(let error):
                            promise(.failure(error))
                        }
                    }
                    .resume()
                }
            }
            
            /// Submit a sell order to the order book for a market. If your order is successful but not fully fulfilled, the order is placed onto the order book and you will receive a uuid for the order.
            public func sell(market: CurrencyPair, quantity: Volume, price: Price) -> Future<UUID, TradeOgreError> {
                return Order.sell(market: market, quantity: quantity, price: price, credentials: self.credentials, urlSession: self.urlSession)
            }
            
            /// Cancel an order on the order book based on the order uuid.
            public static func cancel(uuid: UUID, credentials: APIKeys, urlSession: URLSession = .shared) -> Future<(), TradeOgreError> {
                struct CancelResult : Decodable {
                    let success: Bool
                }
                let cancelURL = self.url(for: "cancel")
                var cancelRequest = URLRequest(url: cancelURL)
                cancelRequest.httpMethod = "POST"
                cancelRequest.httpBody = "uuid=\(self.string(uuid: uuid))".data(using: .utf8)
                cancelRequest = self.applyAPIKeys(apiKeys: credentials, to: cancelRequest)
                return Future { promise in
                    urlSession.dataTask(with: cancelRequest) { dataOrNil, responseOrNil, errorOrNil in
                        let result: Result<CancelResult, TradeOgreError> = V1.handleResponse(dataOrNil, responseOrNil, errorOrNil)
                        switch result {
                        case .success(let cancelResult):
                            if cancelResult.success {
                                promise(.success(()))
                            }
                            else {
                                promise(.failure(.unknownError("Probably Order Not Found...")))
                            }
                        case .failure(let error):
                            promise(.failure(error))
                        }
                    }
                    .resume()
                }
            }
            
            /// Cancel an order on the order book based on the order uuid.
            public func cancel(uuid: UUID) -> Future<(), TradeOgreError> {
                return Order.cancel(uuid: uuid, credentials: self.credentials, urlSession: self.urlSession)
            }
        }
    }
}
