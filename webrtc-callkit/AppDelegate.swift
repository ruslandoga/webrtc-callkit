import UIKit

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
    private lazy var rootController: UINavigationController = {
        UINavigationController()
    }()
    
    var window: UIWindow?
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.makeKeyAndVisible()
        window?.rootViewController = rootController
        
        let callVC = CallVC()
        rootController.setViewControllers([callVC], animated: false)
        
        return true
    }
}
