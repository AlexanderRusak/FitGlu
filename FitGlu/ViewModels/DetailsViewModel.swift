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
    @Published var energyByTraining: [Int64 : Double] = [:]  // kcal по каждой тренировке
    @Published var dailySteps: Int = 0
    @Published var dailySleepMin: Int = 0
    @Published var dailyProteinG: Double = 0
    @Published var dailyBodyMassKg: Double? = nil
    
    
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
        let corrected = try? SessionZonesDBManager.shared.correctedGlucose(for: day)
        let from = day.startOfDay
        let to   = day.endOfDay

        let locT  = local.trainings(from: from, to: to)
        let locHR = local.heartRates(for: locT)
        let locG  = local.glucose(from: from, to: to)

        let bundles = (try? await hk.bundles(in: from ... to)) ?? []
        let hkRaw   = (try? await hk.dailyHeartRates(in: from ... to)) ?? []

        let adapter       = HRFlatAdapter(maxGap: 5 * 60)
        let hkSegments    = adapter.chunks(from: hkRaw)
        #if DEBUG
        if let c = corrected, !c.isEmpty {
            print("✅ correctedGlucose used (\(c.count) pts) for",
                  day.formatted(date: .abbreviated, time: .omitted))
        } else {
            print("ℹ️ raw CGM used (\(locG.count) pts) for",
                  day.formatted(date: .abbreviated, time: .omitted))
        }
        #endif

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
        glucose       = corrected ?? locG
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
        
        self.energyByTraining = await hk.energyByTraining(for: trainings)
        self.dailySteps    = await hk.steps(on: day)
        self.dailySleepMin = await hk.sleepMinutes(on: day)
        self.dailyProteinG = await hk.dietaryProteinGrams(on: day)
        self.dailyBodyMassKg = await hk.bodyMass(on: day)

    }
    
    @MainActor
    func loadTrainingsRange(days: Int = 30) async {
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: now)!
        await loadTrainings(in: start ... now)
    }

    /// Загружает тренировки за конкретный диапазон дат (локальные + HealthKit)
    @MainActor
    func loadTrainings(in range: ClosedRange<Date>) async {
        print("📆 Loading trainings in range \(range.lowerBound.formatted()) → \(range.upperBound.formatted())")

        // 1. Из локальной БД
        let localT = local.trainings(from: range.lowerBound, to: range.upperBound)
        print("📦 Local trainings: \(localT.count)")

        // 2. Из HealthKit
        let hkBundles = (try? await hk.bundles(in: range)) ?? []
        print("⌚ HK workouts: \(hkBundles.count)")

        // 3. Преобразуем HK в TrainingRow
        let adapter = HRFlatAdapter(maxGap: 5 * 60)
        let converted = Self.convert(bundles: hkBundles, adapter: adapter)

        // 4. Объединяем
        let all = localT + converted.trainings
        print("💪 Total trainings loaded: \(all.count)")

        // 5. Сохраняем в Published-свойство, чтобы обновить UI
        self.trainings = all

        // 6. Подгружаем энергию по каждой тренировке
        self.energyByTraining = await hk.energyByTraining(for: all)
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
                endTime: wk.endDate.timeIntervalSince1970,
                energyKcal: wk.totalEnergyBurned?.doubleValue(for: .kilocalorie())
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

// MARK: - Training helpers
extension DetailsViewModel {

    /// Последняя (самая поздняя) тренировка из загруженных
    var lastTraining: TrainingRow? {
        trainings.max(by: { $0.endTime < $1.endTime })
    }

    /// Сколько часов прошло с конца последней тренировки
    func hoursSinceLastTraining(now: Date = Date()) -> Double? {
        guard let last = lastTraining else { return nil }
        let deltaSec = now.timeIntervalSince1970 - last.endTime
        return max(0, deltaSec / 3600.0)
    }

    /// Была ли тренировка сегодня (по локальной дате)
    func wasTrainingToday(calendar: Calendar = .current) -> Bool {
        guard let last = lastTraining else { return false }
        return calendar.isDateInToday(Date(timeIntervalSince1970: last.endTime))
    }
    
    func lastTrainingQualityScore() -> Int? {
        guard let last = lastTraining else { return nil }

        // Длительность в минутах
        let durationMin = max(0, last.endTime - last.startTime) / 60.0

        // Ккал: сначала берём из energyByTraining (из HealthKit),
        // если там нет — из самого TrainingRow (если у него есть energyKcal)
        let kcal = energyByTraining[last.id] ?? last.energyKcal ?? 0

        guard durationMin > 0, kcal > 0 else { return nil }

        let kcalPerMin = kcal / durationMin

        // Нормализация:
        //   3 ккал/мин → 0 баллов
        //   15 ккал/мин → 100 баллов
        // (всё ниже 3 прижимаем к 0, выше 15 — к 100)
        let minRef = 3.0
        let maxRef = 15.0
        let clipped = min(max(kcalPerMin, minRef), maxRef)
        let score = (clipped - minRef) / (maxRef - minRef) * 100.0

        return Int(score.rounded())
    }
}
