//
//  PortfolioNavigationController.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 10/28/21.
//

import Combine
import UIKit

class PortfolioNavigationController : UINavigationController {
    var state: PortfolioStateType!
    var endpoint: PortfolioEndpointType!
    
    override func viewDidLoad() {
        if let portfolioVC = self.viewControllers[0] as? PortfolioViewController {
            portfolioVC.state = state
            portfolioVC.endpoint = endpoint
        }
        
        super.viewDidLoad()
    }
}
