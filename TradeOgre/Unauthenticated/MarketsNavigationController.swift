//
//  MarketsNavigationController.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 10/28/21.
//

import UIKit

class MarketsNavigationController : UINavigationController {
    var state: MarketsStateType!
    var endpoint: MarketsEndpointType!
    
    override func viewDidLoad() {
        if let markets = self.viewControllers[0] as? MarketsViewController {
            markets.state = self.state
            markets.endpoint = self.endpoint
        }
        super.viewDidLoad()
    }
}
