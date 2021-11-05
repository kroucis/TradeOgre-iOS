//
//  UnauthenticatedRootTabBarController.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 10/28/21.
//

import Combine
import UIKit

protocol UnauthenticatedRootState : MarketsStateType {
    var loggedInPublisher: AnyPublisher<Bool, Never> { get }
}

extension AppState : UnauthenticatedRootState {
    var loggedInPublisher: AnyPublisher<Bool, Never> {
        return self.$isLoggedIn.asAny
    }
}

extension AppState : LoginStateType, LoginEndpointType {
    
}

class UnauthenticatedRootTabBarController : UITabBarController, MarketsEndpointType {
    var appState: AppState!
    var loggedInSub: AnyCancellable?
    override func viewDidLoad() {
        if let markets = self.viewControllers?[0] as? MarketsNavigationController {
            markets.state = self.appState
            markets.endpoint = self
        }
        
        if let login = self.viewControllers?[1] as? LoginViewController {
            login.state = self.appState
            login.endpoint = self.appState
        }
        
        super.viewDidLoad()
        
        self.loggedInSub = self.appState.loggedInPublisher
            .receive(on: RunLoop.main)
            .sink { isLoggedIn in
                if isLoggedIn {
                    self.routeToAuthedRoot()
                }
            }
    }
    
    func routeToLogin() {
        self.selectedIndex = 1
    }
    
    func routeToAuthedRoot() {
        guard let unauthedVC = UIStoryboard(name: "Authenticated", bundle: nil).instantiateInitialViewController() as? AuthenticatedRootTabBarController else {
            print("WHAT")
            return
        }
        unauthedVC.appState = self.appState
        self.view.window?.rootViewController = unauthedVC
    }
}
