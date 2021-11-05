//
//  Client.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 11/1/21.
//

import Combine
import Foundation

/// Wrapper for TradeOgreAPI client to provide a more FRP-friendly interface.
class Client {
    fileprivate let client: TradeOgreAPI.V1
    init(urlSession: URLSession = .shared) {
        self.client = TradeOgreAPI.V1(urlSession: urlSession)
    }
    
    fileprivate init(client: TradeOgreAPI.V1) {
        self.client = client
    }
    
    /// Unauthenticated client, exposing only the endpoints that do not require API keys.
    class Unauthenticated : Client {
        /// Publisher providing information on all available markets with a volume > 0.0, coallesced by base currency, e.g. `[("BTC", [{"XMR", 0.002, 4.21}, ...])...]`.
        var marketsPublisher: AnyPublisher<[ExchangeMarket], AppError> {
            return
                self.client
                    .markets()
                    .mapError { AppError.apiError($0) }
                    .map { markets -> [ExchangeMarket] in
                        var m = [Currency : [Market]]()
                        for market in markets {
                            guard market.marketData.volume > 0.0 else { continue }
                            var l = m[market.currencyPair.base] ?? [ ]
                            l.append(market)
                            m[market.currencyPair.base] = l
                        }
                        return m.map { e in
                            let (cur, ms) = e
                            return (cur, ms)
                        }
                    }
                    .asAny
        }
        
        /// Publisher for aggregated market details for `currencyPair`.
        func marketDetailsPublisher(for currencyPair: CurrencyPair) -> AnyPublisher<MarketDetails, AppError> {
            return Publishers.Zip3(self.client.ticker(currencyPair: currencyPair),
                                   self.client.history(currencyPair: currencyPair),
                                   self.client.orders(currencyPair: currencyPair))
                            .mapError { AppError.apiError($0) }
                            .map { (ticker, history, orderBook) -> MarketDetails in
                                .init(market: ticker,
                                      history: history.pastOrders,
                                      buys: orderBook.buys,
                                      sells: orderBook.sells)
                            }
                            .asAny
        }
        
        /// Create an authenticated client with the same settings as `self`.
        func authenticate(credentials: TradeOgreAPI.V1.APIKeys) -> Authenticated {
            return Authenticated(client: self.client.authenticate(credentials: credentials))
        }
    }
    
    /// Authenticated client, exposing both unauthenticated endpoints as well as endpoints that require API keys.
    class Authenticated : Unauthenticated {
        convenience init(urlSession: URLSession = .shared, credentials: TradeOgreAPI.V1.APIKeys) {
            self.init(client: TradeOgreAPI.V1(urlSession: urlSession).authenticate(credentials: credentials))
        }
        
        /// Create a Publisher for the account's balances for `currencyPair`.
        func balancesPublisher(for currencyPair: CurrencyPair) -> AnyPublisher<(base: Double, other: Double), AppError> {
            guard let accountClient = self.client.account else {
                return Fail(error: AppError.notAuthenticated).eraseToAnyPublisher()
            }
            return Publishers.Zip(accountClient.balance(for: currencyPair.base),
                                  accountClient.balance(for: currencyPair.other))
                        .mapError { AppError.apiError($0) }
                        .map { baseBalance, otherBalance -> (base: Double, other: Double) in
                            return (base: baseBalance.balance, other: otherBalance.balance)
                        }
                        .asAny
        }
        
        /// Publisher for all account balances.
        var balancesPublisher: AnyPublisher<[Balance], AppError> {
            guard let accountClient = self.client.account else {
                return Fail(error: AppError.notAuthenticated).eraseToAnyPublisher()
            }
            return
                accountClient
                    .balances()
                    .mapError { AppError.apiError($0) }
                    .asAny
        }
        
        /// Publisher for all account orders
        var ordersPublisher: AnyPublisher<[PendingOrder], AppError> {
            guard let accountClient = self.client.account else {
                return Fail(error: AppError.notAuthenticated).eraseToAnyPublisher()
            }
            return
                accountClient
                    .orders()
                    .mapError { AppError.apiError($0) }
                    .asAny
        }
        
        /// Create a Publisher for the account's orders for `currencyPair`.
        func ordersPublisher(for currencyPair: CurrencyPair) -> AnyPublisher<[PendingOrder], AppError> {
            guard let accountClient = self.client.account else {
                return Fail(error: AppError.notAuthenticated).eraseToAnyPublisher()
            }            
            return
                accountClient
                    .orders(for: currencyPair)
                    .mapError { AppError.apiError($0) }
                    .asAny
        }
        
        /// Submit a `BUY` order in the `currencyPair` market, for `quantity` of `other` at `price` in `base`.
        func buy(currencyPair: CurrencyPair, quantity: Double, price: Double) -> AnyPublisher<(), AppError> {
            guard let orderClient = self.client.order else {
                return Fail(error: AppError.notAuthenticated).asAny
            }
            return orderClient.buy(market: currencyPair, quantity: quantity, price: price)
                .mapError { AppError.apiError($0) }
                .map { _ -> Void in return () }
                .asAny
        }
        
        /// Submit a `SELL` order in the `currencyPair` market, for `quantity` of `other` at `price` in `base`.
        func sell(currencyPair: CurrencyPair, quantity: Double, price: Double) -> AnyPublisher<(), AppError> {
            guard let orderClient = self.client.order else {
                return Fail(error: AppError.notAuthenticated).asAny
            }
            return orderClient.sell(market: currencyPair, quantity: quantity, price: price)
                .mapError { AppError.apiError($0) }
                .map { _ -> Void in return () }
                .asAny
        }
        
        /// Cancel the pending order with `orderUUID`.
        func cancel(orderUUID: UUID) -> AnyPublisher<(), AppError> {
            guard let orderClient = self.client.order else {
                return Fail(error: AppError.notAuthenticated).asAny
            }
            return orderClient.cancel(uuid: orderUUID)
                .mapError { AppError.apiError($0) }
                .map { _ -> Void in return () }
                .asAny
        }
        
        /// Create an unauthenticated client with the settings of `self`.
        func unauthenticate() -> Unauthenticated {
            return Unauthenticated(client: self.client)
        }
    }
}
