import UIKit
import Anchorage

final class CallVC: UIViewController {
    var service: CallService!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let callButton = UIButton(type: .system)
        
        service.subscribe { [unowned callButton] event in
            switch event {
            case let .callStateChange(state):
                switch state {
                case .none:
                    callButton.setTitle("call", for: .normal)
                case let .calling(mate: _):
                    callButton.setTitle("calling", for: .normal)
                case let .called(mate: _):
                    callButton.setTitle("called", for: .normal)
                case let .pickedUp(mate: _):
                    callButton.setTitle("picked", for: .normal)
                }
            }
        }

        view.backgroundColor = .white
        
        callButton.addTarget(self, action: #selector(callTapped), for: .touchUpInside)
        callButton.setTitle("call", for: .normal)
        callButton.backgroundColor = .green
        callButton.layer.cornerRadius = 30
        callButton.heightAnchor == 60
        callButton.widthAnchor == 60
        callButton.tintColor = .black
        
        view.addSubview(callButton)
        callButton.centerAnchors == view.centerAnchors
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        service.start()
    }

    @objc private func callTapped() {
        service.call()
    }
}
