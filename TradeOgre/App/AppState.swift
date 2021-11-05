//
//  AppState.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 10/28/21.
//

import Combine
import Foundation

typealias Currency = TradeOgreAPI.Currency
typealias CurrencyPair = TradeOgreAPI.CurrencyPair
typealias Market = TradeOgreAPI.V1.Market
typealias ExchangeMarket = (Currency, [Market])
typealias Balance = TradeOgreAPI.V1.Balance
typealias PastOrder = TradeOgreAPI.V1.PastOrder
typealias BuyOrder = TradeOgreAPI.V1.BuyOrder
typealias SellOrder = TradeOgreAPI.V1.SellOrder
typealias PendingOrder = TradeOgreAPI.V1.PendingOrder
enum Action {
    case buy
    case sell
}
struct MarketDetails {
    let market: Market
    let history: [PastOrder]
    let buys: [BuyOrder]
    let sells: [SellOrder]
}

enum AppError : Error {
    case miscError(Error)
    case apiError(TradeOgreAPI.TradeOgreError)
    case authenticationError
    case notAuthenticated
}

class Tips {
    class XMR {
        class iOS {
            static let address = "87pYWFvyhmrWdw2EFekpZaZJf4tm758maJAigzkPmd9tD8ou3VByDMuG1DpsFcmTBzZrafk38kLv71wX5sfpX2ri7Zbym1P"
            static let amount = 0.01
        }
        
        class Android {
            static let amount = 0.02
            static let address = "89sA2PuDuYyDvrozNKynxaYDPdkvLUbfbbBQHUaa3dPMbYKkXLWqgGvFsubenscmfE95uv6G9nVha4yskG5h9bef8ptFJLu"
        }
    }
}

/// Root state for the TradeOgre application.
class AppState {
    let keychain = Keychain(service: "TradeOgre")
    var apiKeys: TradeOgreAPI.V1.APIKeys? {
        get {
            guard let str = self.keychain.passwordString(key: "apiKey") else {
                return nil
            }
            let split = str.split(separator: ":")
            guard split.count == 2 else { return nil }
            let pub = String(split[0])
            let priv = String(split[1])
            guard !(pub.isEmpty), !(priv.isEmpty) else { return nil }
            return TradeOgreAPI.V1.APIKeys(public: pub, private: priv)
        }
        set {
            if let keys = newValue {
                self.keychain.set(passwordString: "\(keys.public):\(keys.private)", key: "apiKey")
            }
            else {
                self.keychain.set(passwordString: nil, key: "apiKey")
            }
        }
    }
    
    fileprivate enum State {
        case unauthenticated(Client.Unauthenticated)
        case authenticating(Client.Unauthenticated, Future<Bool, AppError>)
        case locked(Client.Authenticated)
        case unlocked(Client.Authenticated)
    }
    
    fileprivate enum ClientState {
        case unauthenticated(Client.Unauthenticated)
        case authenticating(Client.Unauthenticated, Future<Bool, AppError>)
        case authenticated(Client.Authenticated)
    }
    
    // TODO: Migrate to State instead of ClientState to allow for locking and unlocking using PIN
    //       and/or TouchID/FaceID.
//    fileprivate var state: State {
//        didSet {
//            switch self.state {
//            case .unauthenticated,
//                 .authenticating:
//                self.loggedInSubject.value = false
//            case .locked,
//                 .unlocked:
//                self.loggedInSubject.value = true
//            }
//        }
//    }
    
    fileprivate var clientState: ClientState {
        didSet {
            switch self.clientState {
            case .unauthenticated,
                 .authenticating:
                self.isLoggedIn = false
            case .authenticated:
                self.isLoggedIn = true
            }
        }
    }
    @Published var isLoggedIn: Bool
    
    var appVersion: (String, String) {
        let info = Bundle.main.infoDictionary
        return ((info?["CFBundleShortVersionString"] as? String) ?? "???", (info?["CFBundleVersion"] as? String) ?? "???")
    }
    
    init() {
        self.clientState = .unauthenticated(.init(urlSession: .shared))
        self.isLoggedIn = false
        if let keys = self.apiKeys {
            self.clientState = .authenticated(.init(urlSession: .shared, credentials: keys))
            self.isLoggedIn = true
        }
    }
    
