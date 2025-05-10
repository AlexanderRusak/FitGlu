import SwiftUI

@main
struct FitGluApp: App {

    //--- Сервисы
    private let hkAuth = HealthKitAuthorizationManager()

    //--- Инициализация ― выполняется один раз
    init() {
        @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
        print("📱 FitGluApp launched")

        // 📡 Watch-connectivity (если нужен)
        _ = PhoneConnectivityProvider.shared

        // 🔵 Glucose (CGM)
        GlucoseDataManager.shared.requestAuthorization { ok in
            if ok { GlucoseDataManager.shared.subscribeGlucose() }
        }

        // ❤️ Workouts + Heart-Rate
        hkAuth.requestAuthorization { ok, err in
            if ok {
                print("✅ HealthKit authorised (workouts + HR)")
            } else {
                print("❌ HealthKit auth failed:", err?.localizedDescription ?? "-")
            }
        }
    }

    //--- UI
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onAppear {
                    // безопасно обращаться к HealthKit-провайдерам
                    // (авторизация уже запрошена в init)
                }
        }
    }
}
