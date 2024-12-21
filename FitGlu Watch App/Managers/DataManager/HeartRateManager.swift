import HealthKit

class HeartRateManager {
    private let healthStore = HKHealthStore()
    private var query: HKObserverQuery?
    var onHeartRateUpdate: ((Double) -> Void)?

    func startHeartRateMonitoring() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }

        query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, _, error in
            if let error = error {
                print("Ошибка ObserverQuery: \(error.localizedDescription)")
                return
            }
            self?.fetchLatestHeartRate()
        }

        if let query = query {
            healthStore.execute(query)
        }
    }

    func stopHeartRateMonitoring() {
        if let query = query {
            healthStore.stop(query)
            self.query = nil
        }
    }

    private func fetchLatestHeartRate() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }

        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { [weak self] _, samples, error in
            if let error = error {
                print("Ошибка SampleQuery: \(error.localizedDescription)")
                return
            }

            guard let sample = samples?.first as? HKQuantitySample else { return }
            let heartRate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))

            DispatchQueue.main.async {
                self?.onHeartRateUpdate?(heartRate)
            }
        }

        healthStore.execute(query)
    }
}
