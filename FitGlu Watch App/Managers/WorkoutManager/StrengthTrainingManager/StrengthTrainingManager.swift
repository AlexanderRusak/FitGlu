import Foundation
import HealthKit

class StrengthTrainingManager: ObservableObject {
    private let healthDataManager = HealthDataManager()
    
    @Published var peakThreshold: Int = 150
    @Published var normalThreshold: Int = 100
    @Published var peakCount: Int = 0
    @Published var isReadyForNextSet: Bool = false
    @Published var currentHeartRate: Double = 0.0
    @Published var lastPeakRate: Double = 0.0
    
    private var age: Int?
    private var gender: HKBiologicalSex = .notSet
    
    init() {
        requestAuthorizationAndFetchDetails()
        configureHeartRateMonitoring()
    }
    
    /// Запрос авторизации и получение данных пользователя
    private func requestAuthorizationAndFetchDetails() {
        healthDataManager.requestAuthorization { [weak self] success, error in
            if success {
                DispatchQueue.main.async {
                    self?.age = self?.healthDataManager.age
                    self?.gender = self?.healthDataManager.gender ?? .notSet
                    self?.calculateThresholds()
                    
                    let genderString = self?.genderString(from: self?.gender ?? .notSet) ?? "Unknown"
                    let ageString = self?.age != nil ? String(self!.age!) : "Unknown"
                    print("Данные о пользователе: Пол = \(genderString), Возраст = \(ageString)")
                }
            } else {
                print("Авторизация HealthKit не удалась: \(error?.localizedDescription ?? "Нет информации")")
            }
        }
    }
    
    /// Конвертация HKBiologicalSex в человекочитаемый формат
    private func genderString(from gender: HKBiologicalSex) -> String {
        switch gender {
        case .female: return "Female"
        case .male: return "Male"
        case .other: return "Other"
        default: return "Not set"
        }
    }
    
    /// Пересчет порогов на основе возраста и пола
    private func calculateThresholds() {
        guard let age = age else {
            print("Возраст еще не получен, невозможно рассчитать пороги.")
            return
        }
        
        let maxHeartRate = 220 - age
        let peakMultiplier: Double = (gender == .female) ? 0.85 : 0.90
        let normalMultiplier: Double = (gender == .female) ? 0.55 : 0.60
        
        peakThreshold = Int(Double(maxHeartRate) * peakMultiplier)
        normalThreshold = Int(Double(maxHeartRate) * normalMultiplier)
        
        print("Пороговые значения рассчитаны: peak = \(peakThreshold), normal = \(normalThreshold)")
    }
    
    /// Настройка обработки пульса
    private func configureHeartRateMonitoring() {
        healthDataManager.onHeartRateUpdate = { [weak self] heartRate in
            guard let self = self else { return }
            self.processHeartRate(heartRate)
        }
    }
    
    /// Обработка текущего пульса
    private func processHeartRate(_ heartRate: Double) {
        DispatchQueue.main.async {
            self.currentHeartRate = heartRate
        }

        let genderString = genderString(from: gender)
        let ageString = age != nil ? String(age!) : "Unknown"
        
        // Лог с полом, возрастом и текущим пульсом
        print("Обновление пульса: Пол = \(genderString), Возраст = \(ageString), Текущий пульс = \(heartRate)")

        if heartRate > Double(peakThreshold) {
            DispatchQueue.main.async {
                self.peakCount += 1
                self.lastPeakRate = heartRate
                self.isReadyForNextSet = false
            }
            print("Достигнут пик! Всего пиков: \(peakCount)")
        } else if heartRate <= Double(normalThreshold) {
            DispatchQueue.main.async {
                self.isReadyForNextSet = true
            }
            print("Пульс вернулся к норме. Готов к следующему подходу.")
        }
    }

    /// Запуск мониторинга
    func startMonitoring() {
        print("Начало мониторинга...")
        healthDataManager.setSample(strengthTrainingSample)
        healthDataManager.fetchUserDetails() // Принудительно загружаем данные из сэмпла
        self.age = healthDataManager.age
        self.gender = healthDataManager.gender ?? .notSet
        self.calculateThresholds()
        healthDataManager.startMonitoringHeartRate()
    }
    
    /// Остановка мониторинга
    func stopMonitoring() {
        print("Мониторинг завершен.")
        healthDataManager.stopMonitoringHeartRate()
    }

    /// Метод для тестовых обновлений пульса (если нужно)
    func updateHeartRate(_ heartRate: Double) {
        currentHeartRate = heartRate
        let genderString = genderString(from: gender)
        let ageString = age != nil ? String(age!) : "Unknown"
        print("Обновление пульса вручную: Пол = \(genderString), Возраст = \(ageString), Пульс = \(heartRate)")

        if heartRate > Double(peakThreshold) {
            peakCount += 1
            lastPeakRate = heartRate
            print("Peak detected! Total peaks: \(peakCount)")
        }
    }
}
