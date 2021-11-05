//
//  AuthenticatedRootTabBarController.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 10/29/21.
//

import Combine
import UIKit

protocol AuthenticatedRootState : UnauthenticatedRootState, AuthedMarketsStateType, OrdersStateType {
    
}

extension AppState : AuthenticatedRootState, SettingsStateType {

}

class AuthenticatedRootTabBarController : UITabBarController, MarketsEndpointType, SettingsEndpointType {
    var appState: AppState!
    var loggedInSub: AnyCancellable?
    
    override func viewDidLoad() {
        if let markets = self.viewControllers?[0] as? AuthedMarketsNavigationController {
            markets.authedState = self.appState
            markets.authedEndpoint = self.appState
            markets.state = self.appState
            markets.endpoint = self
        }
        
        if let portfolio = self.viewControllers?[1] as? PortfolioNavigationController {
            portfolio.state = self.appState
        }
        
        if let orders = self.viewControllers?[2] as? OrdersViewController {
            orders.endpoint = self.appState
            orders.state = self.appState
        }
 
        if let settings = self.viewControllers?[3] as? SettingsViewController {
            settings.state = self.appState
            settings.endpoint = self
        }
        
        super.viewDidLoad()
        
        self.loggedInSub = self.appState.loggedInPublisher
            .receive(on: RunLoop.main)
            .sink { isLoggedIn in
                if !(isLoggedIn) {
                    self.routeToUnauthedRoot()
                }
            }
    }
    
    func routeToLogin() {
        // DO NOTHING
    }
    
    func routeToUnauthedRoot() {
        guard let unauthedVC = UIStoryboard(name: "Unauthenticated", bundle: nil).instantiateInitialViewController() as? UnauthenticatedRootTabBarController else {
            print("WHAT")
            return
        }
        unauthedVC.appState = self.appState
        self.view.window?.rootViewController = unauthedVC
    }
    
    func logOut() {
        _ = self.appState.logOut()
    }
}
