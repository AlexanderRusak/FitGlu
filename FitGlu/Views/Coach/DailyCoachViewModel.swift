import SwiftUI
import HealthKit
import OSLog

@MainActor
final class DailyCoachViewModel: ObservableObject {
    @Published var metrics = DailyCoachMetrics.empty
    @Published var aiSummary: String = ""
    @Published var aiBusy = false
    

    // MARK: - Providers
    private let local = LocalDBProvider()
    private let details = DetailsViewModel()
    private let ai = ChatGPTProvider()
    private let healthKit = HealthKitAuthorizationManager()
    private let healthStore = HKHealthStore()

    // MARK: - Loggers
    private let log = Logger(subsystem: "com.yourapp.fitglu", category: "DailyCoach")
    private let aiLog = Logger(subsystem: "com.yourapp.fitglu", category: "DailyCoach.AI")
    
    // MARK: - Recovery logic
    private func hoursSinceLastTraining(from trainings: [TrainingRow]) -> Double {
        guard let last = trainings.sorted(by: { $0.endTime > $1.endTime }).first else {
            log.notice("No trainings found for recovery window check")
            return 999 // давно не было
        }

        let endDate = Date(timeIntervalSince1970: last.endTime)
        let hours = Date().timeIntervalSince(endDate) / 3600.0
        log.info("Last training: \(last.type) ended at \(endDate), \(hours, privacy: .public)h ago")
        return max(0, hours)
    }
    
