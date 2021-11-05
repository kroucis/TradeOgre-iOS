//
//  PeriodicRefreshController.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 11/4/21.
//

import Combine
import Foundation

class PeriodicRefreshController<DataType> {
    var lifecycleSub: AnyCancellable?
    var updatesSub: AnyCancellable?
    
    init(refreshInterval: TimeInterval, viewLifecycleStream: ViewLifecycleStreaming, dataStream: AnyPublisher<DataType, AppError>, block: @escaping (DataType) -> Void) {
        self.lifecycleSub =
            viewLifecycleStream
        .asPublisher()
        .sink { (event) in
            switch event {
            case .viewWillAppear(_):
                self.updatesSub =
                    dataStream
                        .sink(receiveCompletion: { (_) in },
                              receiveValue: { (data) in
                                block(data)
                                self.updatesSub =
                                    Timer.publish(every: refreshInterval, on: .main, in: .common)
                                    .autoconnect()
                                    .mapError({ never -> AppError in
                                        .miscError(never)
                                    })
                                    .flatMap({ (_) -> AnyPublisher<DataType, AppError> in
                                        return dataStream
                                    })
                                    .sink(receiveCompletion: { (_) in },
                                          receiveValue: block)
                        })
            case .viewWillDisappear(_):
                self.updatesSub = nil
            default:
                break
            }
        }
    }
}
