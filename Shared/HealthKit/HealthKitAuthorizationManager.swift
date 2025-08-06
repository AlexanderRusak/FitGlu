import Foundation
import HealthKit

final class HealthKitAuthorizationManager: ObservableObject {
    private let healthStore = HKHealthStore()

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, NSError(domain: "HealthKit",
                                      code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: "HealthKit недоступен"]))
            return
        }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .bloodGlucose)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!, // kcal
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,           // (на будущее)
            HKObjectType.characteristicType(forIdentifier: .biologicalSex)!,
            HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!
        ]

        healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
            completion(success, error)
        }
    }

    func fetchAge(completion: @escaping (Int?) -> Void) {
        do {
            let birth = try healthStore.dateOfBirthComponents()
            guard let year = birth.year else { completion(nil); return }
            let nowYear = Calendar.current.component(.year, from: Date())
            completion(nowYear - year)
        } catch {
            print("Ошибка получения возраста: \(error.localizedDescription)")
            completion(nil)
        }
    }

    func fetchBiologicalSex(completion: @escaping (HKBiologicalSex?) -> Void) {
        do {
            completion(try healthStore.biologicalSex().biologicalSex)
        } catch {
            print("Ошибка получения пола: \(error.localizedDescription)")
            completion(nil)
        }
    }
}
