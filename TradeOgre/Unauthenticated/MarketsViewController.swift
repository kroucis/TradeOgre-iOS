//
//  MarketsViewController.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 10/27/21.
//

import UIKit
import Combine

class MarketsTableView : UITableView, UITableViewDataSource {
    private let reuseIdentifier = "MarketCell"
    var markets: [(TradeOgreAPI.Currency, [TradeOgreAPI.V1.Market])] = [] {
        didSet { MainThread.run(self.reloadData) }
    }
    
    func data(for indexPath: IndexPath) -> TradeOgreAPI.V1.Market {
        return self.markets[indexPath.section].1[indexPath.row]
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.markets.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "\(self.markets[section].0) (\(self.markets[section].1.count))"
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.markets[section].1.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = self.dequeueReusableCell(withIdentifier: self.reuseIdentifier) as? MarketCell else {
            return UITableViewCell()
        }
        let market = self.data(for: indexPath)
        cell.display(market: market)
        return cell
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.dataSource = self
    }
}

class MarketCell : UITableViewCell {
    @IBOutlet weak var otherLabel: UILabel!
    @IBOutlet weak var volumeLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var deltaLabel: UILabel!
    
    func display(market: TradeOgreAPI.V1.Market) {
        self.otherLabel.text = market.currencyPair.other
        let fmt = NumberFormatter()
        fmt.maximumFractionDigits = 12
        self.volumeLabel.text = "\(Style.Text.volume(market.marketData.volume)) \(market.currencyPair.other)"
        self.priceLabel.text = Style.Text.price(market.marketData.price)
        
        let deltaPercent = market.marketData.priceDeltaPercent
        
        self.deltaLabel.textColor = Style.Color.percent(deltaPercent)
        self.deltaLabel.text = Style.Text.percent(deltaPercent)
    }
}

protocol MarketsStateType {
    var marketsPublisher: AnyPublisher<[ExchangeMarket], AppError> { get }
    func marketDetailsPublisher(for: CurrencyPair) -> AnyPublisher<MarketDetails, AppError>
}

protocol MarketsEndpointType {
    func routeToLogin()
}

class MarketsViewController : ViewController, UISearchBarDelegate, UITableViewDelegate, MarketDetailsEndpointType {
    @IBOutlet weak var marketsTableView: MarketsTableView!
    @IBOutlet weak var searchBar: UISearchBar!
    
    var state: MarketsStateType!
    var endpoint: MarketsEndpointType!
    
    var marketsSubscription: AnyCancellable?
    var lifecycleSub: AnyCancellable?
    
    var refreshController: PeriodicRefreshController<([ExchangeMarket], String?)>?
    
    @Published var searchText: String?
    
    override func didBecomeActive() {
        self.refreshController = .init(refreshInterval: 1.0,
                                       viewLifecycleStream: self.viewLifecycleStream,
                                       dataStream: Publishers.CombineLatest(self.state.marketsPublisher,
                                                                            self.$searchText.debounce(for: 0.5, scheduler: RunLoop.main).mapError { never in AppError.miscError(never) }).asAny) { (input) in
                                                                                let (markets, searchTextOrNil) = input
                                                                                let results: [ExchangeMarket]
                                                                                if let searchText = searchTextOrNil,
                                                                                    !(searchText.isEmpty) {
                                                                                    results = markets.compactMap { (market) -> ExchangeMarket? in
                                                                                        let filteredMarkets =
                                                                                            market.1
                                                                                                .filter {
                                                                                                    $0.currencyPair.base.localizedLowercase.contains(searchText.localizedLowercase) || $0.currencyPair.other.localizedLowercase.contains(searchText.localizedLowercase)
                                                                                        }
                                                                                        //                            .sorted { (l, r) -> Bool in
                                                                                        //                                l.currencyPair.other.lexicographicallyPrecedes(r.currencyPair.other)
                                                                                        //                            }
                                                                                        
                                                                                        if filteredMarkets.isEmpty {
                                                                                            return nil
                                                                                        }
                                                                                        else {
                                                                                            return (market.0, filteredMarkets)
                                                                                        }
                                                                                    }
                                                                                }
                                                                                else {
                                                                                    results = markets
                                                                                }
                                                                                self.marketsTableView.markets = results.sorted { (l, r) -> Bool in
                                                                                    l.0.lexicographicallyPrecedes(r.0)
                                                                                }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "MarketDetails":
            self.prepare(marketDetailsSegue: segue, data: sender)
        default:
            super.prepare(for: segue, sender: sender)
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard tableView == self.marketsTableView else {
            return
        }
        self.searchBar.resignFirstResponder()
        self.performSegue(withIdentifier: "MarketDetails", sender: self.marketsTableView.data(for: indexPath))
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.searchBar.resignFirstResponder()
    }
    
    func prepare(marketDetailsSegue: UIStoryboardSegue, data: Any?) {
        struct MarketDetailsState : MarketDetailsStateType {
            let market: Market
            let marketDetailsPublisher: AnyPublisher<MarketDetails, AppError>
        }
        
        guard let marketDetailsVC = marketDetailsSegue.destination as? MarketDetailsViewController,
            let market = data as? TradeOgreAPI.V1.Market else {
            return
        }
        
        marketDetailsVC.state = MarketDetailsState(market: market,
                                                   marketDetailsPublisher: self.state.marketDetailsPublisher(for: market.currencyPair))
        marketDetailsVC.endpoint = self
    }
    
    func routeToLogin() {
        self.navigationController?.popToRootViewController(animated: true)
        delay(0.35) {
            self.endpoint.routeToLogin()
        }
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        self.searchText = searchText
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        self.searchText = searchBar.text
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.searchText = nil
    }
}
