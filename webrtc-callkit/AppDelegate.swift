import UIKit
import SwiftPhoenixClient

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
    private lazy var rootController: UINavigationController = {
        UINavigationController()
    }()
    
    var window: UIWindow?
    private var socket: Socket?
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.makeKeyAndVisible()
        window?.rootViewController = rootController

        let callVC = CallVC()
        callVC.service = makeCallService()
        rootController.setViewControllers([callVC], animated: false)
        rootController.isNavigationBarHidden = true
        
        return true
    }
    
//    func applicationDidEnterBackground(_ application: UIApplication) {
//        socket?.disconnect()
//    }
//
//    func applicationWillEnterForeground(_ application: UIApplication) {
//        socket?.connect()
//    }
    
    private func makeCallService() -> CallService {
        let me = UUID(uuidString: "00000177-8336-5e0e-0242-ac1100030000")!
        
        socket = Socket("http://192.168.1.131:4000/api/socket",
                            params: ["token": "qLgIwVlnThoVUUPrOnDVX4Qa7bf9UHckAUXLRcW0j8o"])
        
        socket?.logger = { msg in print("LOG:", msg) }
        socket?.onOpen { print("socket connected") }
        socket?.onClose { print("socket disconnected") }
        socket?.onError { error in print("socket error", error) }
        
        return CallService(socket: socket!, me: me)
    }
}
