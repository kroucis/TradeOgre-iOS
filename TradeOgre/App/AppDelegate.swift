//
//  AppDelegate.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 10/27/21.
//

import Combine
import UIKit

public enum AppEvent {
    case didFinishLaunching
    case willResignActive
    case didBecomeActive
}

public protocol AppEventStreaming {
    func asPublisher() -> AnyPublisher<AppEvent, Never>
}

public protocol MutableAppEventStreaming {
    func update(appEvent: AppEvent)
}

public class AppEventStream : AppEventStreaming {
    fileprivate let appEventSubject = PassthroughSubject<AppEvent, Never>()
    public func asPublisher() -> AnyPublisher<AppEvent, Never> {
        return self.appEventSubject.eraseToAnyPublisher()
    }
}

public class MutableAppEventStream : AppEventStream, MutableAppEventStreaming {
    public func update(appEvent: AppEvent) {
        self.appEventSubject.send(appEvent)
    }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    public var appEventSteam: AppEventStream {
        return self.mutableAppEventStream
    }
    private let mutableAppEventStream = MutableAppEventStream()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        self.mutableAppEventStream.update(appEvent: .didFinishLaunching)
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        self.mutableAppEventStream.update(appEvent: .willResignActive)
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        self.mutableAppEventStream.update(appEvent: .didBecomeActive)
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}

