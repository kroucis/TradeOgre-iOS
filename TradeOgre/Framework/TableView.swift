//
//  TableView.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 10/27/21.
//

import Combine
import UIKit

protocol TableViewCellType : UITableViewCell {
    associatedtype DATA
    func display(data: DATA)
}

class TableView<DATA, CELL: TableViewCellType> : UITableView, UITableViewDataSource where CELL.DATA == DATA {
    var data: [DATA] = [] {
        didSet {
            MainThread.run(self.reloadData)
        }
    }
    
    private var reuseIdentifier = "CELL"
    
    func data(for indexPath: IndexPath) -> DATA {
        return self.data[indexPath.row]
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.data.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = self.dequeueReusableCell(withIdentifier: self.reuseIdentifier) as? CELL else {
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
