//
//  OrdersViewController.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 10/29/21.
//

import Combine
import UIKit

protocol OrdersStateType {
    var ordersPublisher: AnyPublisher<[PendingOrder], AppError> { get }
}

protocol OrdersEndpointType {
    func cancel(pendingOrder: UUID) -> AnyPublisher<(), AppError>
}

@objc protocol OrdersTableViewDelegate {
    func delete(pendingOrder: UUID, completionBlock: @escaping (Bool) -> Void)
}

class OrdersTableView : UITableView, UITableViewDataSource {
    @IBOutlet weak var orderDelegate: OrdersTableViewDelegate?
    
    var pendingOrders: [PendingOrder] = [] {
        didSet {
            MainThread.run(self.reloadData)
        }
    }
    
    func data(for indexPath: IndexPath) -> PendingOrder {
        return self.pendingOrders[indexPath.row]
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.pendingOrders.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = self.dequeueReusableCell(withIdentifier: "Order") as? OrderTableViewCell else {
            return UITableViewCell()
        }
        cell.display(pendingOrder: self.data(for: indexPath))
        return cell
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return !(tableView.isEditing)
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        switch editingStyle {
        case .delete:
            self.orderDelegate?.delete(pendingOrder: self.data(for: indexPath).uuid) { success in
                if success {
                    self.pendingOrders.remove(at: indexPath.row)
                    self.deleteRows(at: [indexPath], with: .automatic)
                }
            }
        default:
            break
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.dataSource = self
    }
}

class OrderTableViewCell : UITableViewCell {    
    func display(pendingOrder: PendingOrder) {
        self.textLabel?.text = "\(pendingOrder.action == .buy ? TradeOgre.Style.Text.buy(volume: pendingOrder.volume) : TradeOgre.Style.Text.sell(volume: pendingOrder.volume)) \(pendingOrder.currencyPair.other) @ \(Style.Text.price(pendingOrder.price)) \(pendingOrder.currencyPair.base)"
        self.detailTextLabel?.text = Style.Text.date(order: pendingOrder.date)
    }
}

class OrdersViewController : ViewController, UITableViewDelegate, OrdersTableViewDelegate {
    @IBOutlet weak var ordersTableView: OrdersTableView!
    
    lazy var refreshControl: UIRefreshControl = {
        let rc = UIRefreshControl()
        rc.addTarget(self, action: #selector(refresh), for: .valueChanged)
        return rc
    }()
    
    var state: OrdersStateType!
    var endpoint: OrdersEndpointType!//
    var ordersSub: AnyCancellable?
    
    override func didBecomeActive() {
        self.ordersTableView.refreshControl = self.refreshControl
        self.refresh()
    }
    
    @objc func refresh() {
        self.ordersSub =
            self.state.ordersPublisher
                .sink(receiveCompletion: { _ in
                    MainThread.run { self.refreshControl.endRefreshing() }
                },
                  receiveValue: {
                    self.ordersTableView.pendingOrders = $0
                })
    }
    
    var deleteSub: AnyCancellable?
    func delete(pendingOrder: UUID, completionBlock: @escaping (Bool) -> Void) {
        self.deleteSub = self.endpoint.cancel(pendingOrder: pendingOrder)
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { (result) in
                switch result {
                case .failure:
                    completionBlock(false)
                case .finished:
                    completionBlock(true)
                }
            }, receiveValue: { (_) in
            })
    }
}
