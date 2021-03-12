import UIKit
import Anchorage

final class CallVC: UIViewController {
    var service: CallService!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white
        let callButton = UIButton(type: .system)
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