    func login(public: String, private: String) -> Future<(), AppError> {
        let credentials = TradeOgreAPI.V1.APIKeys(public: `public`, private: `private`)
        return Future { promise in
            switch self.clientState {
            case .unauthenticated(let unauthed):
                // TODO: Skip "authenticating" state for now
                self.apiKeys = credentials
                if self.apiKeys != nil {
                    self.clientState = .authenticated(unauthed.authenticate(credentials: credentials))
                    promise(.success(()))
                }
                else {
                    promise(.failure(.authenticationError))
                }
            case .authenticating(let unauthed, _):
                // TODO: Skip "authenticating" state for now
                self.clientState = .authenticated(unauthed.authenticate(credentials: credentials))
                promise(.success(()))
            case .authenticated(_):
                promise(.failure(.authenticationError))
            }
        }
    }
    
    func logOut() -> Future<(), AppError> {
        return Future { promise in
            switch self.clientState {
            case .unauthenticated:
                promise(.success(()))
            case .authenticating(let unauthed, _):
                self.clientState = .unauthenticated(unauthed)
                promise(.success(()))
            case .authenticated(let authed):
                self.apiKeys = nil
                self.clientState = .unauthenticated(authed.unauthenticate())
                promise(.success(()))
            }
        }
    }
}

extension AppState : MarketsStateType {
    var marketsPublisher: AnyPublisher<[ExchangeMarket], AppError> {
        switch self.clientState {
        case .unauthenticated(let unauthed):
            return unauthed.marketsPublisher
        case .authenticating(let unauthed, _):
            return unauthed.marketsPublisher
        case .authenticated(let authed):
            return authed.marketsPublisher
        }
    }
    
    func marketDetailsPublisher(for currencyPair: CurrencyPair) -> AnyPublisher<MarketDetails, AppError> {
        switch self.clientState {
        case .unauthenticated(let unauthed):
            return unauthed.marketDetailsPublisher(for: currencyPair)
        case .authenticating(let unauthed, _):
            return unauthed.marketDetailsPublisher(for: currencyPair)
        case .authenticated(let authed):
            return authed.marketDetailsPublisher(for: currencyPair)
        }
    }
}

extension AppState : AuthedMarketsStateType {
    func balancesPublisher(for currencyPair: CurrencyPair) -> AnyPublisher<(base: Double, other: Double), AppError> {
        switch self.clientState {
        case .unauthenticated,
             .authenticating:
            return Fail(error: AppError.notAuthenticated).eraseToAnyPublisher()
        case .authenticated(let authed):
            return authed.balancesPublisher(for: currencyPair)
        }
    }
    
    func ordersPublisher(for currencyPair: CurrencyPair) -> AnyPublisher<[PendingOrder], AppError> {
        switch self.clientState {
        case .unauthenticated,
             .authenticating:
            return Fail(error: AppError.notAuthenticated).eraseToAnyPublisher()
        case .authenticated(let authed):
            return authed.ordersPublisher(for: currencyPair)
        }
    }
}

extension AppState : PortfolioStateType {
    var balancesPublisher: AnyPublisher<[Balance], AppError> {
        switch self.clientState {
        case .unauthenticated,
             .authenticating:
            return Fail(error: AppError.notAuthenticated).eraseToAnyPublisher()
        case .authenticated(let authed):
            return authed.balancesPublisher
        }
    }
}


extension AppState : OrdersStateType {
    var ordersPublisher: AnyPublisher<[PendingOrder], AppError> {
        switch self.clientState {
        case .unauthenticated,
             .authenticating:
            return Fail(error: AppError.notAuthenticated).eraseToAnyPublisher()
        case .authenticated(let authed):
            return authed.ordersPublisher
        }
    }
}

extension AppState : AuthedMarketsEndpointType {
    // TODO: Change result to Future<(), AppError> instead of AnyPublisher
    func submitOrder(currencyPair: CurrencyPair, action: Action, price: Double, volume: Double) -> AnyPublisher<(), AppError> {
        switch self.clientState {
        case .unauthenticated,
             .authenticating:
            return Fail(error: AppError.notAuthenticated).eraseToAnyPublisher()
        case .authenticated(let authed):
            switch action {
            case .buy:
                return authed.buy(currencyPair: currencyPair, quantity: volume, price: price)
            case .sell:
                return authed.sell(currencyPair: currencyPair, quantity: volume, price: price)
            }
        }
    }
}

extension AppState : OrdersEndpointType {
    func cancel(pendingOrder: UUID) -> AnyPublisher<(), AppError> {
        switch self.clientState {
        case .unauthenticated,
             .authenticating:
            return Fail(error: AppError.notAuthenticated).eraseToAnyPublisher()
        case .authenticated(let authed):
            return authed.cancel(orderUUID: pendingOrder)
        }
    }
}
