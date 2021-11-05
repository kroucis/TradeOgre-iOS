//
//  UIView+TradeOgre.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 11/4/21.
//

import Combine
import UIKit

extension UIView {
    /// Unhides and alpha fades in all of the `UIView`s in `views` together over the `duration` (in seconds).
    static func fadeAllIn(duration: TimeInterval = 0.35, views: [UIView]) {
        views.forEach { $0.isHidden = false }
        UIView.animate(withDuration: duration) {
            views.forEach {
                $0.alpha = 1.0
            }
        }
    }
    
    /// Unhides and alpha fades in all of the `UIView`s in `views` together over the `duration` (in seconds).
    static func fadeAllIn(duration: TimeInterval = 0.35, views: UIView...) {
        self.fadeAllIn(duration: duration, views: views)
    }
    
    /// Alpha fades out all of the `UIView`s in `views` together over the `duration` (in seconds), hiding them when the animation is completed.
    static func fadeAllOut(duration: TimeInterval = 0.35, views: [UIView]) {
        UIView.animate(withDuration: duration,
                       animations: {
                        views.forEach { $0.alpha = 0.0 }
        }, completion: { _ in
            views.forEach { $0.isHidden = true }
        })
    }
    
    /// Alpha fades out all of the `UIView`s in `views` together over the `duration` (in seconds), hiding them when the animation is completed.
    static func fadeAllOut(duration: TimeInterval = 0.35, views: UIView...) {
        self.fadeAllOut(duration: duration, views: views)
    }
    
    /// Unhides and alpha fades in `self` over the `duration` (in seconds).
    func fadeIn(duration: TimeInterval = 0.35) {
        self.isHidden = false
        UIView.animate(withDuration: duration) {
            self.alpha = 1.0
        }
    }
    
    /// Alpha fades out `self` over the `duration` (in seconds), hiding `self` when the animation is completed.
    func fadeOut(duration: TimeInterval = 0.35) {
        UIView.animate(withDuration: duration, animations: {
            self.alpha = 0.0
        },
                       completion: { _ in
                        self.isHidden = true
        })
    }
}
