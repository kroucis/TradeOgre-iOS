//
//  TradeViewController.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 10/30/21.
//

import Combine
import UIKit

protocol TradeStateType {
    var currencyPair: CurrencyPair { get }
    var balancesPublisher: AnyPublisher<(base: Double, other: Double), AppError> { get }
}

protocol TradeEndpointType {
    func submitOrder(currencyPair: CurrencyPair, action: Action, price: Double, volume: Double) -> AnyPublisher<(), AppError>
    func done(_: TradeViewController)
}

class TradeLabel : UILabel {
    private lazy var subscriptions: Set<AnyCancellable> = []
    func text(_ pub: AnyPublisher<String?, Never>) {
        self.subscriptions.insert(pub.assign(to: \.text, on: self))
    }
    
    func textColor(_ pub: AnyPublisher<UIColor, Never>) {
        self.subscriptions.insert(pub.assign(to: \.textColor, on: self))
    }
    
    func isHidden(_ pub: AnyPublisher<Bool, Never>) {
        self.subscriptions.insert(pub.assign(to: \.isHidden, on: self))
    }
}

class TradeTextField : UITextField, UITextFieldDelegate {
    enum EditEvent {
        case changedSelection(String?)
        case begin(String?)
        case end(String?)
    }
    private lazy var eventSubject = PassthroughSubject<EditEvent, Never>()
    private lazy var subscriptions: Set<AnyCancellable> = []
    var eventPublisher: AnyPublisher<EditEvent, Never> {
        return eventSubject.eraseToAnyPublisher()
    }
    
    func textFieldDidChangeSelection(_ textField: UITextField) {
        self.eventSubject.send(.changedSelection(textField.text))
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        self.eventSubject.send(.end(textField.text))
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.eventSubject.send(.begin(textField.text))
    }
    
    func isHidden(_ pub: AnyPublisher<Bool, Never>) {
        pub
            .assign(to: \.isHidden, on: self)
            .store(in: &self.subscriptions)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.delegate = self
    }
}

class TradeButton : UIButton {
    private lazy var subscriptions: Set<AnyCancellable> = []
    func isEnabled(_ pub: AnyPublisher<Bool, Never>) {
        pub
            .assign(to: \.isEnabled, on: self)
            .store(in: &self.subscriptions)
    }
    
    func isHidden(_ pub: AnyPublisher<Bool, Never>) {
        pub
            .assign(to: \.isHidden, on: self)
            .store(in: &self.subscriptions)
    }
    
    func alpha(_ pub: AnyPublisher<CGFloat, Never>) {
        pub
            .assign(to: \.alpha, on: self)
            .store(in: &self.subscriptions)
    }
    
    func titleForState(_ pub: AnyPublisher<(String?, UIControl.State), Never>) {
        pub
            .sink {
                self.setTitle($0.0, for: $0.1)
            }
            .store(in: &self.subscriptions)
    }
}

class TradeViewController : ViewController {
    enum ViewState {
        case editing
        case previewing
    }
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var actionSwitcher: UISegmentedControl!
    
    @IBOutlet weak var baseLabel: UILabel!
    @IBOutlet weak var otherLabel: UILabel!
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet weak var priceWarningLabel: TradeLabel!
    @IBOutlet weak var volumeWarningLabel: TradeLabel!
    
    @IBOutlet weak var priceLabel: TradeLabel!
    @IBOutlet weak var volumeLabel: TradeLabel!
    @IBOutlet weak var priceValueLabel: TradeLabel!
    @IBOutlet weak var volumeValueLabel: TradeLabel!
    
    @IBOutlet weak var priceTextField: TradeTextField!
    @IBOutlet weak var volumeTextField: TradeTextField!
    
    @IBOutlet weak var tradeButton: TradeButton!
    @IBOutlet weak var editButton: TradeButton!
    
    var state: TradeStateType!
    var endpoint: TradeEndpointType!
    
