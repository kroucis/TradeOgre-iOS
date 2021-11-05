//
//  MarketDetailsViewController.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 10/27/21.
//

import Combine
import UIKit

extension TradeOgreAPI.Action {
    var textColor: UIColor {
        switch self {
        case .buy:
            return .systemGreen
        case .sell:
            return .systemRed
        }
    }
}

class DetailTableView : UITableView, UITableViewDataSource {
    enum Tab {
        case history
        case buys
        case sells
        case myOrders
        var cellID: String {
            switch self {
            case .history:
                return "HistoryCell"
            case .buys:
                return "BuyOrderCell"
            case .sells:
                return "SellOrderCell"
            case .myOrders:
                return "OrderCell"
            }
        }
    }
    
    var history: [PastOrder] = []
    var buys: [BuyOrder] = []
    var sells: [SellOrder] = []
    var myOrders: [PendingOrder] = []
    
    func setAll(history: [PastOrder], buys: [BuyOrder], sells: [SellOrder]) {
        self.history = history
        self.buys = buys
        self.sells = sells
        MainThread.run(self.reloadData)
    }

    var tab: Tab = .history {
        didSet {
            MainThread.run(self.reloadData)
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch self.tab {
        case .history:
            return self.history.count
        case .buys:
            return self.buys.count
        case .sells:
            return self.sells.count
        case .myOrders:
            return self.myOrders.count
        }
    }
    
    func data(for indexPath: IndexPath) -> (String, String, UIColor?) {
        switch self.tab {
        case .history:
            let entry = self.history[indexPath.row]
            return (entry.action == .buy ? TradeOgre.Style.Text.buy(volume: entry.volume) : TradeOgre.Style.Text.sell(volume: entry.volume), TradeOgre.Style.Text.price(entry.price), entry.action.textColor)
        case .buys:
            let entry = self.buys[indexPath.row]
            return (TradeOgre.Style.Text.volume(entry.volume), TradeOgre.Style.Text.price(entry.price), nil)
        case .sells:
            let entry = self.sells[indexPath.row]
            return (TradeOgre.Style.Text.volume(entry.volume), TradeOgre.Style.Text.price(entry.price), nil)
        case .myOrders:
            let entry = self.myOrders[indexPath.row]
            return (entry.action == .buy ? TradeOgre.Style.Text.buy(volume: entry.volume) : TradeOgre.Style.Text.sell(volume: entry.volume), TradeOgre.Style.Text.price(entry.price), entry.action.textColor)
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = self.dequeueReusableCell(withIdentifier: self.tab.cellID) as? DetailTableViewCell else {
            return UITableViewCell()
        }
        cell.display(data: self.data(for: indexPath))
        return cell
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.dataSource = self
    }
}

class DetailTableViewCell : UITableViewCell {
    func display(data: (String, String, UIColor?)) {
        self.textLabel?.text = data.0
        self.detailTextLabel?.text = data.1
        if let textColor = data.2 {
            self.textLabel?.textColor = textColor
        }
    }
}

protocol MarketDetailsStateType {
    var market: Market { get }
    var marketDetailsPublisher: AnyPublisher<MarketDetails, AppError> { get }
}

protocol MarketDetailsEndpointType {
    func routeToLogin()
}

class MarketDetailsViewController : ViewController {
    private static let refreshInterval = 5.0
    
    @IBOutlet weak var baseLabel: UILabel!
    @IBOutlet weak var otherLabel: UILabel!
    @IBOutlet weak var deltaLabel: UILabel!
    
    @IBOutlet weak var currentPriceLabel: UILabel!
    @IBOutlet weak var changeLabel: UILabel!
    @IBOutlet weak var volumeLabel: UILabel!
    @IBOutlet weak var highLabel: UILabel!
    @IBOutlet weak var lowLabel: UILabel!
    
    @IBOutlet weak var detailTableView: DetailTableView!
    
    var state: MarketDetailsStateType!
    var endpoint: MarketDetailsEndpointType!
    
    var refreshController: PeriodicRefreshController<MarketDetails>?
    
    private var detailsSub: AnyCancellable?
    
    private var tickerRequest: AnyCancellable?
    private var ordersRequest: AnyCancellable?
    private var baseRequest: AnyCancellable?
    private var otherRequest: AnyCancellable?
    private var historyRequest: AnyCancellable?
    private var loggedInCancellable: AnyCancellable?
    
    private var refreshCancellable: AnyCancellable?
    
    override func didBecomeActive() {
        self.title = self.state.market.currencyPair.asString
        self.baseLabel?.text = self.state.market.currencyPair.base
        self.otherLabel?.text = self.state.market.currencyPair.other
        self.display(marketData: self.state.market.marketData)
        self.detailTableView?.tab = .history
        
        self.refreshController = .init(refreshInterval: 3.0, viewLifecycleStream: self.viewLifecycleStream, dataStream: self.state.marketDetailsPublisher) { (marketDetails) in
            MainThread.run { self.display(marketData: marketDetails.market.marketData) }
            self.detailTableView.setAll(history: marketDetails.history,
                                        buys: marketDetails.buys,
                                        sells: marketDetails.sells)
        }
    }
    
    func display(marketData: TradeOgreAPI.V1.MarketData) {
        let deltaPercent = marketData.priceDeltaPercent
        self.deltaLabel?.text = Style.Text.percent(deltaPercent)
        self.deltaLabel?.textColor = Style.Color.percent(deltaPercent)
        
        self.currentPriceLabel?.text = Style.Text.price(marketData.price)
        self.changeLabel?.text = Style.Text.price(marketData.priceDelta)
        self.volumeLabel?.text = Style.Text.volume(marketData.volume)
        self.highLabel?.text = Style.Text.price(marketData.high)
        self.lowLabel?.text = Style.Text.price(marketData.low)
    }
    
    @IBAction func detailsTabChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            self.detailTableView?.tab = .history
        case 1:
            self.detailTableView?.tab = .buys
        case 2:
            self.detailTableView?.tab = .sells
        case 3:
            self.detailTableView?.tab = .myOrders
        default:
            self.detailTableView?.tab = .history
        }
    }
    
    @IBAction func loginToTrade(_ sender: Any) {
        self.endpoint.routeToLogin()
    }
}
