import SwiftUI

@main
struct FitGluApp: App {
    init() {
        @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
        // Этот код выполнится при запуске приложения.
        print("iPhone: FitGluApp init — приложение запущено!")
        
        // Если у вас есть класс PhoneConnectivityProvider:
        _ = PhoneConnectivityProvider.shared
        
        GlucoseDataManager.shared.requestAuthorization { success in
            if success {
                GlucoseDataManager.shared.subscribeGlucose()
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}

