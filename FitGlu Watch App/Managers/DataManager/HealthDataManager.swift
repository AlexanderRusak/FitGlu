import Foundation
import HealthKit

class HealthDataManager {
    private let healthKitAuthorizationManager = HealthKitAuthorizationManager()
    private let heartRateManager = HeartRateManager()

    private var currentSample: TrainingSample?
    private var sequenceIterator: AnyIterator<(String, Int, Int)>?
    private var timer: Timer?

    var onHeartRateUpdate: ((Double) -> Void)?
    var age: Int?
    var gender: HKBiologicalSex?

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        #if targetEnvironment(simulator)
        // На симуляторе HealthKit недоступен, просто возвращаем успех
        completion(true, nil)
        #else
        healthKitAuthorizationManager.requestAuthorization { success, error in
            if success {
                self.fetchUserDetails()
            }
            completion(success, error)
        }
        #endif
    }

    func fetchUserDetails() {
        #if !targetEnvironment(simulator)
        // На реальном устройстве получаем данные из HealthKit
        healthKitAuthorizationManager.fetchAge { [weak self] age in
            self?.age = age
        }
        
        healthKitAuthorizationManager.fetchBiologicalSex { [weak self] sex in
            self?.gender = sex
        }
        #else
        // В режиме симулятора берем данные из сэмпла, если он установлен
        if let sample = currentSample {
            self.age = sample.age

            // Конвертируем строку пола из сэмпла в HKBiologicalSex
            let lowerGender = sample.gender.lowercased()
            if lowerGender == "male" {
                self.gender = .male
            } else if lowerGender == "female" {
                self.gender = .female
            } else {
                self.gender = .other
            }
        }
        // Если сэмпла нет, не устанавливаем age и gender, оставляем их nil/неопределёнными
        #endif
    }

    func setSample(_ sample: TrainingSample) {
        self.currentSample = sample
    }

    func startMonitoringHeartRate() {
        #if targetEnvironment(simulator)
        startSimulatedHeartRate()
        #else
        startRealHeartRate()
        #endif
    }

    func stopMonitoringHeartRate() {
        #if targetEnvironment(simulator)
        stopSimulatedHeartRate()
        #else
        stopRealHeartRate()
        #endif
    }

    private func startRealHeartRate() {
        heartRateManager.onHeartRateUpdate = { [weak self] hr in
            self?.onHeartRateUpdate?(hr)
        }
        heartRateManager.startHeartRateMonitoring()
    }

    private func stopRealHeartRate() {
        heartRateManager.stopHeartRateMonitoring()
    }

    private func startSimulatedHeartRate() {
        guard let sample = currentSample else {
            print("Не задан сэмпл для симуляции пульса!")
            return
        }

        sequenceIterator = sample.infiniteHeartRateSequence(step: sample.step).makeIterator()
        
        timer = Timer.scheduledTimer(withTimeInterval: sample.updateInterval, repeats: true) { [weak self] _ in
            guard let self = self, let data = self.sequenceIterator?.next() else { return }
            let (_, _, heartRate) = data
            self.onHeartRateUpdate?(Double(heartRate))
        }
    }
    
    private func stopSimulatedHeartRate() {
        timer?.invalidate()
        timer = nil
        sequenceIterator = nil
    }
}
