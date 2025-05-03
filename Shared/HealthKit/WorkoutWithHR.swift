import Foundation
import HealthKit

struct WorkoutWithHR {
    let workout: HKWorkout
    let heartRateSamples: [HKQuantitySample]   // bpm + время
}

final class WorkoutProvider {
    private let store: HKHealthStore
    init(store: HKHealthStore = HKHealthStore()) { self.store = store }

    /// Все тренировки *целого дня* + HR-сэмплы внутри каждой.
    func workouts(forDay date: Date,
                  completion: @escaping ([WorkoutWithHR]) -> Void)
    {
        let dayStart = date.startOfDay
        let dayEnd   = date.endOfDay

        let predicate = HKQuery.predicateForSamples(
            withStart: dayStart, end: dayEnd, options: .strictStartDate)

        // ① Berём сами workout-ы
        let workoutQuery = HKSampleQuery(
            sampleType: .workoutType(),
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil)
        { [weak self] _, samples, _ in
            guard let self,
                  let workouts = samples as? [HKWorkout], !workouts.isEmpty
            else { completion([]); return }

            var result: [WorkoutWithHR] = []
            let group = DispatchGroup()

            // ② Для каждого – вытаскиваем пульс
            workouts.forEach { wk in
                group.enter()
                self.fetchHeartRate(for: wk) { hrSamples in
                    result.append( WorkoutWithHR(workout: wk,
                                                 heartRateSamples: hrSamples) )
                    group.leave()
                }
            }
            group.notify(queue: .main) { completion(result) }
        }
        store.execute(workoutQuery)
    }

    /// HR-сэмплы внутри интервала тренировки
    private func fetchHeartRate(for workout: HKWorkout,
                                completion: @escaping ([HKQuantitySample]) -> Void)
    {
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate)
        else { completion([]); return }

        let pred = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate)

        let q = HKSampleQuery(
            sampleType: hrType, predicate: pred,
            limit: HKObjectQueryNoLimit, sortDescriptors: nil)
        { _, samples, _ in
            completion(samples as? [HKQuantitySample] ?? [])
        }
        store.execute(q)
    }
}
