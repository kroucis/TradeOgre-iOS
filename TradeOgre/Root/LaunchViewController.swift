//
//  LaunchViewController.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 10/29/21.
//

import Combine
import UIKit

class LaunchViewController : ViewController {
    let appState = AppState()
    override func didBecomeActive() {
        delay(1.0) {
            if self.appState.isLoggedIn {
                guard let authedVC = UIStoryboard(name: "Authenticated", bundle: nil).instantiateInitialViewController() as? AuthenticatedRootTabBarController else {
                    print("HUH")   // TODO: More and better error handling
                    return
                }
                authedVC.appState = self.appState
                self.view.window?.rootViewController = authedVC
            }
            else {
                guard let unauthedVC = UIStoryboard(name: "Unauthenticated", bundle: nil).instantiateInitialViewController() as? UnauthenticatedRootTabBarController else {
                    print("WHAT")   // TODO: More and better error handling
                    return
                }
                unauthedVC.appState = self.appState
                self.view.window?.rootViewController = unauthedVC
            }
        }
    }
}
