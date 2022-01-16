//
//  APIKeysViewController.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 1/15/22.
//  Copyright © 2022 Big Byte Studios, Inc. All rights reserved.
//

import Combine
import UIKit

protocol APIKeysStateType {
    
}

protocol APIKeysEndpointType {
    func login(public: String, private: String) -> Future<(), AppError>
}

class APIKeysViewController : ViewController, UITextFieldDelegate {
    @IBOutlet weak var publicTextField: UITextField!
    @IBOutlet weak var privateTextField: UITextField!
    @IBOutlet weak var submitButton: UIButton!
    
    var state: APIKeysStateType!
    var endpoint: APIKeysEndpointType!
    var loginSub: AnyCancellable?
    
    override func didBecomeActive() {
        self.publicTextField.text = nil
        self.privateTextField.text = nil
        self.submitButton.isEnabled = false
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
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch (self.publicTextField.text ?? "", self.privateTextField.text ?? "") {
        case (let pub, let priv) where pub.count == 32 && priv.count == 32:
            self.dismissKeyboard()
            if self.inputIsValid {
                self.submit(textField)
            }
            return true
        case (let pub, let priv) where pub.count == 32 && priv.count != 32:
            self.privateTextField.becomeFirstResponder()
            return false
        case (_, _):
            self.publicTextField.becomeFirstResponder()
            return false
        }
    }
}
