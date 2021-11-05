//
//  Foundation+TradeOgre.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 11/1/21.
//

import Foundation

class MainThread {
    static func run(_ block: @escaping () -> Void) {
        DispatchQueue.main.async(execute: block)
    }
    
    private init() {    // Block construction
        
    }
}

/// Wait `delay` seconds, then run `block` on `queue` (default main).
func delay(_ delay: TimeInterval, on queue: DispatchQueue = .main, block: @escaping () -> Void) {
    queue.asyncAfter(deadline: .now() + delay, execute: block)
}
