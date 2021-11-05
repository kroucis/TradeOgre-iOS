//
//  PortfolioViewController.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 10/27/21.
//

import Combine
import UIKit

class BalancesTableView : UITableView, UITableViewDataSource {
    lazy var activitySpinner = UIActivityIndicatorView()
    
    let reuseIdentifier = "BalanceCell"
    var balances: [Balance] = [] {
        didSet {
            self.reloadData()
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.balances.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = self.dequeueReusableCell(withIdentifier: self.reuseIdentifier) as? BalanceTableViewCell else {
            return UITableViewCell()
        }
        cell.display(balance: self.balances[indexPath.row])
        return cell
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.dataSource = self
    }
}

class BalanceTableViewCell : UITableViewCell {
    func display(balance: TradeOgreAPI.V1.Balance) {
        self.textLabel?.text = balance.currency
        self.detailTextLabel?.text = TradeOgre.Style.Text.volume(balance.balance)
    }
}

protocol PortfolioStateType : LoginStateType {
    var balancesPublisher: AnyPublisher<[Balance], AppError> { get }
}

protocol PortfolioEndpointType {
    
}

class PortfolioViewController: ViewController, UISearchBarDelegate, UITableViewDelegate {
    @IBOutlet weak var balancesTableView: BalancesTableView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var logInButton: UIButton!
    
    @Published var searchText: String?
    
    lazy var refreshControl: UIRefreshControl = {
        let rc = UIRefreshControl()
        rc.addTarget(self, action: #selector(refresh), for: .valueChanged)
        return rc
    }()
    
    var state: PortfolioStateType!
    var endpoint: PortfolioEndpointType!
    
    var balancesSub: AnyCancellable?
    var lifecycleSub: AnyCancellable?
    
    override func didBecomeActive() {
        self.balancesTableView.refreshControl = self.refreshControl
        
        self.lifecycleSub =
            self.viewLifecycleStream
                .asPublisher()
                .sink(receiveValue: { (event) in
                    switch event {
                    case .viewWillAppear:
                        self.refresh()
                    case .viewWillDisappear:
                        self.balancesSub = nil
                    default:
                        break
                    }
                })
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        self.searchText = searchText
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        self.searchText = searchBar.text
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.searchBar.resignFirstResponder()
    }
    
    @objc func refresh() {
        self.balancesSub =
            Publishers.CombineLatest(self.state.balancesPublisher, self.$searchText.debounce(for: 0.5, scheduler: RunLoop.main).mapError { never in AppError.miscError(never) })
                .map { (result) -> [Balance] in
                    let (balances, searchTextOrNil) = result
                    return
                        balances
                            .filter { $0.balance >= 0.000001 }
                            .filter {
                                if let searchText = searchTextOrNil,
                                    !(searchText.isEmpty) {
                                    return $0.currency.localizedLowercase.contains(searchText.localizedLowercase)
                                }
                                else {
                                    return true
                                }
                        }
                        .sorted { $0.balance > $1.balance }
            }
            .sink(receiveCompletion: { _ in },
                  receiveValue: { balances in
                    MainThread.run {
                        self.refreshControl.endRefreshing()
                        self.balancesTableView.balances = balances
                    }
            })
    }
}

