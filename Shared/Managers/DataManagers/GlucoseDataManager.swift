import HealthKit

class GlucoseDataManager {
    static let shared = GlucoseDataManager()
    private let healthStore = HKHealthStore()
    private var observerQuery: HKObserverQuery?

    private let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose)!

    // Запрос авторизации
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }
        healthStore.requestAuthorization(toShare: [], read: [glucoseType]) { success, error in
            if success {
                print("✅ iPhone: Глюкоза - разрешение получено.")
            } else {
                print("❌ iPhone: нет доступа к глюкозе: \(error?.localizedDescription ?? "")")
            }
            completion(success)
        }
    }

    // Подписка (ObserverQuery)
    func subscribeGlucose() {
        guard observerQuery == nil else {
            print("ℹ️ Уже подписаны на глюкозу.")
            return
        }
        
        let query = HKObserverQuery(sampleType: glucoseType, predicate: nil) {
            [weak self] _, completionHandler, error in
            if let error = error {
                print("❌ Ошибка ObserverQuery: \(error)")
                completionHandler()
                return
            }
            print("🔄 iPhone: Получили уведомление об обновлении глюкозы.")
            self?.fetchLatestGlucose()
            completionHandler()
        }
        
        healthStore.execute(query)
        observerQuery = query
        print("✅ iPhone: Подписаны на глюкозу.")
        
        // 🔁 Важно для фоновой доставки!
        healthStore.enableBackgroundDelivery(for: glucoseType, frequency: .immediate) { success, error in
            if success {
                print("✅ Background delivery enabled for glucose")
            } else {
                print("❌ Failed to enable background delivery: \(error?.localizedDescription ?? "")")
            }
        }
    }

    // Выборка данных
    func fetchLatestGlucose() {
        let start = Date(timeIntervalSinceNow: -24 * 3600)
        let pred = HKQuery.predicateForSamples(withStart: start, end: nil, options: .strictStartDate)

        let q = HKSampleQuery(sampleType: glucoseType, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: nil) {
            _, samples, error in
            guard let samples = samples as? [HKQuantitySample], error == nil else {
                print("❌ Ошибка fetchLatestGlucose: \(error?.localizedDescription ?? "")")
                return
            }
            let mgdlUnit = HKUnit(from: "mg/dL")
            for s in samples {
                let val = s.quantity.doubleValue(for: mgdlUnit)
                let ts = s.startDate.timeIntervalSince1970
                GlucoseLogDBManager.shared.insertGlucose(timestamp: ts, value: val)
            }
            print("💉 iPhone: Сохранили \(samples.count) точек глюкозы в локальную БД.")
        }
        healthStore.execute(q)
    }
}
