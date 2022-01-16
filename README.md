#  TradeOgre iOS

## Overview
TradeOgre iOS is an iOS client for the [TrageOgre.com](https://tradeogre.com) website and crypto-exchange platform. I was looking for their iOS client, noticed there wasn't an official one but saw that TradeOgre published their API specifications, so I figured "I'll build an iOS app!" After a month of development, the app is in the state you currently see it and is more-or-less ready for a 1.0 release. HOWEVER, two major hurdles prevent an "official" version:
1. Apple refuses to publish the app in its current state because I do not have an "institutional development account appropriate for crypto-currency trading."
1. @TradeOgre only has their Twitter handle for contact information and has not responded to my inquiries about getting their support to put this app on the Apple App Store.

Sadly, this means that if you want to use this TradeOgre app, you must clone this repository to your own computer, build the project yourself, and install on your own device, including signing up to and paying for an Apple Developer Program license (100 USD/year). Seeing as I've had no external support and am providing this for free, this software is provided "as is" and without warranty or garuantee of any kind (See [LICENSE](LICENSE)). If you would like to see more features or support more work on this project, feel free to ping me in an issue. Until I have support from TradeOgre, Apple, or the TradeOgre community, I am considering this project to be abandoned.

## Technical Specifications
- **App Version**: 1.0.0 (100000)
- **Minimum OS Version**: iOS 13.0
- **Minimum Swift Version**: Swift 5.1
- **UI Framework**: Storyboards
- **Architecture**: State-Endpoint, Combine
- **Remote Data Source(s)**: [TradeOgre API v1](https://tradeogre.com/help/api)

## Building from Source
This project does not use any external dependencies, so simply selecting `Product > Run` (Cmd-r) should build and run the project on the target device.

## Code Style
Standard Swift code style, utilizing Xcode's built-in "Ctrl-i" command for spacing and layout.

## Detailed Architecture
TradeOgre on iOS can be used in two over-arching states: unauthenticated and authenticated. Upon first install, the app is in the unauthenticated state, allowing users to access only the public API endpoints that do not require an API key or other user authentication. Once the user has provided authentication tokens generated on the TradeOgre website, they can be provided to the app in the Settings interface to be stored securely in the [iOS keychain](https://developer.apple.com/documentation/security/keychain_services). With these credentials, users will be able to access the API endpoints that require API keys, such as submitting trade orders, checking balances, and viewing trade history.

### State-Endpoint Architecture
The TradeOgre iOS app architecture borrows from modern Functional Reactive Programming techniques while still utilizing mutation-based tech such as the UIKit framework and Storyboards. There are three major elements to understand about the app architecture at a high level:

1. Shared, global app state exists at the application root and is passed down to child vew controllers using protocols as a type-narrowing mechanism. Only the root app state object is allowed to mutate its stored data.
2. Each ViewController defines a `State`: containing the data that the ViewController depends upon, often presenting this state as streams of data that may change over time. The data contained in the `State` is immutable from the perspective of the ViewController. 
3. Each ViewController defines an `Endpoint`: the only way of communicating with the outside world, providing only functions as a means of informing the view controller's owner about events and requests for data or navigation changes.

This architecture effectively builds a dependency tree that narrows the scope of available state information, where each child ViewController defines their required `State` and `Endpoint` interfaces, that are then expanded upon by parent ViewControllers, and so on all the way up to the root of the application. The `State` and `Endpoint` are usually passed to child ViewControllers using StoryboardSegues and conditional casting. Since the app has both unauthenticated and authenticated behavior that share a lot of functionality, the Storyboard files are split into distinct files for each state, significantly simplifying UI management and Storyboard layout.

### Implementation
#### Root
The `AppState` class contains all of the app-wide shared resources. When the `LaunchViewController` is constructed from the [Main Storyboard file](Root/Main.storyboard), an instance of `AppState` is created and used to store the on-going app-global shared state. Upon launch, the app presents the contents of the `LaunchViewController` and determines if the user has valid API tokens available. If API tokens are found, the root ViewController is replaced with the `AuthenticatedRootTabBarController` and the root `AppState` is passed along; if no tokens are found, then `UnauthenticatedRootTabBarController` is built and presented instead.

#### Unauthenticated
Loading from the [Unauthenticated Storyboard](Unauthenticated/Unauthenticated.storyboard), a simple `Client.Unauthenticated` is created for API access, not allowing any endpoints that require API keys. The user can browse markets and see market details, but cannot otherwise interact with the markets. They can also follow a short set of instructions to generate and submit their API keys. Once keys are submitted, the root ViewController is replaced with `AuthenticatedRootTabBarController` and the global `AppState` is handed over.

#### Authenticated
Once authenticated, the [Authenticated Storyboard](Authenticated/Authenticated.storyboard) is loaded and a new `Client.Authenticated` state is built that maintains the user's API keys and exposes functions/methods for calling endpoints that require auth. This includes wallet balances, view and delete current market orders, craft and submit buy/sell actions, and log out to return to the Unauthenticated state. Since so much of the UI and behavior is the same for both app states, the Authenticated versions of the ViewControllers are subclasses of the Unauthenticated counterparts. This significantly increases code reuse and allows functionality to be hidden simply without having a mess in the Storyboard file.

## Future Features
"Nice to Have" features for implementation in the future. These features are intended to be expansions on the current application that will impact a user's typical usage of the app (in contrast to Known Issues which is more focused on bugs and other "behind the scenes" issues).
- Security View Controller for setting a PIN and enabling/disabling FaceID/TouchID.
- Require a PIN and/or FaceID/TouchID for beginning or resuming an app session.
- UI to surface API key auth failures and prompt the user to regenerate their keys.
- Maybe add an "Update Frequency" setting to control how often API calls are made for auto-updating ViewControllers?
- More nuanced iPad features.
- Maybe more Settings...?

## Known Issues
Bugs, crashes, tech debt, and other issues that are not "user visible" and should be addressed to improve basic app functionality.
- Poor error model: Not enough propagation of errors downstream.
- Poor error surfacing: When an error occurs, the user is not notified.
- API Keys are not validated before moving to "authenticated" state.
- No analytics.
- No crash reporting.
- Maybe need to access the Keychain for API keys every time? Keeping them in memory with the client may be considered "risky"? Seems extremely inefficient as I think the KeychainService stuff is an XPC call, so should be a MASSIVE perf penalty...

## Tips and Android Version
If you would like to send a tip for this work, feel free to send some XMR to this address: 87pYWFvyhmrWdw2EFekpZaZJf4tm758maJAigzkPmd9tD8ou3VByDMuG1DpsFcmTBzZrafk38kLv71wX5sfpX2ri7Zbym1P
If you would like to support the development of an Android version of this app, please send a lot of XMR to this address: 89sA2PuDuYyDvrozNKynxaYDPdkvLUbfbbBQHUaa3dPMbYKkXLWqgGvFsubenscmfE95uv6G9nVha4yskG5h9bef8ptFJLu
For anyone who sends a tip, thank you very much! 

## License
This project is MIT licensed. For the full license, see [LICENSE](LICENSE).

## Contact
The original author and current maintainer for this project is Kyle Roucis ([@kroucis](github.com/kroucis))

## Project Hosting
This project is hosted on [GitHub as TradeOgre-iOS](github.com/kroucis/TradeOgre-ios) and is Open Source Software, subject to the License above.
