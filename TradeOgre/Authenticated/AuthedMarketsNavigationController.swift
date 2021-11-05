//
//  AuthedMarketsNavigationController.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 10/30/21.
//

import Combine
import UIKit

class AuthedMarketsNavigationController : MarketsNavigationController {
    var authedState: AuthedMarketsStateType!
    var authedEndpoint: AuthedMarketsEndpointType!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let markets = self.viewControllers[0] as? AuthedMarketsViewController {
            markets.authedState = self.authedState
            markets.authedEndpoint = self.authedEndpoint
        }
    }
}