    var action: Action = .buy {
        didSet {
            switch self.action {
            case .buy:
                self.actionSwitcher?.selectedSegmentIndex = 0
                UIView.animate(withDuration: 0.35) {
                    self.tradeButton?.backgroundColor = .systemGreen
                    self.balanceLabel?.text = "\(Style.Text.volume(self.balances.base)) \(self.state.currencyPair.base)"
                }
            case .sell:
                self.actionSwitcher?.selectedSegmentIndex = 1
                UIView.animate(withDuration: 0.35) {
                    self.tradeButton?.backgroundColor = .systemRed
                    self.balanceLabel?.text = "\(Style.Text.volume(self.balances.other)) \(self.state.currencyPair.other)"
                }
            }
        }
    }
    var balances: (base: Double, other: Double) = (base: 0.0, other: 0.0) {
        didSet {
            switch self.action {
            case .buy:
                self.action = .buy
            case .sell:
                self.action = .sell
            }
        }
    }
    var balanceSub: AnyCancellable?
    var validInputSub: AnyCancellable?
    var viewStateSub: AnyCancellable?
    @Published var viewState = ViewState.editing
    var inputSubject = CurrentValueSubject<(price: Double?, volume: Double?), Never>((price: nil, volume: nil))
    
    override func didBecomeActive() {
        self.titleLabel.text = "Trade \(self.state.currencyPair.asString)"
        switch self.action {
        case .buy:
            self.action = .buy
        case .sell:
            self.action = .sell
        }
        
        self.viewStateSub =
            self.$viewState
                .receive(on: RunLoop.main)
                .sink(receiveValue: { vs in
                        switch vs {
                        case .editing:
                            UIView.fadeAllIn(duration: 0.35, views: self.priceTextField, self.volumeTextField, self.actionSwitcher)
                            UIView.fadeAllOut(duration: 0.35, views: self.editButton, self.priceValueLabel, self.volumeValueLabel)
                            
//                            UIView.animate(withDuration: 0.35,
//                               animations: {
//                                self.priceTextField.alpha = 1.0
//                                self.priceTextField.isHidden = false//
//                                self.volumeTextField.alpha = 1.0
//                                self.volumeTextField.isHidden = false//
//                                self.actionSwitcher.alpha = 1.0
//                                self.actionSwitcher.isHidden = false//
//                                self.editButton.alpha = 0.0
//                                self.priceValueLabel.alpha = 0.0
//                                self.volumeValueLabel.alpha = 0.0
//                            }, completion: { _ in
//                                self.editButton.isHidden = true
//                                self.priceValueLabel.isHidden = true
//                                self.volumeValueLabel.isHidden = true
//                            })
                            self.tradeButton.setTitle("Preview Order", for: .normal)
                        case .previewing:
                            UIView.fadeAllIn(duration: 0.35, views: self.editButton, self.priceValueLabel, self.volumeValueLabel)
                            UIView.fadeAllOut(duration: 0.35, views: self.priceTextField, self.volumeTextField, self.actionSwitcher)
                            
//                            UIView.animate(withDuration: 0.35,
//                               animations: {
//                                self.editButton.alpha = 1.0
//                                self.editButton.isHidden = false
//                                
//                                self.priceValueLabel.alpha = 1.0
//                                self.priceValueLabel.isHidden = false
//                                
//                                self.volumeValueLabel.alpha = 1.0
//                                self.volumeValueLabel.isHidden = false
//                                
//                                self.priceTextField.alpha = 0.0
//                                self.volumeTextField.alpha = 0.0
//                                self.actionSwitcher.alpha = 0.0
//                            }, completion: { _ in
//                                self.priceTextField.isHidden = true
//                                self.volumeTextField.isHidden = true
//                                self.actionSwitcher.isHidden = true
//                            })
                            
                            self.tradeButton.setTitle((self.action == .buy
                                ? "Submit Buy Order"
                                : "Submit Sell Order"),
                                                      for: .normal)
                        }
                })
                
        
        self.baseLabel.text = self.state.currencyPair.base
        self.otherLabel.text = self.state.currencyPair.other
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(viewTapped(_:))))
        
        self.priceTextField.becomeFirstResponder()
        
        self.balanceSub =
            self.state.balancesPublisher
                .sink(receiveCompletion: { _ in },
                      receiveValue: { (balances) in
                    })
        
        let priceValuePublisher: AnyPublisher<Double?, Never> =
            self.priceTextField.eventPublisher
                .map { event -> String? in
                    switch event {
                    case .begin(let stringOrNil),
                        .changedSelection(let stringOrNil),
                         .end(let stringOrNil):
                        return stringOrNil
                    }
                }
                .map { $0?.asPrice }
                .prepend(nil)
                .share()
                .eraseToAnyPublisher()
        
        let volumeValuePublisher: AnyPublisher<Double?, Never> =
            self.volumeTextField.eventPublisher
                .map { event -> String? in
                    switch event {
                    case .begin(let stringOrNil),
                        .changedSelection(let stringOrNil),
                         .end(let stringOrNil):
                        return stringOrNil
                    }
                }
                .map { $0?.asVolume }
                .prepend(nil)
                .share()
                .eraseToAnyPublisher()
        
        let inputsPublisher =
            Publishers.CombineLatest(priceValuePublisher, volumeValuePublisher)
        
        let inputValidPublisher: AnyPublisher<Bool, Never> =
            inputsPublisher
                .map { (arg) -> Bool in
                    let (priceOrNil, volumeOrNil) = arg
                    return (priceOrNil ?? 0.0) > 0.0 && (volumeOrNil ?? 0.0) > 0.0
                }
                .share()
                .eraseToAnyPublisher()
        
        self.validInputSub =
            inputsPublisher
                .sink(receiveValue: { (values) in
                    let (priceOrNil, volumeOrNil) = values
                    self.inputSubject.value = (price: priceOrNil, volume: volumeOrNil)
                })
        
        self.tradeButton.isEnabled(inputValidPublisher)
        self.tradeButton.alpha(inputValidPublisher.map { $0 ? 1.0 : 0.5 }.asAny)
        
        let priceValidPub =
            priceValuePublisher
                .map { ($0 ?? 0.0) > 0.0 }
                .share()
        self.priceWarningLabel.isHidden(priceValidPub.asAny)
        self.priceLabel.textColor(priceValidPub.map { $0 ? .label : .systemOrange }.asAny)
        
        let volumeValidPub =
            volumeValuePublisher
                .map { ($0 ?? 0.0) > 0.0 }
                .share()
        
        self.volumeWarningLabel.isHidden(volumeValidPub.asAny)
        self.volumeLabel.textColor(volumeValidPub.map { $0 ? .label : .systemOrange }.asAny)
    }
    
    @IBAction func actionChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            self.action = .buy
        case 1:
            self.action = .sell
        default:
            return
        }
    }
    
    @objc func viewTapped(_ sender: Any) {
        self.priceTextField.resignFirstResponder()
        self.volumeTextField.resignFirstResponder()
    }
    
    @IBAction func previewOrder(_ sender: Any) {
        switch self.viewState {
        case .editing:
            self.previewOrder()
        case .previewing:
            self.submitOrder()
        }
    }
    
    @IBAction func editOrder(_ sender: Any) {
        self.viewState = .editing
    }
    
    func previewOrder() {
        self.viewState = .previewing
        self.priceValueLabel.text = Style.Text.price((self.priceTextField.text ?? "0.0").asPrice)
        self.volumeValueLabel.text = Style.Text.price((self.volumeTextField.text ?? "0.0").asVolume)
        self.priceTextField.resignFirstResponder()
        self.volumeTextField.resignFirstResponder()
    }
    
    var submissionSub: AnyCancellable?
    func submitOrder() {
        guard let price = self.inputSubject.value.price,
            let volume = self.inputSubject.value.volume else {
                return
        }
        self.submissionSub =
            self.endpoint
                .submitOrder(currencyPair: self.state.currencyPair,
                             action: self.action,
                             price: price,
                             volume: volume)
                .receive(on: RunLoop.main)
                .sink(receiveCompletion: { (result) in
                    switch result {
                    case .finished:
                        self.endpoint.done(self)
                    case .failure(let appError):
                        print(appError)
                    }
                }) { (_) in }
    }
}
