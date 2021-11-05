//
//  AuthedMarketDetailsViewController.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 10/30/21.
//

import Combine
import UIKit

protocol AuthedMarketDetailsStateType {
    var balancesPublisher: AnyPublisher<(base: Double, other: Double), AppError> { get }
    var ordersPublisher: AnyPublisher<[PendingOrder], AppError> { get }
}

protocol AuthedMarketDetailsEndpointType {
    func submitOrder(currencyPair: CurrencyPair, action: Action, price: Double, volume: Double) -> AnyPublisher<(), AppError>
}

class AuthedMarketDetailsViewController : MarketDetailsViewController, TradeEndpointType {
    @IBOutlet weak var otherBalanceLabel: UILabel!
    @IBOutlet weak var baseBalanceLabel: UILabel!
    
    var authedState: AuthedMarketDetailsStateType!
    var authedEndpoint: AuthedMarketDetailsEndpointType!
    
    var authedRefreshController: PeriodicRefreshController<((base: Double, other: Double), [PendingOrder])>?
    
    var balancesSub: AnyCancellable?
    var ordersSub: AnyCancellable?
    var lifecycleSub: AnyCancellable?
    
    override func didBecomeActive() {
        super.didBecomeActive()
        
        self.authedRefreshController =
            PeriodicRefreshController<((base: Double, other: Double), [PendingOrder])>(refreshInterval: 60.0, viewLifecycleStream: self.viewLifecycleStream, dataStream: Publishers.Zip(self.authedState.balancesPublisher, self.authedState.ordersPublisher).asAny, block: { (result) in
                let (balances, orders) = result
                MainThread.run {
                    self.display(baseBalance: balances.base,
                                 otherBalance: balances.other)
                    self.detailTableView.myOrders = orders
                }
            })
    }
    
    func display(baseBalance: Double, otherBalance: Double) {
        self.otherBalanceLabel.text = "\(Style.Text.volume(otherBalance)) \(self.state.market.currencyPair.other)"
        self.baseBalanceLabel.text = "\(Style.Text.volume(baseBalance)) \(self.state.market.currencyPair.base)"
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        struct TradeState : TradeStateType {
            var currencyPair: CurrencyPair
            var balancesPublisher: AnyPublisher<(base: Double, other: Double), AppError>
        }
        
        let action: Action
        switch segue.identifier {
        case "Buy":
            action = .buy
        case "Sell":
            action = .sell
        default:
            super.prepare(for: segue, sender: sender)
            return
        }
        guard let tradeVC = segue.destination as? TradeViewController else {
            super.prepare(for: segue, sender: sender)
            return
        }
        tradeVC.action = action
        tradeVC.state = TradeState(currencyPair: self.state.market.currencyPair,
                                   balancesPublisher: self.authedState.balancesPublisher)
        tradeVC.endpoint = self
    }
    
    func done(_: TradeViewController) {
        self.dismiss(animated: true)
    }
    
    func submitOrder(currencyPair: CurrencyPair, action: Action, price: Double, volume: Double) -> AnyPublisher<(), AppError> {
        return self.authedEndpoint.submitOrder(currencyPair: currencyPair, action: action, price: price, volume: volume)
    }
}
