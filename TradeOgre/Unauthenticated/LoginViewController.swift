//
//  LoginViewController.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 10/28/21.
//

import Combine
import UIKit

protocol LoginStateType {
    var appVersion: (String, String) { get }
}

protocol LoginEndpointType {
    func login(public: String, private: String) -> Future<(), AppError>
}

class LoginViewController : ViewController, UITextFieldDelegate {
    @IBOutlet weak var publicTextField: UITextField!
    @IBOutlet weak var privateTextField: UITextField!
    @IBOutlet weak var submitButton: UIButton!
    @IBOutlet weak var iHaveMyKeysButton: UIButton!
    @IBOutlet weak var formStackView: UIStackView!
    @IBOutlet weak var appVersionLabel: UILabel!
    
    var state: LoginStateType!
    var endpoint: LoginEndpointType!
    var loginSub: AnyCancellable?
    
    override func didBecomeActive() {
        self.formStackView.isHidden = true
        self.iHaveMyKeysButton.isHidden = false
        self.submitButton.isEnabled = false
        self.publicTextField.text = nil
        self.privateTextField.text = nil
        
        self.appVersionLabel.text = "App Version \(self.state.appVersion.0) (\(self.state.appVersion.1))"
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard)))
    }
    
    @objc func dismissKeyboard() {
        self.publicTextField.resignFirstResponder()
        self.privateTextField.resignFirstResponder()
    }
    
    @IBAction func submit(_ sender: Any) {
        guard let key = self.publicTextField.text,
                  key.count == 32,
              let secret = self.privateTextField.text,
                  secret.count == 32
        else {
            return
        }
        self.loginSub =
            self.endpoint.login(public: key, private: secret)
                .sink(receiveCompletion: { (result) in
                   }, receiveValue: { (_) in
                   })
    }
    
    @IBAction func openWeb(_ sender: Any) {
        self.dismissKeyboard()
        
        let link = URL(string: "https://tradeogre.com/account/settings")!
        UIApplication.shared.open(link)
    }
    
    @IBAction func iHaveMyKeys(_ sender: UIButton) {
        self.formStackView.isHidden = false
        self.iHaveMyKeysButton.isHidden = true
        self.publicTextField.becomeFirstResponder()
    }
    
    var inputIsValid: Bool {
        if let key = self.publicTextField.text,
            key.count == 32,
            let secret = self.privateTextField.text,
            secret.count == 32 {
            return true
        }
        else {
            return false
        }
    }
    
    func textFieldDidChangeSelection(_ textField: UITextField) {
        self.submitButton.isEnabled = self.inputIsValid
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        self.submitButton.isEnabled = self.inputIsValid
    }
}
