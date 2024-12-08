import Foundation
import HealthKit

class HealthKitAuthorizationManager: ObservableObject {
    private let healthStore = HKHealthStore()

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, NSError(domain: "HealthKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "HealthKit недоступен"]))
            return
        }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!, // Частота сердечных сокращений
            HKObjectType.characteristicType(forIdentifier: .biologicalSex)!, // Биологический пол
            HKObjectType.characteristicType(forIdentifier: .dateOfBirth)! // Дата рождения
        ]

        healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
            if success {
                print("Авторизация HealthKit успешна.")
            } else if let error = error {
                print("Ошибка авторизации HealthKit: \(error.localizedDescription)")
            } else {
                print("Авторизация отклонена пользователем.")
            }
        }

    }

    func fetchAge(completion: @escaping (Int?) -> Void) {
        do {
            let birthDate = try healthStore.dateOfBirthComponents()
            let calendar = Calendar.current
            let now = Date()
            if let birthYear = birthDate.year {
                let age = calendar.component(.year, from: now) - birthYear
                completion(age)
            } else {
                completion(nil)
            }
        } catch {
            print("Ошибка получения возраста: \(error.localizedDescription)")
            completion(nil)
        }
    }
    
    func fetchBiologicalSex(completion: @escaping (HKBiologicalSex?) -> Void) {
        do {
            let biologicalSex = try healthStore.biologicalSex().biologicalSex
            completion(biologicalSex)
        } catch {
            print("Ошибка получения пола: \(error.localizedDescription)")
            completion(nil)
        }
    }
}
