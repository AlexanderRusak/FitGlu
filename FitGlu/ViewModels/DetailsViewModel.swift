import Foundation
import Combine
import HealthKit

/// Объединённый провайдер: локальная БД + HealthKit
final class DetailsViewModel: ObservableObject {

    // MARK: published‑данные для View
    @Published var trainings:     [TrainingRow]      = []
    @Published var heartRates:    [HeartRateLogRow]  = []
    @Published var glucose:       [GlucoseRow]       = []
    @Published var hrDailyPoints: [HRPoint]          = []

    // MARK: providers
    private let local    = LocalDBProvider()          // SQLite (уже был)
    private let hk       = HealthKitWorkoutProvider() // HealthKit

    private var bag = Set<AnyCancellable>()

    // MARK: public API
    @MainActor
    func load(for day: Date) async {

        let from = day.startOfDay
        let to   = day.endOfDay

        // ---- 1. локальная БД ------------------------------------------------
        let locT = local.trainings(from: from, to: to)
        let locHR = local.heartRates(for: locT)
        let locG  = local.glucose (from: from, to: to)

        // ---- 2. HealthKit ---------------------------------------------------
        let bundles    = (try? await hk.bundles(in: from ... to)) ?? []
        let hkSamples  = (try? await hk.dailyHeartRates(in: from ... to)) ?? []

        let converted  = Self.convert(bundles: bundles)
        let points     = Self.points(from: hkSamples, workouts: converted.trainings)

        // ---- 3. publish -----------------------------------------------------
        trainings     = locT + converted.trainings
        heartRates    = locHR + converted.heartRates
        glucose       = locG
        hrDailyPoints = points
    }
}

// MARK: helpers
private extension DetailsViewModel {

    /// превращаем `HKWorkoutBundle`‑ы в обычные модели
    static func convert(bundles: [HKWorkoutBundle])
      -> (trainings: [TrainingRow], heartRates: [HeartRateLogRow])
    {
        var tRows: [TrainingRow] = []
        var hrRows: [HeartRateLogRow] = []

        for bundle in bundles {
            let wk = bundle.workout
            tRows.append(
                TrainingRow(
                    id:        Int64(wk.uuid.hashValue),   // временный
                    type:      wk.workoutActivityType.readableName,
                    startTime: wk.startDate.timeIntervalSince1970,
                    endTime:   wk.endDate.timeIntervalSince1970
                )
            )
            let samples = bundle.heartRates
            for s in samples {
                hrRows.append(
                    HeartRateLogRow(
                        id: Int64(s.uuid.hashValue),
                        trainingID: 0,
                        heartRate: Int(s.quantity.doubleValue(
                            for: .count().unitDivided(by: .minute()))),
                        timestamp: s.startDate.timeIntervalSince1970,
                        isSynced: true
                    )
                )
            }
        }
        return (tRows, hrRows)
    }

    /// строим `HRPoint` для «фоновых» точек
    static func points(from samples: [HKQuantitySample],
                       workouts: [TrainingRow]) -> [HRPoint] {

        let intervals = workouts.map {
            Date(timeIntervalSince1970: $0.startTime)
            ...
            Date(timeIntervalSince1970: $0.endTime)
        }
        return samples.map { s in
            let bpm = Int(s.quantity.doubleValue(
                for: .count().unitDivided(by: .minute())))
            let inside = intervals.contains { $0.contains(s.startDate) }
            return HRPoint(time: s.startDate, bpm: bpm, inWorkout: inside)
        }
    }
}
