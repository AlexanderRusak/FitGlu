import Foundation
import HealthKit

class FatBurningManager: ObservableObject {
    private let zoneManager = HeartRateZoneManager()
    private let healthDataManager = HealthDataManager()

    @Published var currentHeartRate: Double = 0.0
    @Published var age: Int?
    @Published var isWorkoutActive: Bool = false
    @Published var currentZone: String = "Below Target"
    @Published var currentGlucose: Double = 0.0
    
    // MARK: - Добавляем лог-менеджер
    private let logManager = TrainingLogDBManager()
    private var currentLogID: Int64?   // ID записи в БД для текущей тренировки

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
        configureBloodGlucoseMonitoring()
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

    // MARK: - Настройка мониторинга глюкозы
    private func configureBloodGlucoseMonitoring() {
        print("Configuring blood glucose monitoring...")
        healthDataManager.onBloodGlucoseUpdate = { [weak self] glucoseValue in
            print("Blood glucose received: \(glucoseValue)")
            DispatchQueue.main.async {
                self?.currentGlucose = glucoseValue
                self?.logCurrentStatusGlucose()
            }
        }
    }

    // MARK: - Управление тренировкой «Fat Burning»
    
    func startWorkout() {
        print("Starting workout...")
        isWorkoutActive = true
        
        // 1. Логируем старт в DB
        let newID = logManager.startTraining(type: .fatBurning) // <-- Вызываем
        currentLogID = newID
        
        // 2. Устанавливаем сэмпл для пульса
        healthDataManager.setSample(fatBurningSample)
        
        // 3. Устанавливаем сэмпл для глюкозы
        healthDataManager.setGlucoseSample(glucoseSample)

        // 4. Принудительно обновляем возраст/пол
        healthDataManager.fetchUserDetails()
        DispatchQueue.main.async {
            self.age = self.healthDataManager.age
            let genderString = self.genderString(from: self.healthDataManager.gender ?? .notSet)
            let ageString = self.age != nil ? String(self.age!) : "Unknown"
            print("Сэмплы установлены. Пол = \(genderString), Возраст = \(ageString)")
        }

        // 5. Старт мониторинга
        healthDataManager.startMonitoringHeartRate()
        healthDataManager.startMonitoringBloodGlucose()
    }

    func stopWorkout() {
        print("Stopping workout...")
        isWorkoutActive = false
        
        if let logID = currentLogID {
            logManager.finishTraining(id: logID)
            currentLogID = nil
            
            // Сразу после завершения посмотрим список
            logManager.printAllTrainings() // <-- вызов
        }
        
        healthDataManager.stopMonitoringHeartRate()
        healthDataManager.stopMonitoringBloodGlucose()
    }

    
    // MARK: - Доп. логика зоны
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

    // MARK: - Вспомогательные методы
    
    private func genderString(from gender: HKBiologicalSex) -> String {
        switch gender {
        case .female: return "Female"
        case .male: return "Male"
        case .other: return "Other"
        default: return "Not set"
        }
    }
    
    private func logCurrentStatus() {
        let genderString = genderString(from: healthDataManager.gender ?? .notSet)
        let ageString = age != nil ? String(age!) : "Unknown"
        print("Текущий статус (пульс): Пол = \(genderString), Возраст = \(ageString), Пульс = \(currentHeartRate), Зона = \(currentZone)")
    }

    private func logCurrentStatusGlucose() {
        let genderString = genderString(from: healthDataManager.gender ?? .notSet)
        let ageString = age != nil ? String(age!) : "Unknown"
        print("Текущий статус (глюкоза): Пол = \(genderString), Возраст = \(ageString), Глюкоза = \(currentGlucose)")
    }
}
