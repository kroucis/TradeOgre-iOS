//
//  Style.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 10/28/21.
//

import UIKit

class Style {
    class Color {
        static let positive = UIColor.green
        static let negative = UIColor.red
        static let zero = UIColor.gray
        static func percent(_ percent: Double) -> UIColor {
            return (percent > 0.0001) ? Color.positive : (percent < -0.0001) ? Color.negative : Color.zero
        }
    }
    class Text {
        static let priceFormatter: NumberFormatter = {
            let fmt = NumberFormatter()
            fmt.minimumSignificantDigits = 2
            fmt.maximumSignificantDigits = 10
            return fmt
        }()
        
//        static let volumeFormatter: NumberFormatter = {
//            let fmt = NumberFormatter()
//            fmt.minimumSignificantDigits = 1
//            fmt.maximumSignificantDigits = 8
//            return fmt
//        }()
        
        static let percentFormatter: NumberFormatter = {
            let fmt = NumberFormatter()
            fmt.numberStyle = .percent
            fmt.minimumFractionDigits = 1
            fmt.maximumFractionDigits = 2
            return fmt
        }()
        
        static let orderDateFormatter: DateFormatter = {
            let fmt = DateFormatter()
            fmt.dateStyle = .medium
            fmt.formattingContext = .standalone
            return fmt
        }()
        
        static func price(_ price: Double) -> String {
            return Text.priceFormatter.string(for: price) ?? "???"
        }
        
        static func volume(_ volume: Double) -> String {
//            return Text.volumeFormatter.string(for: volume) ?? "???"
            return Text.priceFormatter.string(for: volume) ?? "???"
        }
        
        static func percent(_ percent: Double) -> String {
            return Text.percentFormatter.string(for: percent) ?? "0.0%"
        }
        
        static func date(order: Date) -> String {
            return Text.orderDateFormatter.string(from: order)
        }
        
        static func buy(volume: Double) -> String {
            return "Buy \(self.volume(volume))"
        }
        
        static func sell(volume: Double) -> String {
            return "Sell \(self.volume(volume))"
        }
    }
}
