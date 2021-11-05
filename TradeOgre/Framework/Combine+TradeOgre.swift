//
//  Combine+TradeOgre.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 11/1/21.
//

import Combine

extension Publisher {
    /// Property wrapper for the very common and verbose `eraseToAnyPublisher` method.
    var asAny: AnyPublisher<Self.Output, Self.Failure> {
        return self.eraseToAnyPublisher()
    }
}
