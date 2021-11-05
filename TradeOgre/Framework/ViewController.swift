//
//  ViewController.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 10/29/21.
//

import Combine
import UIKit

public enum ViewLifecycleEvent {
    case viewDidLoad
    case viewWillAppear(Bool)
    case viewDidAppear(Bool)
    case viewWillDisappear(Bool)
    case viewDidDisappear(Bool)
}

public protocol ViewLifecycleStreaming {
    func asPublisher() -> AnyPublisher<ViewLifecycleEvent, Never>
}

public protocol MutableViewLifecycleStreaming : ViewLifecycleStreaming {
    func update(viewLifecycleEvent: ViewLifecycleEvent)
}

public class ViewLifecycleStream : ViewLifecycleStreaming {
    fileprivate let viewLifecycleSubject = PassthroughSubject<ViewLifecycleEvent, Never>()
    public func asPublisher() -> AnyPublisher<ViewLifecycleEvent, Never> {
        return self.viewLifecycleSubject.eraseToAnyPublisher()
    }
}

public final class MutableViewLifecycleStream : ViewLifecycleStream, MutableViewLifecycleStreaming {
    public override init() {
        super.init()
    }
    
    public func update(viewLifecycleEvent: ViewLifecycleEvent) {
        self.viewLifecycleSubject.send(viewLifecycleEvent)
    }
}

/// Base class that wraps UIViewController for more consistent and reactive events.
class ViewController : UIViewController {
    var viewLifecycleStream: ViewLifecycleStreaming {
        return self.mutableLifecycleStream
    }
    private let mutableLifecycleStream = MutableViewLifecycleStream()
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        self.mutableLifecycleStream.update(viewLifecycleEvent: .viewDidLoad)
        
        self.activate()
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.mutableLifecycleStream.update(viewLifecycleEvent: .viewWillAppear(animated))
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.mutableLifecycleStream.update(viewLifecycleEvent: .viewDidAppear(animated))
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.mutableLifecycleStream.update(viewLifecycleEvent: .viewWillDisappear(animated))
    }
    
    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.mutableLifecycleStream.update(viewLifecycleEvent: .viewDidDisappear(animated))
    }
    
    open func didBecomeActive() {
        
    }
    
    open func willResignActive() {
        
    }
    
    private func activate() {
        self.didBecomeActive()
        
        self.children.forEach { (child) in
            if let vc = child as? ViewController {
                vc.activate()
            }
        }
    }
    
    private func deactivate() {
        self.willResignActive()
        
        self.children.forEach { (child) in
            if let vc = child as? ViewController {
                vc.deactivate()
            }
        }
    }
}
