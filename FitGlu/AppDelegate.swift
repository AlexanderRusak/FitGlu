import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func applicationDidBecomeActive(_ application: UIApplication) {
        print("✅ AppDelegate: App became active — повторная подписка на глюкозу.")
        GlucoseDataManager.shared.subscribeGlucose()
    }
}
