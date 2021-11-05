//
//  MarketsViewController.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 10/27/21.
//

import UIKit
import Combine

protocol AuthedMarketsStateType {
    func balancesPublisher(for: CurrencyPair) -> AnyPublisher<(base: Double, other: Double), AppError>
    func ordersPublisher(for: CurrencyPair) -> AnyPublisher<[PendingOrder], AppError>
}

protocol AuthedMarketsEndpointType : AuthedMarketDetailsEndpointType {
    
}

class AuthedMarketsViewController : MarketsViewController {
    var authedState: AuthedMarketsStateType!
    var authedEndpoint: AuthedMarketsEndpointType!
    
    override func didBecomeActive() {
        super.didBecomeActive()
    }
    
    override func prepare(marketDetailsSegue: UIStoryboardSegue, data: Any?) {
        struct AuthedMarketDetailsState : AuthedMarketDetailsStateType {
            var balancesPublisher: AnyPublisher<(base: Double, other: Double), AppError>
            var ordersPublisher: AnyPublisher<[PendingOrder], AppError>
        }
        if let marketDetailsVC = marketDetailsSegue.destination as? AuthedMarketDetailsViewController,
            let market = data as? Market {
            marketDetailsVC.authedState = AuthedMarketDetailsState(balancesPublisher: self.authedState.balancesPublisher(for: market.currencyPair),
                                                                   ordersPublisher: self.authedState.ordersPublisher(for: market.currencyPair))
            marketDetailsVC.authedEndpoint = self.authedEndpoint
        }
        super.prepare(marketDetailsSegue: marketDetailsSegue, data: data)
    }
}

