import Foundation
import HealthKit

class FatBurningManager: ObservableObject {
    private let zoneManager = HeartRateZoneManager()
    private let healthDataManager = HealthDataManager()

    @Published var currentHeartRate: Double = 0.0
    @Published var age: Int?
    @Published var isWorkoutActive: Bool = false
    @Published var currentZone: String = "Below Target"

    // NEW: Глюкоза — текущее значение (для отображения в UI, если нужно)
    @Published var currentGlucose: Double = 0.0

    init() {
        print("FatBurningManager initialized.")
        healthDataManager.requestAuthorization { [weak self] success, error in
            if success {
                self?.healthDataManager.fetchUserDetails()
                DispatchQueue.main.async {
                    self?.age = self?.healthDataManager.age
                    let genderString = self?.genderString(from: self?.healthDataManager.gender ?? .notSet) ?? "Unknown"
                    let ageString = self?.age != nil ? String(self!.age!) : "Unknown"
                    print("Данные о пользователе: Пол = \(genderString), Возраст = \(ageString)")
                }
            } else {
                print("Не удалось авторизоваться: \(error?.localizedDescription ?? "Нет информации")")
            }
        }
        configureHeartRateMonitoring()
        configureBloodGlucoseMonitoring() // NEW: Настраиваем подписку на глюкозу
    }

    // MARK: - Настройка мониторинга пульса
    private func configureHeartRateMonitoring() {
        print("Configuring heart rate monitoring...")
        healthDataManager.onHeartRateUpdate = { [weak self] heartRate in
            print("Heart rate received: \(heartRate)")
            DispatchQueue.main.async {
                self?.currentHeartRate = heartRate
                self?.logCurrentStatus()
                self?.updateZone(for: heartRate)
            }
        }
    }

    // MARK: - Настройка мониторинга глюкозы (NEW)
    private func configureBloodGlucoseMonitoring() {
        print("Configuring blood glucose monitoring...")
        healthDataManager.onBloodGlucoseUpdate = { [weak self] glucoseValue in
            print("Blood glucose received: \(glucoseValue)")
            DispatchQueue.main.async {
                self?.currentGlucose = glucoseValue
                self?.logCurrentStatusGlucose()
                // Здесь можно добавить дополнительную аналитику, логику и т.д.
            }
        }
    }

    private func updateZone(for heartRate: Double) {
        print("Updating zone for heart rate: \(heartRate)")
        guard let age = age else {
            print("Age is not available yet.")
            return
        }
        
        zoneManager.updateZone(for: heartRate, age: age, trainingType: .fatBurning) { [weak self] (newZone: HeartRateZone) in
            print("New zone received: \(newZone)")
            DispatchQueue.main.async {
                self?.currentZone = "\(newZone)"
                print("Zone updated to: \(self?.currentZone ?? "Unknown")")
            }
        }
    }

    // MARK: - Управление «Жиросжигающей тренировки»
    
    func startWorkout() {
        print("Starting workout...")
        isWorkoutActive = true
        
        // 1. Устанавливаем сэмпл для пульса (в режиме симулятора)
        healthDataManager.setSample(fatBurningSample)
        
        // 2. Устанавливаем сэмпл для глюкозы (в режиме симулятора) (NEW)
        healthDataManager.setGlucoseSample(glucoseSample)

        // 3. Принудительно обновляем возраст/пол
        healthDataManager.fetchUserDetails()
        DispatchQueue.main.async {
            self.age = self.healthDataManager.age
            let genderString = self.genderString(from: self.healthDataManager.gender ?? .notSet)
            let ageString = self.age != nil ? String(self.age!) : "Unknown"
            print("Сэмплы установлены. Пол = \(genderString), Возраст = \(ageString)")
        }

        // 4. Старт мониторинга (реальные данные или симуляция)
        healthDataManager.startMonitoringHeartRate()
        healthDataManager.startMonitoringBloodGlucose() // NEW
    }

    func stopWorkout() {
        print("Stopping workout...")
        isWorkoutActive = false
        healthDataManager.stopMonitoringHeartRate()
        healthDataManager.stopMonitoringBloodGlucose() // NEW
    }
    
    // MARK: - Вспомогательные методы
    
    private func genderString(from gender: HKBiologicalSex) -> String {
        switch gender {
        case .female: return "Female"
        case .male: return "Male"
        case .other: return "Other"
        default: return "Not set"
        }
    }
    
    /// Лог текущего статуса (пульс)
    private func logCurrentStatus() {
        let genderString = genderString(from: healthDataManager.gender ?? .notSet)
        let ageString = age != nil ? String(age!) : "Unknown"
        print("Текущий статус (пульс): Пол = \(genderString), Возраст = \(ageString), Пульс = \(currentHeartRate), Зона = \(currentZone)")
    }

    /// Лог текущего статуса (глюкоза)
    private func logCurrentStatusGlucose() {
        let genderString = genderString(from: healthDataManager.gender ?? .notSet)
        let ageString = age != nil ? String(age!) : "Unknown"
        print("Текущий статус (глюкоза): Пол = \(genderString), Возраст = \(ageString), Глюкоза = \(currentGlucose)")
    }
}
