//
//  LoginViewController.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 10/28/21.
//

import Combine
import UIKit

protocol LoginStateType : APIKeysStateType {
    var appVersion: (String, String) { get }
}

protocol LoginEndpointType : APIKeysEndpointType {
    
}

class LoginViewController : ViewController, UITextFieldDelegate {
    @IBOutlet weak var appVersionLabel: UILabel!
    
    var state: LoginStateType!
    var endpoint: LoginEndpointType!
    
    override func didBecomeActive() {
        self.appVersionLabel.text = "App Version \(self.state.appVersion.0) (\(self.state.appVersion.1))"
    }
    
    @IBAction func openWeb(_ sender: Any) {
        let link = URL(string: "https://tradeogre.com/account/settings")!
        UIApplication.shared.open(link)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard segue.identifier == "Keys",
              let keysVC = segue.destination as? APIKeysViewController else {
            return
        }
        keysVC.state = self.state
        keysVC.endpoint = self.endpoint
    }
}