    // MARK: - Recovery logic (mapping workout type -> recovery window)
    private func recoveryWindowHours(for rawType: String) -> Double {
        // сначала пытаемся по точным именам (как в TrainingPalette)
        let type = rawType.trimmingCharacters(in: .whitespacesAndNewlines)

        var hours: Double
        var matched: String = "default"

        switch type {
        case "HIIT":
            hours = 36; matched = "HIIT"
        case "Functional Strength Training", "Functional Strength Training":
            hours = 24; matched = "Functional Strength Training"
        case "Traditional Strength Training", "Traditional Strength Training":
            hours = 24; matched = "Traditional Strength Training"
        case "Running":
            hours = 18; matched = "Running"
        case "Cycling":
            hours = 18; matched = "Cycling"
        case "Walking":
            hours = 12; matched = "Walking"
        default:
            // fallback — подстрахуемся по подстрокам/локализациям
            let t = type.lowercased()
            if t.contains("hiit") || t.contains("interval") {
                hours = 36; matched = "fallback:hiit/interval"
            } else if t.contains("strength") || t.contains("сил") {
                hours = 24; matched = "fallback:strength"
            } else if t.contains("run") || t.contains("bike")
                        || t.contains("cycling") || t.contains("vel") {
                hours = 18; matched = "fallback:endurance"
            } else if t.contains("walk") || t.contains("yoga") || t.contains("stretch") {
                hours = 12; matched = "fallback:light"
            } else {
                hours = 24; matched = "fallback:default(24h)"
            }
        }

        log.info("Recovery map: raw='\(rawType)' -> match=\(matched, privacy: .public), hours=\(hours, privacy: .public)")
        return hours
    }

    
    private func fetchBaselineRestingHR() async -> Int? {
        await withCheckedContinuation { continuation in
            let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
            let start = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
            let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                let total = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) }
                let avg = total / Double(samples.count)
                continuation.resume(returning: Int(avg.rounded()))
            }
            healthStore.execute(query)
        }
    }
    

    // MARK: - Public
    func load() async {
        let authorized = await healthKit.requestAuthorization()
        log.info("HealthKit authorization granted: \(authorized, privacy: .public)")
        guard authorized else { return }

        // 🏋️ Получаем тренировки за последние 30 дней
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -30, to: end)!
        await details.loadTrainings(in: start ... end)
        // 🕒 Recovery analysis
        let lastTrainingHours = hoursSinceLastTraining(from: details.trainings)
        let intenseTraining = mostIntenseTrainingOfLatestDay(in: details.trainings)

        let lastTrainingType = intenseTraining?.type ?? "Unknown"
        let recoveryWindow = recoveryWindowHours(for: lastTrainingType)
        let recoveryProgress = min(1.0, lastTrainingHours / recoveryWindow)
        log.info("Recovery window check: type=\(lastTrainingType), since=\(lastTrainingHours, privacy: .public)h, window=\(recoveryWindow, privacy: .public)h, progress=\(recoveryProgress, privacy: .public)")


        let activityFactor = computeActivityFactor(from: details.trainings, in: start ... end)
        log.info("AF for \(start)–\(end): \(activityFactor)")

        // 📊 Получаем метрики за сегодня
        let data = await healthKit.fetchTodayMetrics()
        let sleepFactor = min(1.0, Double(data.sleepMinutes) / 420.0) // 7h = 1.0
        let sleepPenalty = (1.0 - sleepFactor) * 0.5 // до -50% скорости восстановления
        let adjustedRecoveryWindow = recoveryWindow * (1.0 + sleepPenalty)
        let remainingHours = max(0.0, adjustedRecoveryWindow - lastTrainingHours)
        let proteinYesterday = await healthKit.fetchYesterdayProteinG()
        let proteinAvg = Int(Double(data.proteinG + proteinYesterday) / 2.0)

        log.info("""
        Next training estimation:
        type=\(lastTrainingType),
        rawWindow=\(recoveryWindow, privacy: .public)h,
        sleepPenalty=\(sleepPenalty, privacy: .public),
        adjustedWindow=\(adjustedRecoveryWindow, privacy: .public)h,
        remaining=\(remainingHours, privacy: .public)h,
        proteinYesterday=\(proteinYesterday, privacy: .public),
        proteinAvg=\(proteinAvg, privacy: .public),
        lastTrainingType=\(lastTrainingType, privacy: .public),
        """)
        
        
        let baselineHR = await fetchBaselineRestingHR() ?? 55
        log.info("Baseline HR: \(String(describing: baselineHR), privacy: .public)")

        log.debug("""
        HealthKit today:
          steps=\(data.steps, privacy: .public)
          sleepMin=\(data.sleepMinutes, privacy: .public)
          hrRest=\(data.restingHR, privacy: .public)
          proteinG=\(data.proteinG, privacy: .public)
          kcal=\(data.kcal, privacy: .public)
          weightKg=\(String(describing: data.weightKg), privacy: .public)
          leanMassKg=\(String(describing: data.leanMassKg), privacy: .public)
          fatPercent=\(String(describing: data.fatPercent), privacy: .public)
        """)
        
        let proteinTarget = computeProteinTarget(
            weightKg: data.weightKg,
            leanMassKg: data.leanMassKg,
            fatPercent: data.fatPercent,
            activityFactor: activityFactor
        )

        let readiness = Self.computeReadiness(
            steps: data.steps,
            sleepMin: data.sleepMinutes,
            hrRest: data.restingHR,
            baselineHR: baselineHR,
            proteinG: proteinAvg, // 👈 теперь среднее за 2 дня
            proteinTarget: proteinTarget,
            recoveryProgress: recoveryProgress
        )
        log.info("Computed readiness: \(readiness, privacy: .public)")


        log.info("Protein target (g): \(proteinTarget, privacy: .public)")
        
        let tr = computeTrainingReadiness(
            sleepMin: data.sleepMinutes,
            proteinG: data.proteinG,
            proteinTarget: proteinTarget,
            hrRestToday: data.restingHR,
            baselineHR: baselineHR,
            lastTraining: details.lastTraining
        )
        let qualityScore = computeLastTrainingQuality()
             let qualitySummary: String?
             if let q = qualityScore, let lastType = details.lastTraining?.type {
                 qualitySummary = "\(lastType) — \(q)/100"
             } else {
                 qualitySummary = nil
             }
        log.info("Training readiness: \(tr.score, privacy: .public), label: \(tr.label, privacy: .public)")

        let newMetrics = DailyCoachMetrics(
            readiness: readiness,
            steps: data.steps,
            stepsTarget: 9000,
            sleepMin: data.sleepMinutes,
            baselineHR: baselineHR,
            hrMax: HRMaxDBManager.shared.valueOrDefault(age: details.userAge),
            proteinG: data.proteinG,
            kcal: data.kcal,
            glucoseFlag: nil,
            weightKg: data.weightKg,
            weightDelta: nil,
            proteinTarget: proteinTarget,
            coachTag1: readiness >= 70 ? "Ready" : "Recover",
            coachTag2: data.proteinG >= proteinTarget ? "Protein OK" : "Protein ↑",
            lastTrainingType: lastTrainingType,
            hoursSinceLastTraining: lastTrainingHours,
            nextTrainingInHours: remainingHours,
            recoveryProgress: recoveryProgress,
            trainingReadiness: tr.score,
            trainingReadinessLabel: tr.label,
            lastTrainingScore: qualityScore,        // 👈 НОВОЕ
            lastTrainingSummary: qualitySummary     // 👈 НОВОЕ
        )

        var metricsWithQuality = newMetrics

        // Добавляем качество последней тренировки (если есть)
        if let q = details.lastTrainingQualityScore(),
           let last = details.lastTraining {
            metricsWithQuality.lastTrainingScore = q
            metricsWithQuality.lastTrainingSummary = "\(last.type) — \(q)/100"
        }

        if let json = metricsWithQuality.prettyJSON {
            log.notice("DailyCoachMetrics updated:\n\(json, privacy: .public)")
        } else {
            log.notice("DailyCoachMetrics updated (fallback): \(String(describing: metricsWithQuality), privacy: .public)")
        }

        metrics = newMetrics
    }

    // MARK: - AI summary
    func runAI() async {
        aiBusy = true
        defer { aiBusy = false }

        let prompt = AISummaryBuilder.makeDailyPrompt(from: metrics)
        if let json = metrics.prettyJSON {
            aiLog.debug("AI prompt built from metrics:\n\(json, privacy: .public)")
        }

        do {
            let result = try await ai.send(messages: [
                .init(role: .system, content: "Ты строгий и краткий спортивный врач-тренер."),
                .init(role: .user, content: prompt)
            ], temperature: 0.4)

            let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
            aiLog.info("AI summary received (\(trimmed.count, privacy: .public) chars)")
            aiSummary = trimmed
        } catch {
            aiLog.error("AI error: \(error.localizedDescription, privacy: .public)")
            aiSummary = "Ошибка AI: \(error.localizedDescription)"
        }
    }

    // MARK: - Activity factor
    private func computeActivityFactor(from trainings: [TrainingRow],
                                       in range: ClosedRange<Date>) -> Double {
        let filtered = trainings.filter {
            let start = Date(timeIntervalSince1970: $0.startTime)
            return start >= range.lowerBound && start <= range.upperBound
        }

        guard !filtered.isEmpty else {
            log.notice("AF: no trainings found in selected range")
            return 1.2
        }

        let totalEnergy = filtered.compactMap { $0.energyKcal }.reduce(0, +)
        let activeDays = Set(filtered.map { Date(timeIntervalSince1970: $0.startTime).startOfDay }).count
        let avgPerActiveDay = totalEnergy / Double(max(1, activeDays))

        let missing = filtered.filter { $0.energyKcal == nil }.count
        if missing > 0 { log.notice("AF: trainings without kcal = \(missing)") }

        log.info("AF: totalEnergy=\(totalEnergy) kcal, activeDays=\(activeDays), avg=\(avgPerActiveDay) kcal/day")

        let factor: Double
        switch avgPerActiveDay {
        case 0..<200: factor = 1.2
        case 200..<400: factor = 1.4
        case 400..<700: factor = 1.6
        default: factor = 1.8
        }
        log.info("AF: activityFactor=\(factor)")
        return factor
    }
    
    // MARK: - Last training quality (0–100)
    private func computeLastTrainingQuality() -> Int? {
        // Берём самую последнюю тренировку по endTime
        guard let last = details.trainings.sorted(by: { $0.endTime > $1.endTime }).first else {
            return nil
        }

        // 1) Компонент по длительности (0–100)
        let durationMin = max(0, (last.endTime - last.startTime) / 60.0)
        // считаем, что 90 минут = 100 баллов, меньше — пропорционально
        let durScore = min(1.0, durationMin / 90.0) * 100.0

        // 2) Компонент по энергии (0–100)
        // сначала берём из energyByTraining, если нет — из поля тренировки
        let kcal = details.energyByTraining[last.id] ?? last.energyKcal ?? 0
        // считаем, что 1000 ккал = 100 баллов
        let energyScore = min(1.0, kcal / 1000.0) * 100.0

        // 3) Компонент по типу тренировки (0–100)
        let t = last.type.lowercased()
        let typeScore: Double
        if t.contains("hiit") {
            typeScore = 100
        } else if t.contains("functional") && t.contains("strength") {
            typeScore = 90
        } else if t.contains("traditional") && t.contains("strength") {
            typeScore = 85
        } else if t.contains("run") || t.contains("cycling") || t.contains("bike") || t.contains("velo") || t.contains("вел") {
            typeScore = 80
        } else if t.contains("walk") || t.contains("yoga") || t.contains("stretch") || t.contains("ход") {
            typeScore = 60
        } else {
            typeScore = 70
        }

        // Итоговый скор: 40% длительность, 40% энергия, 20% тип
        let score = 0.4 * durScore + 0.4 * energyScore + 0.2 * typeScore
        return max(0, min(100, Int(score.rounded())))
    }
    
    // MARK: - Intensity selection (pick the heaviest workout of the latest training day)
    private func mostIntenseTrainingOfLatestDay(in trainings: [TrainingRow]) -> TrainingRow? {
        guard !trainings.isEmpty else { return nil }

        // 1) Берём самый свежий день с тренировками
        let latestDay = trainings
            .map { Date(timeIntervalSince1970: $0.endTime).startOfDay }
            .max()!

        let dayTrainings = trainings.filter {
            let end = Date(timeIntervalSince1970: $0.endTime)
            return Calendar.current.isDate(end, inSameDayAs: latestDay)
        }
        guard !dayTrainings.isEmpty else { return nil }

        // 2) Вес по типу
        func typeWeight(for type: String) -> Double {
            let t = type.lowercased()
            if t.contains("hiit") { return 1.00 }
            if t.contains("functional") && t.contains("strength") { return 0.90 }
            if t.contains("traditional") && t.contains("strength") { return 0.90 }
            if t.contains("strength") || t.contains("сил") { return 0.90 }
            if t.contains("run") || t.contains("cycling") || t.contains("bike") || t.contains("velo") || t.contains("вел") { return 0.80 }
            if t.contains("walk") || t.contains("yoga") || t.contains("stretch") { return 0.50 }
            return 0.70
        }

        // 3) Энергия по мапе из DetailsViewModel (если есть)
        func kcal(for tr: TrainingRow) -> Double {
            details.energyByTraining[tr.id] ?? (tr.energyKcal ?? 0) // если у тебя есть optional energyKcal в модели — тоже учтём
        }

        // 4) Длительность в минутах
        func minutes(for tr: TrainingRow) -> Double {
            let dur = tr.endTime - tr.startTime
            return max(0, dur) / 60.0
        }

        // 5) Итоговый скоринг
        return dayTrainings.max { a, b in
            let scoreA = typeWeight(for: a.type) * 10
                        + kcal(for: a) * 0.01      // 1000 ккал ≈ +10 очков
                        + minutes(for: a) * 0.10   // 60 мин ≈ +6 очков
            let scoreB = typeWeight(for: b.type) * 10
                        + kcal(for: b) * 0.01
                        + minutes(for: b) * 0.10
            return scoreA < scoreB
        }
    }


    // MARK: - Readiness
    private static func computeReadiness(
        steps: Int,
        sleepMin: Int,
        hrRest: Int,
        baselineHR: Int,
        proteinG: Int,
        proteinTarget: Int,
        recoveryProgress: Double
    ) -> Int {
        let s = min(1.0, Double(steps) / 8000.0)
        let sl = min(1.0, Double(sleepMin) / 420.0) // 7h
        let r = 1.0 - min(1.0, max(0.0, Double(hrRest - baselineHR) / 25.0))
        let p = min(1.0, Double(proteinG) / Double(proteinTarget))

        var score = (s + sl + r + p) / 4.0 * 100.0

        // 💡 Применяем штраф за недостаточное восстановление
        score *= recoveryProgress

        return max(0, min(100, Int(score.rounded())))
    }

    // MARK: - Training readiness
    /// Строим шкалу "готовности к тренировке" с учётом сна, интервала после тренировки, типа и белка.
    /// Если тренировка уже была сегодня — переключаемся в режим post-training recovery.
    private func computeTrainingReadiness(
        sleepMin: Int,
        proteinG: Int,
        proteinTarget: Int,
        hrRestToday: Int,
        baselineHR: Int,
        lastTraining: TrainingRow?,
        now: Date = Date()
    ) -> (score: Int, label: String) {

        // 1) Нормы
        let sleepFactor = min(1.0, Double(sleepMin) / 420.0)            // 7h = 1.0
        let proteinFactor = min(1.0, Double(max(0, proteinG)) / Double(max(1, proteinTarget)))

        // 2) RHR штраф относительно базы
        //   если выше базы на 7+ уд/мин — ощутимо снижаем "готовность"
        let rhrDelta = max(0, hrRestToday - baselineHR)
        let rhrFactor = 1.0 - min(1.0, Double(rhrDelta) / 25.0)         // +25 bpm → 0

        // 3) Интервал и «окно восстановления» по типу
        let recLog = Logger(subsystem: "com.yourapp.fitglu", category: "Recovery")
        @inline(__always)
        func normalizeType(_ raw: String) -> String {
            let nbpsFixed = raw.replacingOccurrences(of: "\u{00A0}", with: " ")
            let trimmed   = nbpsFixed.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).lowercased()
        }
        
        let lastTraining = details.trainings.sorted(by: { $0.endTime > $1.endTime }).first
        let lastTrainingType = lastTraining?.type ?? "Unknown"

        func hoursSince(_ unix: TimeInterval?) -> Double {
            guard let t = unix else { return .infinity }
            return Date().timeIntervalSince(Date(timeIntervalSince1970: t)) / 3600.0
        }
        let hoursSinceLast = hoursSince(lastTraining?.endTime)
        
        func recoveryWindowHours(for type: String) -> Double {
            let raw = type
            let t = normalizeType(type)
            var hours: Double = 24
            var matched: String = "default"

            // 1) точные названия, как в палитре (lowercased)
            switch t {
            case "running":
                hours = 18; matched = "palette:running"
            case "walking":
                hours = 12; matched = "palette:walking"
            case "cycling":
                hours = 18; matched = "palette:cycling"
            case "functional strength training":
                hours = 24; matched = "palette:functionalStrength"
            case "traditional strength training":
                hours = 24; matched = "palette:traditionalStrength"
            case "hiit":
                hours = 36; matched = "palette:hiit"
            default:
                // 2) fallback по ключевым словам (EN/RU)
                if t.contains("hiit") || t.contains("interval") {
                    hours = 36; matched = "fallback:hiit/interval"
                } else if t.contains("strength") || t.contains("сил") {
                    hours = 24; matched = "fallback:strength"
                } else if t.contains("run") || t.contains("bike") || t.contains("cycling") || t.contains("velo") || t.contains("вел") {
                    hours = 18; matched = "fallback:run/bike/cycling"
                } else if t.contains("walk") || t.contains("yoga") || t.contains("stretch") || t.contains("ход") {
                    hours = 12; matched = "fallback:walk/yoga/stretch"
                }
            }

            recLog.debug("Recovery map: raw='\(raw, privacy: .public)' -> norm='\(t, privacy: .public)', match=\(matched, privacy: .public), hours=\(hours, privacy: .public)")
            return hours
        }
        
        let window = recoveryWindowHours(for: lastTrainingType)
        let recoveryProgress = max(0, min(1, hoursSinceLast / window))
        let nextTrainingInHours = max(0, window - hoursSinceLast)

        // Простейшая «готовность к тренировке» из прогресса восстановления
        let trainingReadiness = Int((recoveryProgress * 100).rounded())
        let trainingReadinessLabel = trainingReadiness >= 70 ? "Train" : "Recover"

        var trainingRecoveryFactor: Double = 1.0
        var isToday = false
        if let last = lastTraining {
            let hours = max(0, (now.timeIntervalSince1970 - last.endTime) / 3600.0)
            isToday = Calendar.current.isDateInToday(Date(timeIntervalSince1970: last.endTime))
            let window = recoveryWindowHours(for: last.type)
            trainingRecoveryFactor = min(1.0, hours / window)
        }

        // 4) Две логики: до тренировки (готовность тренироваться) и после (восстановление)
        let score: Double
        let label: String

        if isToday {
            // Уже потренировался — оцениваем восстановление после
            // Белок здесь более весом, т.к. критичен post-workout
            score =
                0.50 * proteinFactor +
                0.30 * sleepFactor +
                0.20 * rhrFactor
            label = "Recover"
        } else {
            // Ещё не тренился — готов ли тренироваться
            score =
                0.40 * sleepFactor +
                0.30 * trainingRecoveryFactor +
                0.20 * proteinFactor +
                0.10 * rhrFactor
            label = "Train"
        }

        let pct = max(0, min(100, Int((score * 100.0).rounded())))
        return (pct, label)
    }


    // MARK: - Protein target
    private func computeProteinTarget(weightKg: Double?,
                                      leanMassKg: Double?,
                                      fatPercent: Double?,
                                      activityFactor: Double) -> Int {
        guard let weight = weightKg else { return 120 }

        var factor = activityFactor

        if let lean = leanMassKg, lean / weight > 0.8 {
            factor += 0.2
        }

        if let fat = fatPercent, fat > 25 {
            factor -= 0.1
        }

        let proteinTarget = weight * factor
        return Int(proteinTarget.rounded())
    }
}

