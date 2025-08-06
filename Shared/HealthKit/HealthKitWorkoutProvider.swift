import Foundation
import HealthKit

// MARK: - Модель для комплексной загрузки тренировки
struct HKWorkoutBundle {
    let workout: HKWorkout
    let heartRates: [HKQuantitySample]
    let glucose: [HKQuantitySample]
    /// Суммарная активная энергия тренировки (kcal)
    let energyKcal: Double
}

final class HealthKitWorkoutProvider: ObservableObject {

    private let store = HKHealthStore()
    private let hrUnit = HKUnit.count().unitDivided(by: .minute()) // bpm
    private let glucoseUnit = HKUnit(from: "mg/dL")
    private let kcalUnit = HKUnit.kilocalorie()

    // Если где-то использовался — оставляю, но не трогаю
    @Published private(set) var bundles: [WorkoutWithHR] = []

    // MARK: - Публично: загрузка бандлов за интервал

    /// Возвращает тренировки и связанные данные (HR, глюкоза, kcal) за интервал.
    func bundles(in interval: ClosedRange<Date>) async throws -> [HKWorkoutBundle] {
        let workouts = try await fetchWorkouts(from: interval.lowerBound, to: interval.upperBound)

        var result: [HKWorkoutBundle] = []
        result.reserveCapacity(workouts.count)

        for w in workouts {
            async let hr = fetchQuantity(.heartRate, from: w.startDate, to: w.endDate)
            async let gl = fetchQuantity(.bloodGlucose, from: w.startDate, to: w.endDate)
            let kcal    = await energyKcal(for: w) // единая точка правды (без deprecated)

            result.append(.init(workout: w,
                                heartRates: try await hr,
                                glucose: try await gl,
                                energyKcal: kcal))
        }
        return result
    }

    // MARK: - Энергия (единственная реализация, без двусмысленности)

    /// Сумма активной энергии (kcal) за интервал.
    func sumActiveEnergyKcal(from start: Date, to end: Date) async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type,
                                      quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, stats, _ in
                let kcal = stats?.sumQuantity()?.doubleValue(for: self.kcalUnit) ?? 0
                cont.resume(returning: kcal)
            }
            self.store.execute(q)
        }
    }

    /// Энергия конкретного HKWorkout.
    /// На iOS 18+ всегда считаем статистикой; на старых — пробуем поле, иначе статистика.
    func energyKcal(for workout: HKWorkout) async -> Double {
        if #available(iOS 18, *) {
            // На iOS 18+ totalEnergyBurned deprecated — всегда считаем статистикой
            return await sumActiveEnergyKcal(from: workout.startDate, to: workout.endDate)
        } else {
            if let kcal = workout.totalEnergyBurned?.doubleValue(for: kcalUnit) {
                return kcal
            } else {
                return await sumActiveEnergyKcal(from: workout.startDate, to: workout.endDate)
            }
        }
    }

    /// Словарь [TrainingRow.id : kcal] по времени ваших тренировок.
    /// Ищем совпадающий HKWorkout (по старт/финишу с допуском), иначе суммируем по интервалу.
    func energyByTraining(for trainings: [TrainingRow]) async -> [Int64: Double] {
        guard let minStart = trainings.map(\.startTime).min(),
              let maxEnd   = trainings.map(\.endTime).max() else { return [:] }

        let allWorkouts = (try? await fetchWorkouts(from: Date(timeIntervalSince1970: minStart),
                                                    to:   Date(timeIntervalSince1970: maxEnd))) ?? []

        func matches(_ tr: TrainingRow, _ w: HKWorkout) -> Bool {
            let s = Date(timeIntervalSince1970: tr.startTime)
            let e = Date(timeIntervalSince1970: tr.endTime)
            // допуск 3 минуты на неточности
            return abs(w.startDate.timeIntervalSince(s)) < 180 &&
                   abs(w.endDate.timeIntervalSince(e))   < 180
        }

        var result: [Int64: Double] = [:]

        for tr in trainings {
            if let w = allWorkouts.first(where: { matches(tr, $0) }) {
                result[tr.id] = await energyKcal(for: w)
            } else {
                let s = Date(timeIntervalSince1970: tr.startTime)
                let e = Date(timeIntervalSince1970: tr.endTime)
                result[tr.id] = await sumActiveEnergyKcal(from: s, to: e)
            }
        }
        return result
    }

    // MARK: - Ежедневные HR (как было)

    func dailyHeartRates(in range: ClosedRange<Date>) async throws -> [HKQuantitySample] {
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: range.lowerBound,
                                                    end:   range.upperBound,
                                                    options: .strictStartDate)

        return try await withCheckedThrowingContinuation { cont in
            let q = HKSampleQuery(sampleType: hrType,
                                  predicate: predicate,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate,
                                                                      ascending: true)]) { _, samples, error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume(returning: (samples as? [HKQuantitySample] ?? [])) }
            }
            self.store.execute(q)
        }
    }

    // MARK: - Private fetch helpers

    private func fetchWorkouts(from start: Date, to end: Date) async throws -> [HKWorkout] {
        try await withCheckedThrowingContinuation { cont in
            let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            let q = HKSampleQuery(sampleType: .workoutType(),
                                  predicate: pred,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: sort) { _, samples, err in
                if let err { cont.resume(throwing: err) }
                else { cont.resume(returning: samples as? [HKWorkout] ?? []) }
            }
            store.execute(q)
        }
    }

    private func fetchQuantity(_ id: HKQuantityTypeIdentifier,
                               from start: Date,
                               to end: Date) async throws -> [HKQuantitySample] {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return [] }
        return try await withCheckedThrowingContinuation { cont in
            let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let q = HKSampleQuery(sampleType: type,
                                  predicate: pred,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: nil) { _, samples, err in
                if let err { cont.resume(throwing: err) }
                else { cont.resume(returning: samples as? [HKQuantitySample] ?? []) }
            }
            store.execute(q)
        }
    }
}
