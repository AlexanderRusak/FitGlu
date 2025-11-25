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
            
            HKObjectType.quantityType(forIdentifier: .stepCount)!,             // шаги
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,         // сон
            HKObjectType.quantityType(forIdentifier: .dietaryProtein)!,        // белок (г)
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,   // пульс в покое
            HKObjectType.quantityType(forIdentifier: .leanBodyMass)!,    // мышечная масса
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!, // жир %
            
            HKObjectType.characteristicType(forIdentifier: .biologicalSex)!,
            HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!
        ]

        healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
            completion(success, error)
        }
    }
    
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            self.requestAuthorization { success, error in
                if let error = error {
                    print("HealthKit authorization error:", error.localizedDescription)
                }
                continuation.resume(returning: success)
            }
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
    
    // MARK: - Async wrapper
    func fetchTodayMetrics() async -> HealthKitDailyData {
        async let steps = fetchSteps()
        async let sleep = fetchSleepMinutes()
        async let hrRest = fetchRestingHR()
        async let protein = fetchProtein()
        async let weight = fetchWeight()
        async let energy = fetchEnergy()
        async let lean = fetchLeanMass()
        async let fat = fetchBodyFatPercent()

        return await HealthKitDailyData(
            steps: steps,
            sleepMinutes: sleep,
            restingHR: hrRest,
            proteinG: protein,
            weightKg: weight,
            kcal: energy,
            leanMassKg: lean,
            fatPercent: fat
        )
    }

    // MARK: - Steps
    private func fetchSteps() async -> Int {
        await withCheckedContinuation { continuation in
            let type = HKQuantityType.quantityType(forIdentifier: .stepCount)!
            let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: Date()), end: Date(), options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let value = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(value))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Sleep
    private func fetchSleepMinutes() async -> Int {
        await withCheckedContinuation { continuation in
            let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
            let calendar = Calendar.current
            let now = Date()

            // Берём сон, который закончился сегодня утром (до полудня)
            let startOfToday = calendar.startOfDay(for: now)
            let noonToday = calendar.date(byAdding: .hour, value: 12, to: startOfToday)!

            // Диапазон с 18:00 вчера до 12:00 сегодня
            let startOfYesterdayEvening = calendar.date(byAdding: .hour, value: -6, to: startOfToday)!

            let predicate = HKQuery.predicateForSamples(
                withStart: startOfYesterdayEvening,
                end: noonToday,
                options: .strictStartDate
            )

            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                    continuation.resume(returning: 0)
                    return
                }

                // Берём только фазы сна
                let sleepSeconds = samples
                    .filter { sample in
                        sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                    }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

                let minutes = Int(sleepSeconds / 60)
                continuation.resume(returning: minutes)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Resting HR
    private func fetchRestingHR() async -> Int {
        await withCheckedContinuation { continuation in
            let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: 55)
                    return
                }
                let value = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: Int(value))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Protein
    private func fetchProtein() async -> Int {
        await withCheckedContinuation { continuation in
            let type = HKQuantityType.quantityType(forIdentifier: .dietaryProtein)!
            let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: Date()), end: Date(), options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let value = result?.sumQuantity()?.doubleValue(for: .gram()) ?? 0
                continuation.resume(returning: Int(value))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Weight
    private func fetchWeight() async -> Double? {
        await withCheckedContinuation { continuation in
            let type = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let kg = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                continuation.resume(returning: kg)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Active Energy
    private func fetchEnergy() async -> Double {
        await withCheckedContinuation { continuation in
            let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
            let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: Date()), end: Date(), options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let value = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchLeanMass() async -> Double? {
        await withCheckedContinuation { continuation in
            let type = HKQuantityType.quantityType(forIdentifier: .leanBodyMass)!
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let kg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: kg)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Body fat %
    private func fetchBodyFatPercent() async -> Double? {
        await withCheckedContinuation { continuation in
            let type = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let percent = sample.quantity.doubleValue(for: .percent()) * 100
                continuation.resume(returning: percent)
            }
            healthStore.execute(query)
        }
    }
    
    func fetchYesterdayProteinG() async -> Int {
        await withCheckedContinuation { continuation in
            let start = Calendar.current.date(byAdding: .day, value: -1, to: Date())!.startOfDay
            let end   = Calendar.current.startOfDay(for: Date())

            let type = HKQuantityType.quantityType(forIdentifier: .dietaryProtein)!
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

            let query = HKStatisticsQuery(quantityType: type,
                                          quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { _, result, _ in
                let total = result?.sumQuantity()?.doubleValue(for: .gram()) ?? 0
                continuation.resume(returning: Int(total.rounded()))
            }
            HKHealthStore().execute(query)
        }
    }


}

extension HKBiologicalSex {
    var stringValue: String {
        switch self {
        case .male: return "male"
        case .female: return "female"
        case .other: return "other"
        case .notSet: return "unknown"
        @unknown default: return "unknown"
        }
    }
}

struct HealthKitDailyData {
    let steps: Int
    let sleepMinutes: Int
    let restingHR: Int
    let proteinG: Int
    let weightKg: Double?
    let kcal: Double
    let leanMassKg: Double?
    let fatPercent: Double?
}
