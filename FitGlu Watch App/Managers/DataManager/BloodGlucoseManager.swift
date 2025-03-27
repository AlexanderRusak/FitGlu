import HealthKit

class BloodGlucoseManager {
    private let healthStore = HKHealthStore()
    private var observerQuery: HKObserverQuery?
    
    /// Коллбэк для уведомления о поступивших данных
    var onBloodGlucoseUpdate: ((Double) -> Void)?
    
    /// Запуск мониторинга глюкозы (через ObserverQuery)
    func startBloodGlucoseMonitoring() {
        guard let bloodGlucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else {
            return
        }
        
        // ObserverQuery, которая уведомляет нас при добавлении в HealthKit новых данных глюкозы
        observerQuery = HKObserverQuery(sampleType: bloodGlucoseType, predicate: nil) { [weak self] _, completionHandler, error in
            if let error = error {
                print("Ошибка ObserverQuery: \(error.localizedDescription)")
                completionHandler()
                return
            }
            
            // Когда в HealthKit появились новые данные, запрашиваем последнее измерение
            self?.fetchLatestBloodGlucose()
            
            // Вызываем completionHandler, чтобы сообщить HK, что обработка завершена
            completionHandler()
        }
        
        if let observerQuery = observerQuery {
            healthStore.execute(observerQuery)
        }
    }
    
    /// Остановка мониторинга
    func stopBloodGlucoseMonitoring() {
        if let observerQuery = observerQuery {
            healthStore.stop(observerQuery)
            self.observerQuery = nil
        }
    }
    
    /// Запрашиваем последнее (самое свежее) измерение глюкозы
    private func fetchLatestBloodGlucose() {
        guard let bloodGlucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else {
            return
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: bloodGlucoseType,
                                  predicate: nil,
                                  limit: 1,
                                  sortDescriptors: [sortDescriptor]) { [weak self] _, samples, error in
            if let error = error {
                print("Ошибка SampleQuery: \(error.localizedDescription)")
                return
            }
            
            guard let sample = samples?.first as? HKQuantitySample else { return }
            
            // В HealthKit глюкоза может храниться в разных единицах: ммоль/л или мг/дл.
            // Для простоты возьмём mg/dL. Если нужно ммоль/л, укажите "mmol/L".
            let glucoseValue = sample.quantity.doubleValue(for: HKUnit(from: "mg/dL"))
            
            DispatchQueue.main.async {
                self?.onBloodGlucoseUpdate?(glucoseValue)
            }
        }
        
        healthStore.execute(query)
    }
}
