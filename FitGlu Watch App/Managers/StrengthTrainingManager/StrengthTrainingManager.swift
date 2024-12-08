import Foundation
import HealthKit

class StrengthTrainingManager: ObservableObject {
    private let healthKitManager = HealthKitAuthorizationManager()
    private let heartRateManager = HeartRateManager()
    
    @Published var peakThreshold: Int = 150
    @Published var normalThreshold: Int = 100
    @Published var peakCount: Int = 0
    @Published var isReadyForNextSet: Bool = false
    @Published var currentHeartRate: Double = 0.0
    @Published var lastPeakRate: Double = 0.0
    
    private var age: Int?
    private var gender: HKBiologicalSex = .notSet
    
    init() {
        fetchUserDetails()
        configureHeartRateMonitoring()
    }
    
    /// Получение данных пользователя (возраст и пол)
    private func fetchUserDetails() {
        healthKitManager.fetchAge { [weak self] age in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.age = age
                self.calculateThresholds()
            }
        }
        
        healthKitManager.fetchBiologicalSex { [weak self] biologicalSex in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.gender = biologicalSex ?? .notSet
                self.calculateThresholds()
            }
        }
    }
    
    /// Пересчет порогов на основе возраста и пола
    private func calculateThresholds() {
        guard let age = age else { return } // Ждем, пока возраст будет получен
        
        let maxHeartRate = 220 - age
        let peakMultiplier: Double = (gender == .female) ? 0.85 : 0.90
        let normalMultiplier: Double = (gender == .female) ? 0.55 : 0.60
        
        peakThreshold = Int(Double(maxHeartRate) * peakMultiplier)
        normalThreshold = Int(Double(maxHeartRate) * normalMultiplier)
        
        print("Пороговые значения рассчитаны: peak = \(peakThreshold), normal = \(normalThreshold)")
    }
    
    /// Настройка обработки пульса
    private func configureHeartRateMonitoring() {
        heartRateManager.onHeartRateUpdate = { [weak self] heartRate in
            print("Heart rate updated: \(heartRate)")
            self?.processHeartRate(heartRate)
        }
    }
    
    /// Обработка текущего пульса
    private func processHeartRate(_ heartRate: Double) {
        // Обновляем currentHeartRate
        DispatchQueue.main.async {
            self.currentHeartRate = heartRate
        }

        if heartRate > Double(peakThreshold) {
            DispatchQueue.main.async {
                self.peakCount += 1
                self.lastPeakRate = heartRate
                self.isReadyForNextSet = false
            }
            print("Peak detected! Total peaks: \(peakCount)")
        } else if heartRate <= Double(normalThreshold) {
            DispatchQueue.main.async {
                self.isReadyForNextSet = true
            }
            print("Heart rate restored. Ready for the next set.")
        }
    }

    
    /// Запуск мониторинга
    func startMonitoring() {
        print("Начало мониторинга...")
        heartRateManager.startHeartRateMonitoring()
    }
    
    /// Остановка мониторинга
    func stopMonitoring() {
        print("Мониторинг завершен.")
        heartRateManager.stopHeartRateMonitoring()
    }

    func updateHeartRate(_ heartRate: Double) {
        currentHeartRate = heartRate

        if heartRate > Double(peakThreshold) {
            peakCount += 1
            lastPeakRate = heartRate
            print("Peak detected! Total peaks: \(peakCount)")
        }
    }
}
