import Foundation
import HealthKit

// MARK: — Модели

struct HKWorkoutBundle {
    let workout: HKWorkout                // сама тренировка
    let heartRates: [HKQuantitySample]    // пульс
    let glucose:    [HKQuantitySample]    // глюкоза (может быть пусто)
}

// MARK: — Провайдер

final class HealthKitWorkoutProvider: ObservableObject {

    private let store = HKHealthStore()
    private let hrUnit = HKUnit.count().unitDivided(by: .minute())   // «уд/мин»
    private let glucoseUnit = HKUnit(from: "mg/dL")                  // поменяйте, если нужно
    @Published private(set) var bundles: [WorkoutWithHR] = []

    /// Тренировки и связанные данные за `interval`
    func bundles(in interval: ClosedRange<Date>) async throws -> [HKWorkoutBundle] {

        // 1. Загружаем список HKWorkout
        let workouts = try await fetchWorkouts(from: interval.lowerBound,
                                               to: interval.upperBound)

        // 2. Для каждой тренировки подгружаем HR и Glucose
        var result: [HKWorkoutBundle] = []

        for w in workouts {
            async let hr  = fetchQuantity(
                .heartRate,
                from: w.startDate, to: w.endDate)

            async let gl  = fetchQuantity(
                .bloodGlucose,
                from: w.startDate, to: w.endDate)

            result.append(.init(workout: w,
                                heartRates: try await hr,
                                glucose:    try await gl))
        }
        return result
    }

    // MARK: — Private Fetch helpers

    private func fetchWorkouts(from start: Date, to end: Date) async throws -> [HKWorkout] {
        try await withCheckedThrowingContinuation { cont in
            let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            let q = HKSampleQuery(sampleType: .workoutType(), predicate: pred,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: sort) { _, samples, err in
                if let err { cont.resume(throwing: err) }
                else { cont.resume(returning: samples as? [HKWorkout] ?? []) }
            }
            store.execute(q)
        }
    }

    private func fetchQuantity(_ id: HKQuantityTypeIdentifier,
                               from start: Date, to end: Date) async throws -> [HKQuantitySample] {

        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return [] }
        return try await withCheckedThrowingContinuation { cont in
            let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let q = HKSampleQuery(sampleType: type, predicate: pred,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, err in
                if let err { cont.resume(throwing: err) }
                else { cont.resume(returning: samples as? [HKQuantitySample] ?? []) }
            }
            store.execute(q)
        }
    }
}

extension HealthKitWorkoutProvider {

    /// Все HR-сэмплы в заданном диапазоне (например, сутки).
    /// - Parameter range: [start, end] – обычно `00:00…23:59` дня
    /// - Returns: Отсортированный по времени массив `HKQuantitySample`
    func dailyHeartRates(in range: ClosedRange<Date>) async throws -> [HKQuantitySample] {

        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: range.lowerBound,
            end:       range.upperBound,
            options:   .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate:  predicate,
                limit:      HKObjectQueryNoLimit,
                sortDescriptors: [
                    NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
                ]
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else {
                    let list = samples as? [HKQuantitySample] ?? []
                    continuation.resume(returning: list)
                }
            }
            self.store.execute(query)
        }
    }
}
