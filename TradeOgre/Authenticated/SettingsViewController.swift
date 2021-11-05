//
//  SettingsViewController.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 10/29/21.
//

import Combine
import UIKit

protocol SettingsStateType {
    var appVersion: (String, String) { get }
}

protocol SettingsEndpointType {
    func logOut()
}

class SettingsNavigationController : UINavigationController {
    var state: SettingsStateType!
    var endpoint: SettingsEndpointType!
    
    override func viewDidLoad() {
        if let settingsVC = self.viewControllers[0] as? SettingsViewController {
            settingsVC.state = state
            settingsVC.endpoint = endpoint
        }
        
        super.viewDidLoad()
    }
}

class SettingsViewController : ViewController {
    var state: SettingsStateType!
    var endpoint: SettingsEndpointType!
    
    @IBOutlet weak var appVersionLabel: UILabel!
    
    override func didBecomeActive() {
        self.appVersionLabel.text = "App Version \(self.state.appVersion.0) (\(self.state.appVersion.1))"
    }
    
    @IBAction func logOut(_ sender: Any) {
        self.endpoint.logOut()
    }
}
