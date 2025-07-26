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
    @Published var hrSegments    : [[HRPoint]]       = []
    @Published var zones         : ZoneThresholds?   // ← added zone storage

    // MARK: – Providers
    private let local = LocalDBProvider()              // SQLite
    private let hk    = HealthKitWorkoutProvider()     // HealthKit

    private var bag = Set<AnyCancellable>()
    
    @Published var userAge : Int?
    @Published var userSex : HKBiologicalSex?

    private let auth = HealthKitAuthorizationManager()

    // MARK: – Public API
    @MainActor
    func load(for day: Date) async {
        let from = day.startOfDay
        let to   = day.endOfDay

        let locT  = local.trainings(from: from, to: to)
        let locHR = local.heartRates(for: locT)
        let locG  = local.glucose(from: from, to: to)

        let bundles = (try? await hk.bundles(in: from ... to)) ?? []
        let hkRaw   = (try? await hk.dailyHeartRates(in: from ... to)) ?? []

        let adapter       = HRFlatAdapter(maxGap: 5 * 60)
        let hkSegments    = adapter.chunks(from: hkRaw)

        let hrSegments: [[HRPoint]] = hkSegments.map { seg in
            seg.map { s in
                HRPoint(
                    time: s.startDate,
                    bpm: Int(s.quantity.doubleValue(for: .count().unitDivided(by: .minute()))),
                    inWorkout: false
                )
            }
        }
        self.hrSegments = hrSegments

        let hkClean = adapter.convert(hkRaw)
        print("📈 HR daily: raw=\(hkRaw.count)   clean=\(hkClean.count)")

        let converted = Self.convert(bundles: bundles, adapter: adapter)
        let points = Self.points(from: hkClean, workouts: converted.trainings)

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

        let today = calendar.startOfDay(for: Date())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }

        let lastUpdateDate = TrainingsStateDBManager.shared.getLastUpdateDate()

        let localTrainings = local.trainings(from: .distantPast, to: .distantFuture)
        let localDays = Set(localTrainings.map { Date(timeIntervalSince1970: $0.startTime).startOfDay })

        let hkBundles = try await hk.bundles(in: .distantPast ... .distantFuture)
        let hkDays = Set(hkBundles.map { calendar.startOfDay(for: $0.workout.startDate) })

        var daysToAnalyze = Array(localDays.union(hkDays)).sorted()
        if let last = lastUpdateDate {
            daysToAnalyze = daysToAnalyze.filter { $0 > last }
        }
        daysToAnalyze = daysToAnalyze.filter { $0 <= yesterday }
        print("🗖️ Дней для анализа: \(daysToAnalyze.map { df.string(from: $0) })")

        for day in daysToAnalyze {
            print("\n—— День \(df.string(from: day)) ——")
            try await load(for: day)

            guard !trainings.isEmpty, !glucose.isEmpty, !hrSegments.isEmpty else {
                print("⚠️ Пропущено: недостаточно данных")
                continue
            }
            print("   ▶ trainings=\(trainings.count), glucose=\(glucose.count), hrSeg=\(hrSegments.count)")

            let sessions = SessionAnalyzer.makeSessions(hrSegments: hrSegments, glucose: glucose, trainings: trainings)
            print("   ▶ SessionAnalyzer вернул: \(sessions.count) сессии(й)")

            let db = SessionZonesDBManager.shared
            for session in sessions {
                if try !db.exists(start: session.start) {
                    try db.save(session: session)
                    try AverageZonesDBManager.shared.upsertAverage(newZones: session.zones)
                    newCount += 1
                    print("     ✅ Сохранена новая сессия")
                }
            }
        }

        TrainingsStateDBManager.shared.saveLastUpdateDate(yesterday)

        if newCount == 0 {
            print("\nℹ️ Новых сессий не добавлено.")
        } else {
            print("\n🎉 Всего добавлено новых сессий: \(newCount)")
        }
        return newCount
    }

    // MARK: – Helpers
    static func convert(bundles: [HKWorkoutBundle], adapter: HRFlatAdapter)
    -> (trainings: [TrainingRow], heartRates: [HeartRateLogRow]) {
        var tRows: [TrainingRow] = []
        var hrRows: [HeartRateLogRow] = []

        for bundle in bundles {
            let wk = bundle.workout
            tRows.append(TrainingRow(
                id: Int64(wk.uuid.hashValue),
                type: wk.workoutActivityType.workoutName,
                startTime: wk.startDate.timeIntervalSince1970,
                endTime: wk.endDate.timeIntervalSince1970
            ))

            let raw = bundle.heartRates
            let clean = adapter.convert(raw)

            print("🏃‍♂️ \(wk.workoutActivityType.workoutName): HR raw=\(raw.count)  clean=\(clean.count)")

            for s in clean {
                hrRows.append(HeartRateLogRow(
                    id: Int64(s.uuid.hashValue),
                    trainingID: 0,
                    heartRate: Int(s.quantity.doubleValue(for: .count().unitDivided(by: .minute()))),
                    timestamp: s.startDate.timeIntervalSince1970,
                    isSynced: true
                ))
            }
        }
        return (tRows, hrRows)
    }

    static func points(from samples: [HKQuantitySample], workouts: [TrainingRow]) -> [HRPoint] {
        let intervals = workouts.map {
            Date(timeIntervalSince1970: $0.startTime)...Date(timeIntervalSince1970: $0.endTime)
        }

        return samples.map { s in
            let bpm = Int(s.quantity.doubleValue(for: .count().unitDivided(by: .minute())))
            let inside = intervals.contains { $0.contains(s.startDate) }
            return HRPoint(time: s.startDate, bpm: bpm, inWorkout: inside)
        }
    }
}
