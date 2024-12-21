import Foundation
import HealthKit

class FatBurningManager: ObservableObject {
    private let zoneManager = HeartRateZoneManager()
    private let healthDataManager = HealthDataManager()

    @Published var currentHeartRate: Double = 0.0
    @Published var age: Int?
    @Published var isWorkoutActive: Bool = false
    @Published var currentZone: String = "Below Target"
        
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
    }

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

    func startWorkout() {
        print("Starting workout...")
        isWorkoutActive = true
        healthDataManager.setSample(fatBurningSample)
        
        // Принудительно снова вызываем fetchUserDetails, чтобы загрузить возраст и пол из сэмпла
        healthDataManager.fetchUserDetails()
        
        DispatchQueue.main.async {
            self.age = self.healthDataManager.age
            let genderString = self.genderString(from: self.healthDataManager.gender ?? .notSet)
            let ageString = self.age != nil ? String(self.age!) : "Unknown"
            print("Сэмпл установлен. Пол = \(genderString), Возраст = \(ageString)")
        }

        healthDataManager.startMonitoringHeartRate()
    }

    func stopWorkout() {
        print("Stopping workout...")
        isWorkoutActive = false
        healthDataManager.stopMonitoringHeartRate()
    }
    
    private func genderString(from gender: HKBiologicalSex) -> String {
        switch gender {
        case .female: return "Female"
        case .male: return "Male"
        case .other: return "Other"
        default: return "Not set"
        }
    }
    
    /// Дополнительный метод для логирования текущего статуса (возраст, пол, пульс, зона)
    private func logCurrentStatus() {
        let genderString = genderString(from: healthDataManager.gender ?? .notSet)
        let ageString = age != nil ? String(age!) : "Unknown"
        print("Текущий статус: Пол = \(genderString), Возраст = \(ageString), Пульс = \(currentHeartRate), Зона = \(currentZone)")
    }
}
