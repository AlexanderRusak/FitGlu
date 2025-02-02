import Foundation
import HealthKit

class FatBurningManager: ObservableObject {
    private let zoneManager = HeartRateZoneManager()
    private let healthDataManager = HealthDataManager()
    
    // Параметры UI / состояния
    @Published var currentHeartRate: Double = 0.0
    @Published var age: Int?
    @Published var isWorkoutActive: Bool = false
    @Published var currentZone: String = "Below Target"
    @Published var currentGlucose: Double = 0.0
    
    // Вместо хранения двух менеджеров —
    // используем единый сервис (фасад).
    private let workoutLogService = WorkoutLogService()
    
    // Текущее trainingID (из таблицы training_log)
    private var currentLogID: Int64?

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
                
                // NEW: Если тренировка активна, записываем пульс в БД через WorkoutLogService
                if let logID = self?.currentLogID, self?.isWorkoutActive == true {
                    self?.workoutLogService.recordHeartRate(trainingID: logID,
                                                            hrValue: Int(heartRate))
                }
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
    
    // MARK: - Управление тренировкой Fat Burning
    func startWorkout() {
        print("Starting Fat Burning workout...")
        isWorkoutActive = true
        
        // 1. Вызываем сервис (startWorkout), получаем trainingID
        let newID = workoutLogService.startWorkout(type: .fatBurning)
        currentLogID = newID
        
        // 2. Настройка HealthDataManager (симуляции или реальных данных)
        healthDataManager.setSample(fatBurningSample)
        healthDataManager.setGlucoseSample(glucoseSample)
        
        // 3. Обновляем возраст/пол
        healthDataManager.fetchUserDetails()
        DispatchQueue.main.async {
            self.age = self.healthDataManager.age
            let genderString = self.genderString(from: self.healthDataManager.gender ?? .notSet)
            let ageString = self.age != nil ? String(self.age!) : "Unknown"
            print("Сэмплы установлены. Пол = \(genderString), Возраст = \(ageString)")
        }

        // 4. Запуск мониторинга
        healthDataManager.startMonitoringHeartRate()
        healthDataManager.startMonitoringBloodGlucose()
    }

    func stopWorkout() {
        print("Stopping Fat Burning workout...")
        isWorkoutActive = false
        
        // 1. Завершаем запись в БД, если есть
        if let logID = currentLogID {
            workoutLogService.stopWorkout(trainingID: logID)
            
            // Для отладки: посмотрим, что у нас в БД по этой тренировке
            workoutLogService.debugPrintAll(for: logID)
            
            // Сбрасываем
            currentLogID = nil
        }
        
        // 2. Остановка HealthKit мониторинга
        healthDataManager.stopMonitoringHeartRate()
        healthDataManager.stopMonitoringBloodGlucose()
        TrainingLogDBManager.shared.syncAllUnSynced()
    }

    // MARK: - Логика зон
    private func updateZone(for heartRate: Double) {
        guard let age = age else {
            print("Age is not available yet.")
            return
        }
        zoneManager.updateZone(for: heartRate, age: age, trainingType: .fatBurning) { [weak self] (newZone: HeartRateZone) in
            DispatchQueue.main.async {
                self?.currentZone = "\(newZone)"
                print("Zone updated to: \(self?.currentZone ?? "Unknown")")
            }
        }
    }

    // MARK: - Логирование статуса (пульс, глюкоза)
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
