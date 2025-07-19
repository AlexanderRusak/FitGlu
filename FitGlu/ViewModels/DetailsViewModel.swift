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
    @Published var hrSegments: [[HRPoint]] = []   // ← новая published-переменная

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

        // внутри load(for:)
        let adapter       = HRFlatAdapter(maxGap: 5 * 60)
        let hkSegments    = adapter.chunks(from: hkRaw)          // [[HKQuantitySample]]

        let hrSegments: [[HRPoint]] = hkSegments.map { seg in
            seg.map { s in
                HRPoint(
                    time: s.startDate,
                    bpm:  Int(s.quantity.doubleValue(
                                for: .count().unitDivided(by: .minute()))),
                    inWorkout: false          // или вычислите сами
                )
            }
        }

        self.hrSegments = hrSegments          // ← публикуем для графика
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
    
    @MainActor
    func analyzeAndSaveAll() async throws -> Int {
        var newCount = 0
        let calendar = Calendar.current
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .none

        // 1) Дни локальных тренировок
        let localTrainings = local.trainings(from: .distantPast, to: .distantFuture)
        let localDays = Set(localTrainings.map {
            Date(timeIntervalSince1970: $0.startTime).startOfDay
        })

        // 2) Дни тренировок из HealthKit
        let hkBundles = try await hk.bundles(in: .distantPast ... .distantFuture)
        let hkDays = Set(hkBundles.map {
            calendar.startOfDay(for: $0.workout.startDate)
        })

        // 3) Объединяем и сортируем
        let daysToAnalyze = Array(localDays.union(hkDays)).sorted()
        print("📆 Дней для анализа: \(daysToAnalyze.map { df.string(from: $0) })")

        // 4) По каждому дню: load → анализ → сохранение новых
        for day in daysToAnalyze {
            let dayStr = df.string(from: day)
            print("\n—— День \(dayStr) ——")

            // Загрузили в self.trainings, self.glucose и self.hrSegments
            try await load(for: day)

            // Пропускаем, если нет ни одного из трёх наборов данных
            guard !trainings.isEmpty, !glucose.isEmpty, !hrSegments.isEmpty else {
                print("⚠️ Пропущено: недостаточно данных (trainings=\(trainings.count), glucose=\(glucose.count), hrSeg=\(hrSegments.count))")
                continue
            }
            print("   ▶ trainings=\(trainings.count), glucose=\(glucose.count), hrSeg=\(hrSegments.count)")

            // Анализируем сессии
            let sessions = SessionAnalyzer.makeSessions(
                hrSegments: hrSegments,
                glucose:    glucose,
                trainings:  trainings
            )
            print("   ▶ SessionAnalyzer вернул: \(sessions.count) сессии(й)")

            // Сохраняем только новые
            let db = SessionZonesDBManager.shared
            for session in sessions {
                if try !db.exists(start: session.start) {
                    try db.save(session: session)
                    newCount += 1
                    print("     ✅ Сохранена новая сессия (start=\(df.string(from: Date(timeIntervalSince1970: session.start))))")
                }
            }
        }

        // 5) Итог
        if newCount == 0 {
            print("\nℹ️ Новых сессий не добавлено.")
        } else {
            print("\n🎉 Всего добавлено новых сессий: \(newCount)")
        }
        return newCount
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