// MARK: - Metrics model
struct DailyCoachMetrics: Codable {
    var readiness: Int

    var steps: Int
    var stepsTarget: Int

    var sleepMin: Int
    var baselineHR: Int?
    var hrMax: Int
    var proteinG: Int

    var kcal: Double
    var glucoseFlag: String?

    var weightKg: Double?
    var weightDelta: Double?

    var proteinTarget: Int

    var coachTag1: String
    var coachTag2: String
    
    // 🔹 Новые поля для восстановления и AI
    var lastTrainingType: String?
    var hoursSinceLastTraining: Double?
    var nextTrainingInHours: Double?
    var recoveryProgress: Double?
    var trainingReadiness: Int?
    var trainingReadinessLabel: String?
    var lastTrainingScore: Int?
    var lastTrainingSummary: String?
    
    // MARK: - Formatters
    var weightString: String {
        guard let w = weightKg else { return "—" }
        return String(format: "%.1f kg", w)
    }

    var weightDeltaString: String? {
        guard let d = weightDelta else { return nil }
        let sign = d > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", d)) kg vs. yesterday"
    }
    
    var recoveryProgressString: String? {
        guard let p = recoveryProgress else { return nil }
        return "\(Int((p * 100).rounded()))%"
    }

    var sleepString: String { "\(sleepMin / 60)h \(sleepMin % 60)m" }
    var stepsTargetString: String { "↗︎ \(stepsTarget) target" }
    var proteinTargetString: String { "\(proteinTarget) g target" }

    static let empty = DailyCoachMetrics(
        readiness: 0, steps: 0, stepsTarget: 9000,
        sleepMin: 0, baselineHR: 0, hrMax: 0, proteinG: 0,
        kcal: 0, glucoseFlag: nil, weightKg: nil, weightDelta: nil,
        proteinTarget: 120,
        coachTag1: "—", coachTag2: "—",
        lastTrainingType: nil,
        hoursSinceLastTraining: nil,
        nextTrainingInHours: nil,
        recoveryProgress: nil,
        trainingReadiness: nil,
        trainingReadinessLabel: nil,
        lastTrainingScore: nil,
        lastTrainingSummary: nil
    )
}

// MARK: - JSON Logging
extension DailyCoachMetrics {
    var prettyJSON: String? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(self)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
