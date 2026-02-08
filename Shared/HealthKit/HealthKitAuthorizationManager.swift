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
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,

            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .dietaryProtein)!,
            HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .leanBodyMass)!,
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!,

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

    // MARK: - Public (new): metrics for конкретный день

    /// ✅ Основной метод для DailyCoach: метрики строго за выбранный день.
    func fetchMetrics(for day: Date) async -> HealthKitDailyData {
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)! // end of day (exclusive)

        async let steps = fetchSteps(from: start, to: end)
        async let sleep = fetchSleepMinutes(forDay: day) // сон: вечер предыдущего + утро day
        async let hrRest = fetchRestingHR(from: start, to: end)
        async let protein = fetchProtein(from: start, to: end)
        async let energy = fetchEnergy(from: start, to: end)
        async let kcalTotal = fetchDietaryEnergyTotal(from: start, to: end)

        // “последнее значение на момент end”
        async let weight = fetchWeight(latestUpTo: end)
        async let lean = fetchLeanMass(latestUpTo: end)
        async let fat = fetchBodyFatPercent(latestUpTo: end)

        return await HealthKitDailyData(
            steps: steps,
            sleepMinutes: sleep,
            restingHR: hrRest,
            proteinG: protein,
            weightKg: weight,
            kcal: energy,
            kcalTotal: kcalTotal,
            hasKcalTotal: kcalTotal != nil,
            leanMassKg: lean,
            fatPercent: fat
        )
    }

    /// ✅ Белок за конкретный день (в граммах, cumulativeSum)
    func fetchProteinGrams(for day: Date) async -> Int {
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        return await fetchProtein(from: start, to: end)
    }

    /// ✅ Resting HR за конкретный день (берём последнее значение в пределах дня; если нет — fallback)
    func fetchRestingHR(for day: Date) async -> Int {
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        return await fetchRestingHR(from: start, to: end)
    }

    // MARK: - Backward compatible: today wrappers

    /// Старый метод оставляем, чтобы ничего не ломать.
    func fetchTodayMetrics() async -> HealthKitDailyData {
        await fetchMetrics(for: Date())
    }

    /// Старый метод оставляем, но теперь корректно использует healthStore (не создаёт новый).
    func fetchYesterdayProteinG() async -> Int {
        let day = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        return await fetchProteinGrams(for: day)
    }

    // MARK: - Private helpers (range-based)

    // Steps (cumulative sum in range)
    private func fetchSteps(from start: Date, to end: Date) async -> Int {
        await withCheckedContinuation { continuation in
            let type = HKQuantityType.quantityType(forIdentifier: .stepCount)!
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

            let query = HKStatisticsQuery(quantityType: type,
                                          quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { _, result, _ in
                let value = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(value.rounded()))
            }
            healthStore.execute(query)
        }
    }

    // Sleep minutes (18:00 предыдущего дня -> 12:00 выбранного дня)
    private func fetchSleepMinutes(forDay day: Date) async -> Int {
        await withCheckedContinuation { continuation in
            let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
            let calendar = Calendar.current

            let startOfDay = calendar.startOfDay(for: day)
            let noon = calendar.date(byAdding: .hour, value: 12, to: startOfDay)!
            // 18:00 предыдущего дня:
            let startPrevEvening = calendar.date(byAdding: .hour, value: -6, to: startOfDay)!

            let predicate = HKQuery.predicateForSamples(
                withStart: startPrevEvening,
                end: noon,
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

                let sleepSeconds = samples
                    .filter { sample in
                        sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                    }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

                continuation.resume(returning: Int((sleepSeconds / 60.0).rounded()))
            }

            healthStore.execute(query)
        }
    }

    // Resting HR: последнее значение в диапазоне (если нет — fallback 55)
    private func fetchRestingHR(from start: Date, to end: Date) async -> Int {
        await withCheckedContinuation { continuation in
            let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

            let query = HKSampleQuery(sampleType: type,
                                      predicate: predicate,
                                      limit: 1,
                                      sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: 55)
                    return
                }
                let value = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: Int(value.rounded()))
            }
            healthStore.execute(query)
        }
    }

    // Protein: cumulative sum in range
    private func fetchProtein(from start: Date, to end: Date) async -> Int {
        await withCheckedContinuation { continuation in
            let type = HKQuantityType.quantityType(forIdentifier: .dietaryProtein)!
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

            let query = HKStatisticsQuery(quantityType: type,
                                          quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { _, result, _ in
                let value = result?.sumQuantity()?.doubleValue(for: .gram()) ?? 0
                continuation.resume(returning: Int(value.rounded()))
            }
            healthStore.execute(query)
        }
    }

    // Active energy: cumulative sum in range
    private func fetchEnergy(from start: Date, to end: Date) async -> Double {
        await withCheckedContinuation { continuation in
            let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

            let query = HKStatisticsQuery(quantityType: type,
                                          quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { _, result, _ in
                let value = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    // Dietary total energy (kcal): cumulative sum in range.
    // Returns nil when nutrition data is unavailable.
    private func fetchDietaryEnergyTotal(from start: Date, to end: Date) async -> Int? {
        await withCheckedContinuation { continuation in
            let type = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed)!
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

            let query = HKStatisticsQuery(quantityType: type,
                                          quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { _, result, error in
                if error != nil {
                    continuation.resume(returning: nil)
                    return
                }
                guard let sum = result?.sumQuantity() else {
                    continuation.resume(returning: nil)
                    return
                }
                let value = sum.doubleValue(for: .kilocalorie())
                continuation.resume(returning: Int(value.rounded()))
            }
            healthStore.execute(query)
        }
    }

    // Latest weight sample up to endDate
    private func fetchWeight(latestUpTo endDate: Date) async -> Double? {
        await fetchLatestQuantitySample(
            identifier: .bodyMass,
            unit: .gramUnit(with: .kilo),
            latestUpTo: endDate
        )
    }

    private func fetchLeanMass(latestUpTo endDate: Date) async -> Double? {
        await fetchLatestQuantitySample(
            identifier: .leanBodyMass,
            unit: .gramUnit(with: .kilo),
            latestUpTo: endDate
        )
    }

    private func fetchBodyFatPercent(latestUpTo endDate: Date) async -> Double? {
        await withCheckedContinuation { continuation in
            let type = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!
            let predicate = HKQuery.predicateForSamples(withStart: nil, end: endDate, options: .strictEndDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

            let query = HKSampleQuery(sampleType: type,
                                      predicate: predicate,
                                      limit: 1,
                                      sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let percent = sample.quantity.doubleValue(for: .percent()) * 100.0
                continuation.resume(returning: percent)
            }
            healthStore.execute(query)
        }
    }

    private func fetchLatestQuantitySample(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        latestUpTo endDate: Date
    ) async -> Double? {
        await withCheckedContinuation { continuation in
            let type = HKQuantityType.quantityType(forIdentifier: identifier)!
            let predicate = HKQuery.predicateForSamples(withStart: nil, end: endDate, options: .strictEndDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

            let query = HKSampleQuery(sampleType: type,
                                      predicate: predicate,
                                      limit: 1,
                                      sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let value = sample.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
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
    let kcalTotal: Int?
    let hasKcalTotal: Bool
    let leanMassKg: Double?
    let fatPercent: Double?
}
