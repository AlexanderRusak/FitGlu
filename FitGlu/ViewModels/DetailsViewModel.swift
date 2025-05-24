import Foundation
import Combine
import HealthKit

/// Объединённый провайдер: локальная БД + HealthKit
final class DetailsViewModel: ObservableObject {

    // MARK: – Published для View
    @Published var trainings     : [TrainingRow]     = []
    @Published var heartRates    : [HeartRateLogRow] = []
    @Published var glucose       : [GlucoseRow]      = []
    @Published var hrDailyPoints : [HRPoint]         = []

    // MARK: – Providers
    private let local = LocalDBProvider()              // SQLite
    private let hk    = HealthKitWorkoutProvider()     // HealthKit

    private var bag = Set<AnyCancellable>()
    
    @Published var userAge : Int?               // ← новое
    @Published var userSex : HKBiologicalSex?   // ← новое

    private let auth = HealthKitAuthorizationManager()

    // MARK: – Public API
    @MainActor
    func load(for day: Date) async {

        let from = day.startOfDay
        let to   = day.endOfDay

        // ───────── 1. локальная БД ─────────
        let locT  = local.trainings(from: from, to: to)
        let locHR = local.heartRates(for: locT)
        let locG  = local.glucose (from: from, to: to)

        // ───────── 2. HealthKit ────────────
        let bundles   = (try? await hk.bundles(in: from ... to)) ?? []
        let hkRaw     = (try? await hk.dailyHeartRates(in: from ... to)) ?? []

        // фильтруем суточные HR‑сэмплы
        let adapter       = HRFlatAdapter()
        let hkClean       = adapter.convert(hkRaw)
        print("📈 HR daily: raw=\(hkRaw.count)   clean=\(hkClean.count)")

        // конвертируем bundles (с доп. фильтром внутри каждой тренировки)
        let converted = Self.convert(bundles: bundles, adapter: adapter)

        let points = Self.points(from: hkClean,
                                 workouts: converted.trainings)

        // ───────── 3. publish ─────────────
        trainings     = locT  + converted.trainings
        heartRates    = locHR + converted.heartRates
        glucose       = locG
        hrDailyPoints = points
        
        if userAge == nil {
            await withCheckedContinuation { cont in
                auth.fetchAge { age in
                    self.userAge = age
                    self.auth.fetchBiologicalSex { sex in
                        self.userSex = sex
                        cont.resume()
                    }
                }
            }
        }
    }
}

// MARK: – Helpers
private extension DetailsViewModel {

    /// Конвертируем HKWorkoutBundle‑ы в обычные модели + фильтруем HR внутри
    static func convert(bundles: [HKWorkoutBundle],
                        adapter: HRFlatAdapter)
      -> (trainings: [TrainingRow], heartRates: [HeartRateLogRow])
    {
        var tRows: [TrainingRow]     = []
        var hrRows: [HeartRateLogRow] = []

        for bundle in bundles {

            // ── тренировка
            let wk = bundle.workout
            tRows.append(
                TrainingRow(
                    id:        Int64(wk.uuid.hashValue),   // временный
                    type:      wk.workoutActivityType.workoutName,
                    startTime: wk.startDate.timeIntervalSince1970,
                    endTime:   wk.endDate.timeIntervalSince1970
                )
            )

            // ── HR‑сэмплы этой тренировки + фильтр€
            let raw   = bundle.heartRates               // ← вот откуда берём «сырые»
            let clean = adapter.convert(raw)

            print("🏃‍♂️ \(wk.workoutActivityType.workoutName): "
                  + "HR raw=\(raw.count)  clean=\(clean.count)")

            for s in clean {
                hrRows.append(
                    HeartRateLogRow(
                        id: Int64(s.uuid.hashValue),
                        trainingID: 0,
                        heartRate: Int(
                            s.quantity.doubleValue(
                                for: .count().unitDivided(by: .minute())) ),
                        timestamp: s.startDate.timeIntervalSince1970,
                        isSynced: true
                    )
                )
            }
        }
        return (tRows, hrRows)
    }

    /// Строим точки для «фоновых» HR‑сэмплов
    static func points(from samples: [HKQuantitySample],
                       workouts: [TrainingRow]) -> [HRPoint]
    {
        let intervals = workouts.map {
            Date(timeIntervalSince1970: $0.startTime)
            ...
            Date(timeIntervalSince1970: $0.endTime)
        }

        return samples.map { s in
            let bpm = Int(
                s.quantity.doubleValue(
                    for: .count().unitDivided(by: .minute())) )
            let inside = intervals.contains { $0.contains(s.startDate) }
            return HRPoint(time: s.startDate, bpm: bpm, inWorkout: inside)
        }
    }
}
