//
//  TipViewController.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 11/1/21.
//

import Combine
import UIKit

class TipViewController : ViewController {
    @IBOutlet weak var addressCopiedLabel: UILabel!
    @IBOutlet weak var androidAddressCopiedLabel: UILabel!
    @IBOutlet weak var iosStackView: UIStackView!
    @IBOutlet weak var androidStackView: UIStackView!
    @IBOutlet weak var iosLabel: UILabel!
    @IBOutlet weak var androidLabel: UILabel!
    
    override func didBecomeActive() {
        self.addressCopiedLabel.alpha = 0.0
        androidAddressCopiedLabel.alpha = 0.0
        self.swapToiOS(self)
    }
    
    @IBAction func copyAddressToClipboard(_ sender: Any) {
        UIPasteboard.general.string = Tips.XMR.iOS.address
        self.addressCopiedLabel.alpha = 1.0
        delay(3.0) {
            self.addressCopiedLabel.fadeOut(duration: 3.0)
        }
    }
    @IBAction func copyAndroidAddressToClipboard(_ sender: Any) {
        UIPasteboard.general.string = Tips.XMR.Android.address
        self.androidAddressCopiedLabel.alpha = 1.0
        delay(3.0) {
            self.androidAddressCopiedLabel.fadeOut(duration: 3.0)
        }
    }
    
    @IBAction func swapToAndroid(_ sender: Any) {
        self.iosStackView.isHidden = true
        self.iosLabel.isHidden = true
        self.androidStackView.isHidden = false
        self.androidLabel.isHidden = false
    }
    
    
    @IBAction func swapToiOS(_ sender: Any) {
        self.iosStackView.isHidden = false
        self.iosLabel.isHidden = false
        self.androidStackView.isHidden = true
        self.androidLabel.isHidden = true
    }
}
