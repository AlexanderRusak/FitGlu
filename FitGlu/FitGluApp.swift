import SwiftUI

@main
struct FitGluApp: App {
    init() {
        // Этот код выполнится при запуске приложения.
        print("iPhone: FitGluApp init — приложение запущено!")
        
        // Если у вас есть класс PhoneConnectivityProvider:
        _ = PhoneConnectivityProvider.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
