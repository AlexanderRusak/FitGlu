import SwiftUI
import HealthKit
import OSLog

@MainActor
final class DailyCoachViewModel: ObservableObject {
    @Published var metrics = DailyCoachMetrics.empty
    @Published var aiSummary: String = ""
    @Published var aiBusy = false
    @Published var goal: TrainingGoal = .maintain
    @Published var followUp: CoachFollowUp?

    // MARK: - Providers
    private let local = LocalDBProvider()
    private let details = DetailsViewModel()
    private let ai = ChatGPTProvider()
    private let healthKit = HealthKitAuthorizationManager()
    private let healthStore = HKHealthStore()

    // MARK: - Loggers
    private let log = Logger(subsystem: "com.yourapp.fitglu", category: "DailyCoach")
    private let aiLog = Logger(subsystem: "com.yourapp.fitglu", category: "DailyCoach.AI")

    // MARK: - Debug day switch
    private static let useDebugDay = false

    private static var debugDay: Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 1))!
    }

    private var activeDay: Date {
        Self.useDebugDay ? Self.debugDay : Date()
    }

    // MARK: - Workout type normalization (iPhone-only)
    private func normalizeTypeKey(_ raw: String) -> String {
        let nbpsFixed = raw.replacingOccurrences(of: "\u{00A0}", with: " ")
        let trimmed = nbpsFixed.trimmingCharacters(in: .whitespacesAndNewlines)
        let compact = trimmed.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        // Keep letters/numbers (unicode), replace punctuation with spaces.
        let cleaned = compact.replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: " ", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func canonicalWorkoutType(_ raw: String) -> String {
        let t = normalizeTypeKey(raw)
        if t.contains("hiit") || t.contains("interval") { return "HIIT" }
        if t.contains("skipping") || t.contains("jump rope") || t.contains("rope") || t.contains("скакал") { return "Skipping Rope" }
        if t.contains("functional") && t.contains("strength") { return "Functional Strength Training" }
        if t.contains("traditional") && t.contains("strength") { return "Traditional Strength Training" }
        if t.contains("strength") || t.contains("сил") { return "Strength Training" }
        if t.contains("run") || t.contains("running") || t.contains("бег") { return "Running" }
        if t.contains("cycling") || t.contains("bike") || t.contains("velo") || t.contains("вел") { return "Cycling" }
        if t.contains("walk") || t.contains("walking") || t.contains("ход") { return "Walking" }
        if t.contains("yoga") { return "Yoga" }
        if t.contains("stretch") { return "Stretching" }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Recovery logic
    private func hoursSinceLastTraining(from trainings: [TrainingRow], now: Date) -> Double {
        guard let last = trainings.sorted(by: { $0.endTime > $1.endTime }).first else {
            log.notice("No trainings found for recovery window check")
            return 999
        }
        let endDate = Date(timeIntervalSince1970: last.endTime)
        let hours = now.timeIntervalSince(endDate) / 3600.0
        log.info("Last training: \(last.type) ended at \(endDate), \(hours, privacy: .public)h ago")
        return max(0, hours)
    }

    // MARK: - Recovery logic (mapping workout type -> recovery window)
    private func recoveryWindowHours(for rawType: String) -> Double {
        let type = canonicalWorkoutType(rawType)
        log.info("Day trainings types: \(rawType)")

        var hours: Double
        var matched: String = "default"

        switch type {
        case "HIIT":
            hours = 36; matched = "HIIT"
        case "Functional Strength Training":
            hours = 24; matched = "Functional Strength Training"
        case "Traditional Strength Training":
            hours = 24; matched = "Traditional Strength Training"
        case "Strength Training":
            hours = 24; matched = "Strength Training"
        case "Running":
            hours = 18; matched = "Running"
        case "Cycling":
            hours = 18; matched = "Cycling"
        case "Walking":
            hours = 12; matched = "Walking"
        case "Skipping Rope":
            hours = 18; matched = "Skipping Rope"
        case "Yoga", "Stretching":
            hours = 12; matched = "Yoga/Stretching"
        default:
            hours = 24; matched = "default(24h)"
        }

        log.info("Recovery map: raw='\(rawType)' -> canon='\(type, privacy: .public)', match=\(matched, privacy: .public), hours=\(hours, privacy: .public)")
        return hours
    }

    private func fetchBaselineRestingHR() async -> Int? {
        await withCheckedContinuation { continuation in
            let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
            let start = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
            let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                let total = samples.reduce(0.0) {
                    $0 + $1.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                }
                let avg = total / Double(samples.count)
                continuation.resume(returning: Int(avg.rounded()))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Public
    func load(for _: Date = Date()) async {
        self.goal = local.loadUserSettings().goal
        self.log.info("Loaded goal from settings: \(self.goal.rawValue, privacy: .public)")

        let authorized = await healthKit.requestAuthorization()
        log.info("HealthKit authorization granted: \(authorized, privacy: .public)")
        guard authorized else { return }

        let day = activeDay
        let dayStart = day.startOfDay
        let dayEnd = day.endOfDay

        // 1) trainings 30d
        let end = day
        let start = Calendar.current.date(byAdding: .day, value: -30, to: end)!
        await details.loadTrainings(in: start ... end)

        // 2) daily details for day (HR points etc)
        await details.load(for: day)

        // 3) diary summary
        let diary = WorkoutDiarySummaryBuilder.makeSummary(for: day)

        // 4) recovery / activity
        let lastTrainingHours = hoursSinceLastTraining(from: details.trainings, now: dayEnd)
        let intenseTraining = mostIntenseTrainingOfLatestDay(in: details.trainings)
        let lastTrainingType = canonicalWorkoutType(intenseTraining?.type ?? "Unknown")
        let recoveryWindow = recoveryWindowHours(for: lastTrainingType)
        let recoveryProgress = min(1.0, lastTrainingHours / recoveryWindow)

        let activityFactor = computeActivityFactor(from: details.trainings, in: start ... end)

        // 5) HK metrics for day
        let data = await healthKit.fetchMetrics(for: day)

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: dayStart)!
        let proteinYesterday = await healthKit.fetchProteinGrams(for: yesterday)
        let proteinAvg = Int(Double(data.proteinG + proteinYesterday) / 2.0)

        let sleepFactor = min(1.0, Double(data.sleepMinutes) / 420.0)
        let sleepPenalty = (1.0 - sleepFactor) * 0.5
        let adjustedRecoveryWindow = recoveryWindow * (1.0 + sleepPenalty)
        let remainingHours = max(0.0, adjustedRecoveryWindow - lastTrainingHours)

        let baselineHR = await fetchBaselineRestingHR() ?? 55

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
            proteinG: proteinAvg,
            proteinTarget: proteinTarget,
            recoveryProgress: recoveryProgress
        )

        let tr = computeTrainingReadiness(
            sleepMin: data.sleepMinutes,
            proteinG: data.proteinG,
            proteinTarget: proteinTarget,
            hrRestToday: data.restingHR,
            baselineHR: baselineHR,
            lastTraining: details.lastTraining,
            now: dayEnd
        )

        let qualityScore = computeLastTrainingQuality()
        let qualitySummary: String? = {
            guard let q = qualityScore, let lastType = details.lastTraining?.type else { return nil }
            return "\(lastType) — \(q)/100"
        }()

        // 6) base metrics
        var newMetrics = DailyCoachMetrics(
            readiness: readiness,
            steps: data.steps,
            stepsTarget: 9000,
            sleepMin: data.sleepMinutes,
            restingHR: data.restingHR,
            baselineHR: baselineHR,
            planAnalysisVersion: AISummaryBuilder.analysisVersion,
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
            lastTrainingScore: qualityScore,
            lastTrainingSummary: qualitySummary
        )

        // 7) diary -> metrics
        newMetrics.diaryTotalSets = diary.totalSets
        newMetrics.diaryExercisesCount = diary.exercisesCount
        newMetrics.diarySupersetExercisesCount = diary.supersetExercisesCount
        newMetrics.diaryApproxTonnage = diary.approxTonnage.map { Int($0.rounded()) }
        newMetrics.diaryTopExercises = diary.topExercises

        // 8) strength window -> HR analyze
        let dayTrainings = details.trainings.filter {
            Calendar.current.isDate(Date(timeIntervalSince1970: $0.startTime), inSameDayAs: day)
        }

        let strengthWorkout = dayTrainings.first { tr in
            let t = canonicalWorkoutType(tr.type)
            return t == "Traditional Strength Training" || t == "Functional Strength Training" || t == "Strength Training"
        }

        if let sw = strengthWorkout {
            let from = Date(timeIntervalSince1970: sw.startTime)
            let to   = Date(timeIntervalSince1970: sw.endTime)

            let hrPoints = details.hrDailyPoints
                .filter { $0.time >= from && $0.time <= to }
                .sorted { $0.time < $1.time }

            if let s = StrengthHRAnalyzer.analyze(points: hrPoints) {
                newMetrics.strengthAnalysisVersion = s.analysisVersion
                newMetrics.strengthHasEnoughHR = s.hasEnoughData
                newMetrics.strengthDurationMin = s.durationMin
                newMetrics.strengthAvgHR = s.avgHR
                newMetrics.strengthMaxHR = s.maxHR
                newMetrics.strengthWaveCount = s.waveCount
                newMetrics.strengthRestMedianSec = s.restMedianSec
                newMetrics.strengthRestP90Sec = s.restP90Sec
                newMetrics.strengthRecoveryDropMedianBpm = s.recoveryDropMedianBpm
                newMetrics.strengthDriftBpm = s.driftBpm
                newMetrics.strengthEfficiencyScore = s.efficiencyScore
                newMetrics.strengthWeakSpot = s.weakSpot

                newMetrics.restRecommendedSec = s.restRecommendedSec
                newMetrics.restDisciplineScore = s.restDisciplineScore
                log.info("Strength: ver=\(s.analysisVersion, privacy: .public), dur=\(s.durationMin, privacy: .public) min, eff=\(s.efficiencyScore, privacy: .public)")
            } else {
                newMetrics.strengthHasEnoughHR = false
            }
        }

        // 9) HIIT: если есть HIIT тренировка — считаем hiit-метрики
        let hiitWorkout = dayTrainings.first { tr in
            let t = canonicalWorkoutType(tr.type)
            return t == "HIIT"
        }

        if let hw = hiitWorkout {
            let from = Date(timeIntervalSince1970: hw.startTime)
            let to   = Date(timeIntervalSince1970: hw.endTime)

            let hrPoints = details.hrDailyPoints
                .filter { $0.time >= from && $0.time <= to }
                .sorted { $0.time < $1.time }

            if let h = HIITHRAnalyzer.analyze(points: hrPoints) {
                newMetrics.hiitAnalysisVersion = h.analysisVersion
                newMetrics.hiitHasEnoughHR = h.hasEnoughData
                newMetrics.hiitDurationMin = h.durationMin
                newMetrics.hiitAvgHR = h.avgHR
                newMetrics.hiitMaxHR = h.maxHR

                newMetrics.hiitHighThresholdBpm = h.highThresholdBpm
                newMetrics.hiitLowThresholdBpm = h.lowThresholdBpm

                newMetrics.hiitTimeInHighZoneSec = h.timeInHighZoneSec
                newMetrics.hiitTimeInHighZonePct = h.timeInHighZonePct

                newMetrics.hiitIntervalCount = h.intervalCount
                newMetrics.hiitWorkMedianSec = h.workMedianSec
                newMetrics.hiitRestMedianSec = h.restMedianSec

                newMetrics.hiitRecoverySlopeBpmPerMin = h.recoverySlopeBpmPerMin
                newMetrics.hiitQualityScore = h.qualityScore
                newMetrics.hiitWeakSpot = h.weakSpot
            } else {
                newMetrics.hiitHasEnoughHR = false
            }

            log.info("HIIT: ver=\(newMetrics.hiitAnalysisVersion ?? "n/a", privacy: .public), dur=\(newMetrics.hiitDurationMin ?? -1) min, intervals=\(newMetrics.hiitIntervalCount ?? -1), high%=\(newMetrics.hiitTimeInHighZonePct ?? -1)")
        }

        let snapshot = DailySnapshot(
            id: LocalDBProvider.snapshotID(for: dayStart),
            date: dayStart,
            steps: data.steps,
            sleepMinutes: data.sleepMinutes,
            restingHR: data.restingHR,
            baselineRHR: baselineHR,
            weightKg: data.weightKg,
            proteinG: data.proteinG,
            kcalTotal: data.kcalTotal,
            readiness: newMetrics.readiness,
            trainingReadiness: newMetrics.trainingReadiness ?? 0,
            trainingReadinessLabel: newMetrics.trainingReadinessLabel ?? "—",
            recoveryProgress: newMetrics.recoveryProgress ?? 0,
            lastTrainingType: newMetrics.lastTrainingType,
            lastTrainingScore: newMetrics.lastTrainingScore,
            analysisVersion: newMetrics.planAnalysisVersion ?? AISummaryBuilder.analysisVersion,
            dataQuality: .init(hasKcal: data.hasKcalTotal),
            createdAt: .now
        )
        local.upsertDailySnapshot(snapshot)
        log.info("DailySnapshot saved: id=\(snapshot.id, privacy: .public), kcalTotal=\(snapshot.kcalTotal ?? -1, privacy: .public), hasKcal=\(snapshot.dataQuality.hasKcal, privacy: .public)")

        if let follow = buildCoachFollowUpForToday(todaySnapshot: snapshot, yesterday: yesterday) {
            local.upsertCoachFollowUp(follow)
            followUp = follow
            log.info("CoachFollowUp saved: id=\(follow.id, privacy: .public), planDateId=\(follow.planDateId, privacy: .public)")
        } else {
            followUp = local.getCoachFollowUp(date: dayStart)
        }

        metrics = newMetrics
        if let cachedPlan = local.getCoachPlan(date: dayStart) {
            aiSummary = cachedPlan.planText
            aiLog.info("CoachPlan restored from DB: id=\(cachedPlan.id, privacy: .public), ver=\(cachedPlan.analysisVersion, privacy: .public)")
        } else {
            aiSummary = ""
        }
    }

    // MARK: - AI summary
    func runAI(goal: TrainingGoal, rules: CoachRuleOutput) async {
        aiBusy = true
        defer { aiBusy = false }

        let day = activeDay
        let diary = WorkoutDiarySummaryBuilder.makeSummary(for: day)

        var extra = "\n\nStrength metrics:\n"
        extra += "efficiency=\(metrics.strengthEfficiencyScore ?? -1)\n"
        extra += "restMedianSec=\(metrics.strengthRestMedianSec ?? -1)\n"
        extra += "restP90Sec=\(metrics.strengthRestP90Sec ?? -1)\n"
        extra += "avgHR=\(metrics.strengthAvgHR ?? -1)\n"
        extra += "maxHR=\(metrics.strengthMaxHR ?? -1)\n"
        extra += "waves=\(metrics.strengthWaveCount ?? -1)\n"
        extra += "recoveryDropMedian=\(metrics.strengthRecoveryDropMedianBpm ?? -1)\n"
        extra += "driftBpm=\(metrics.strengthDriftBpm ?? -1)\n"
        extra += "weakSpot=\(metrics.strengthWeakSpot ?? "none")\n"
        extra += "restRecommendedSec=\(metrics.restRecommendedSec ?? -1)\n"
        extra += "restDisciplineScore=\(metrics.restDisciplineScore ?? -1)\n"

        extra += "\nDiary:\n"
        extra += "totalSets=\(diary.totalSets), exercises=\(diary.exercisesCount), supersetExercises=\(diary.supersetExercisesCount)\n"
        if let ton = diary.approxTonnage {
            extra += "approxTonnage=\(Int(ton.rounded()))\n"
        }
        if !diary.topExercises.isEmpty {
            extra += "topExercises=\(diary.topExercises.prefix(10).joined(separator: " | "))\n"
        }

        // optional: HIIT block for AI
        if metrics.hiitDurationMin != nil {
            extra += "\nHIIT metrics:\n"
            extra += "hiitQualityScore=\(metrics.hiitQualityScore ?? -1)\n"
            extra += "hiitIntervals=\(metrics.hiitIntervalCount ?? -1)\n"
            extra += "hiitHighPct=\(metrics.hiitTimeInHighZonePct ?? -1)\n"
            extra += "hiitWorkMed=\(metrics.hiitWorkMedianSec ?? -1)\n"
            extra += "hiitRestMed=\(metrics.hiitRestMedianSec ?? -1)\n"
            extra += "hiitWeakSpot=\(metrics.hiitWeakSpot ?? "none")\n"
        }

        let prompt = AISummaryBuilder.makeDailyPrompt(from: metrics, goal: goal, rules: rules) + extra
        aiLog.info("AI plan version: \(AISummaryBuilder.analysisVersion, privacy: .public)")

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

            let parsed = parseCoachPlanSections(from: trimmed)
            let dayStart = day.startOfDay
            let plan = CoachPlan(
                id: LocalDBProvider.snapshotID(for: dayStart),
                date: dayStart,
                goal: goal,
                snapshotId: LocalDBProvider.snapshotID(for: dayStart),
                analysisVersion: AISummaryBuilder.analysisVersion,
                planText: trimmed,
                actions: parsed.actions,
                avoid: parsed.avoid,
                improve: parsed.improve,
                motivation: parsed.motivation,
                createdAt: .now
            )
            local.upsertCoachPlan(plan)
            aiLog.info("CoachPlan saved: id=\(plan.id, privacy: .public), actions=\(plan.actions.count, privacy: .public)")
        } catch {
            aiLog.error("AI error: \(error.localizedDescription, privacy: .public)")
            aiSummary = "Ошибка AI: \(error.localizedDescription)"
        }
    }

    private func parseCoachPlanSections(from text: String) -> (actions: [String], avoid: String, improve: String, motivation: String) {
        var sections: [Int: String] = [:]
        var currentIndex: Int?

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if let point = parsePointIndex(from: line) {
                currentIndex = point
                let withoutPrefix = stripPointPrefix(line, for: point)
                sections[point] = stripPointLabel(withoutPrefix, for: point)
                continue
            }

            guard let currentIndex else { continue }
            let previous = sections[currentIndex]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            sections[currentIndex] = previous.isEmpty ? line : "\(previous) \(line)"
        }

        let action1 = normalizedPointText(sections[1])
        let action2 = normalizedPointText(sections[2])
        let action3 = normalizedPointText(sections[3])
        let motivation = normalizedPointText(sections[4])

        return (
            actions: [action1, action2, action3],
            avoid: action2,
            improve: action3,
            motivation: motivation
        )
    }

    private func parsePointIndex(from line: String) -> Int? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes: [(Int, [String])] = [
            (1, ["1️⃣", "1)", "1.", "1:", "1 "]),
            (2, ["2️⃣", "2)", "2.", "2:", "2 "]),
            (3, ["3️⃣", "3)", "3.", "3:", "3 "]),
            (4, ["4️⃣", "4)", "4.", "4:", "4 "])
        ]

        for (index, values) in prefixes {
            if values.contains(where: { trimmed.hasPrefix($0) }) {
                return index
            }
        }
        return nil
    }

    private func stripPointPrefix(_ line: String, for point: Int) -> String {
        let variants: [String]
        switch point {
        case 1: variants = ["1️⃣", "1)", "1.", "1:", "1 "]
        case 2: variants = ["2️⃣", "2)", "2.", "2:", "2 "]
        case 3: variants = ["3️⃣", "3)", "3.", "3:", "3 "]
        case 4: variants = ["4️⃣", "4)", "4.", "4:", "4 "]
        default: variants = []
        }

        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in variants where trimmed.hasPrefix(prefix) {
            return String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    private func stripPointLabel(_ text: String, for point: Int) -> String {
        let labels: [String]
        switch point {
        case 1:
            labels = ["**Что делать:**", "Что делать:", "**Что делать**:", "Что делать —"]
        case 2:
            labels = ["**Чего избегать:**", "Чего избегать:", "**Чего избегать**:", "Чего избегать —"]
        case 3:
            labels = ["**Что улучшить:**", "Что улучшить:", "**Что улучшить**:", "Что улучшить —"]
        case 4:
            labels = ["**Мотивация:**", "Мотивация:", "**Мотивация**:", "Мотивация —"]
        default:
            labels = []
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for label in labels where trimmed.hasPrefix(label) {
            return String(trimmed.dropFirst(label.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    private func normalizedPointText(_ text: String?) -> String {
        let value = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "—" : value
    }

    private func buildCoachFollowUpForToday(todaySnapshot: DailySnapshot, yesterday: Date) -> CoachFollowUp? {
        let dayStart = todaySnapshot.date.startOfDay
        let yesterdayId = LocalDBProvider.snapshotID(for: yesterday)
        guard
            let yesterdayPlan = local.getCoachPlan(date: yesterday),
            let yesterdaySnapshot = local.getDailySnapshot(date: yesterday)
        else {
            return nil
        }

        let planText = "\(yesterdayPlan.planText)\n\(yesterdayPlan.actions.joined(separator: "\n"))".lowercased()
        let expectedProtein = planText.contains("бел") || planText.contains("protein")
        let expectedSteps = planText.contains("шаг")
        let expectedSleep = planText.contains("сон") || planText.contains("sleep") || planText.contains("спать")
        let expectedTraining = planText.contains("тренир") || planText.contains("hiit") || planText.contains("сил") || planText.contains("бег")

        let proteinTarget = inferredProteinTarget(from: yesterdayPlan)
        let stepsTarget = 9000
        let sleepTargetMin = 420

        let trainingDone = (yesterdaySnapshot.lastTrainingType?.isEmpty == false)
        let weightDelta: Double? = {
            guard let todayWeight = todaySnapshot.weightKg, let yesterdayWeight = yesterdaySnapshot.weightKg else { return nil }
            return todayWeight - yesterdayWeight
        }()

        return CoachFollowUp(
            id: LocalDBProvider.snapshotID(for: dayStart),
            date: dayStart,
            planDateId: yesterdayId,
            proteinHit: expectedProtein ? (yesterdaySnapshot.proteinG >= proteinTarget) : nil,
            stepsHit: expectedSteps ? (yesterdaySnapshot.steps >= stepsTarget) : nil,
            sleepHit: expectedSleep ? (yesterdaySnapshot.sleepMinutes >= sleepTargetMin) : nil,
            trainingDone: expectedTraining ? trainingDone : nil,
            weightDelta: weightDelta,
            restingHRDelta: todaySnapshot.restingHR - yesterdaySnapshot.restingHR,
            createdAt: .now
        )
    }

    private func inferredProteinTarget(from plan: CoachPlan) -> Int {
        let lines = plan.planText.components(separatedBy: .newlines)
        for line in lines {
            let lower = line.lowercased()
            guard lower.contains("бел") || lower.contains("protein") else { continue }
            let numbers = lower
                .split(whereSeparator: { !$0.isNumber })
                .compactMap { Int($0) }
            if let target = numbers.first(where: { $0 >= 40 && $0 <= 260 }) {
                return target
            }
        }

        switch plan.goal {
        case .maintain: return 120
        case .fatLoss: return 130
        case .muscleGain: return 150
        }
    }

    // MARK: - Activity factor
    private func computeActivityFactor(from trainings: [TrainingRow], in range: ClosedRange<Date>) -> Double {
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
        guard let last = details.trainings.sorted(by: { $0.endTime > $1.endTime }).first else {
            return nil
        }

        let durationMin = max(0, (last.endTime - last.startTime) / 60.0)
        let durScore = min(1.0, durationMin / 90.0) * 100.0

        let kcal = details.energyByTraining[last.id] ?? last.energyKcal ?? 0
        let energyScore = min(1.0, kcal / 1000.0) * 100.0

        let t = canonicalWorkoutType(last.type)
        let typeScore: Double
        if t == "HIIT" {
            typeScore = 100
        } else if t == "Functional Strength Training" {
            typeScore = 90
        } else if t == "Traditional Strength Training" || t == "Strength Training" {
            typeScore = 85
        } else if t == "Running" || t == "Cycling" {
            typeScore = 80
        } else if t == "Walking" || t == "Yoga" || t == "Stretching" {
            typeScore = 60
        } else {
            typeScore = 70
        }

        let score = 0.4 * durScore + 0.4 * energyScore + 0.2 * typeScore
        return max(0, min(100, Int(score.rounded())))
    }

    // MARK: - Intensity selection
    private func mostIntenseTrainingOfLatestDay(in trainings: [TrainingRow]) -> TrainingRow? {
        guard !trainings.isEmpty else { return nil }

        let latestDay = trainings
            .map { Date(timeIntervalSince1970: $0.endTime).startOfDay }
            .max()!

        let dayTrainings = trainings.filter {
            let end = Date(timeIntervalSince1970: $0.endTime)
            return Calendar.current.isDate(end, inSameDayAs: latestDay)
        }
        guard !dayTrainings.isEmpty else { return nil }

        func typeWeight(for type: String) -> Double {
            let t = canonicalWorkoutType(type)
            if t == "HIIT" { return 1.00 }
            if t == "Functional Strength Training" { return 0.90 }
            if t == "Traditional Strength Training" { return 0.90 }
            if t == "Strength Training" { return 0.90 }
            if t == "Running" || t == "Cycling" { return 0.80 }
            if t == "Walking" || t == "Yoga" || t == "Stretching" { return 0.50 }
            return 0.70
        }

        func kcal(for tr: TrainingRow) -> Double {
            details.energyByTraining[tr.id] ?? (tr.energyKcal ?? 0)
        }

        func minutes(for tr: TrainingRow) -> Double {
            let dur = tr.endTime - tr.startTime
            return max(0, dur) / 60.0
        }

        return dayTrainings.max { a, b in
            let scoreA = typeWeight(for: a.type) * 10
            + kcal(for: a) * 0.01
            + minutes(for: a) * 0.10

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
        let sl = min(1.0, Double(sleepMin) / 420.0)
        let r = 1.0 - min(1.0, max(0.0, Double(hrRest - baselineHR) / 25.0))
        let p = min(1.0, Double(proteinG) / Double(proteinTarget))

        var score = (s + sl + r + p) / 4.0 * 100.0
        score *= recoveryProgress

        return max(0, min(100, Int(score.rounded())))
    }

    // MARK: - Training readiness
    private func computeTrainingReadiness(
        sleepMin: Int,
        proteinG: Int,
        proteinTarget: Int,
        hrRestToday: Int,
        baselineHR: Int,
        lastTraining: TrainingRow?,
        now: Date = Date()
    ) -> (score: Int, label: String) {

        let sleepFactor = min(1.0, Double(sleepMin) / 420.0)
        let proteinFactor = min(1.0, Double(max(0, proteinG)) / Double(max(1, proteinTarget)))

        let rhrDelta = max(0, hrRestToday - baselineHR)
        let rhrFactor = 1.0 - min(1.0, Double(rhrDelta) / 25.0)

        let recLog = Logger(subsystem: "com.yourapp.fitglu", category: "Recovery")

        let last = lastTraining ?? details.trainings.sorted(by: { $0.endTime > $1.endTime }).first
        let lastTrainingType = last?.type ?? "Unknown"

        func hoursSince(_ unix: TimeInterval?) -> Double {
            guard let t = unix else { return .infinity }
            return now.timeIntervalSince(Date(timeIntervalSince1970: t)) / 3600.0
        }

        func recoveryWindowHours2(for type: String) -> Double {
            let raw = type
            let t = canonicalWorkoutType(type)
            var hours: Double = 24
            var matched: String = "default"

            switch t {
            case "Running":
                hours = 18; matched = "palette:running"
            case "Walking":
                hours = 12; matched = "palette:walking"
            case "Cycling":
                hours = 18; matched = "palette:cycling"
            case "Functional Strength Training":
                hours = 24; matched = "palette:functionalStrength"
            case "Traditional Strength Training":
                hours = 24; matched = "palette:traditionalStrength"
            case "Strength Training":
                hours = 24; matched = "palette:strength"
            case "HIIT":
                hours = 36; matched = "palette:hiit"
            case "Yoga", "Stretching":
                hours = 12; matched = "palette:light"
            default:
                hours = 24; matched = "fallback:default(24h)"
            }

            recLog.debug("Recovery map: raw='\(raw, privacy: .public)' -> norm='\(t, privacy: .public)', match=\(matched, privacy: .public), hours=\(hours, privacy: .public)")
            return hours
        }

        var trainingRecoveryFactor: Double = 1.0
        var isToday = false
        if let last {
            let hours = max(0, (now.timeIntervalSince1970 - last.endTime) / 3600.0)
            isToday = Calendar.current.isDateInToday(Date(timeIntervalSince1970: last.endTime))
            let window = recoveryWindowHours2(for: last.type)
            trainingRecoveryFactor = min(1.0, hours / window)
        }

        let score: Double
        let label: String

        if isToday {
            score =
            0.50 * proteinFactor +
            0.30 * sleepFactor +
            0.20 * rhrFactor
            label = "Recover"
        } else {
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
    private func computeProteinTarget(
        weightKg: Double?,
        leanMassKg: Double?,
        fatPercent: Double?,
        activityFactor: Double
    ) -> Int {
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
    var restingHR: Int?
    var baselineHR: Int?
    var planAnalysisVersion: String?
    var hrMax: Int
    var proteinG: Int
    var kcal: Double
    var glucoseFlag: String?
    var weightKg: Double?
    var weightDelta: Double?
    var proteinTarget: Int
    var coachTag1: String
    var coachTag2: String

    // recovery + ai
    var lastTrainingType: String?
    var hoursSinceLastTraining: Double?
    var nextTrainingInHours: Double?
    var recoveryProgress: Double?
    var trainingReadiness: Int?
    var trainingReadinessLabel: String?
    var lastTrainingScore: Int?
    var lastTrainingSummary: String?

    // Strength MVP
    var strengthAnalysisVersion: String?
    var strengthDurationMin: Int?
    var strengthAvgHR: Int?
    var strengthMaxHR: Int?
    var strengthWaveCount: Int?
    var strengthRestMedianSec: Int?
    var strengthRestP90Sec: Int?
    var strengthRecoveryDropMedianBpm: Int?
    var strengthDriftBpm: Int?
    var strengthEfficiencyScore: Int?
    var strengthWeakSpot: String?

    // Strength NEW
    var restRecommendedSec: Int?
    var restDisciplineScore: Int?

    // Diary NEW
    var diaryTotalSets: Int?
    var diaryExercisesCount: Int?
    var diarySupersetExercisesCount: Int?
    var diaryApproxTonnage: Int?
    var diaryTopExercises: [String]?

    // Data quality
    var strengthHasEnoughHR: Bool?

    // HIIT MVP
    var hiitAnalysisVersion: String?
    var hiitHasEnoughHR: Bool?
    var hiitDurationMin: Int?
    var hiitAvgHR: Int?
    var hiitMaxHR: Int?
    var hiitHighThresholdBpm: Int?
    var hiitLowThresholdBpm: Int?
    var hiitTimeInHighZoneSec: Int?
    var hiitTimeInHighZonePct: Int?
    var hiitIntervalCount: Int?
    var hiitWorkMedianSec: Int?
    var hiitRestMedianSec: Int?
    var hiitRecoverySlopeBpmPerMin: Int?
    var hiitQualityScore: Int?
    var hiitWeakSpot: String?

    // MARK: - Formatters
    var sleepString: String { "\(sleepMin / 60)h \(sleepMin % 60)m" }
    var stepsTargetString: String { "↗︎ \(stepsTarget) target" }
    var proteinTargetString: String { "\(proteinTarget) g target" }

    var weightString: String {
        guard let w = weightKg else { return "—" }
        return String(format: "%.1f kg", w)
    }

    var weightDeltaString: String? {
        guard let d = weightDelta else { return nil }
        let sign = d > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", d)) kg"
    }

    var recoveryProgressString: String? {
        guard let p = recoveryProgress else { return nil }
        return "\(Int((p * 100).rounded()))%"
    }

    static func formatMMSS(_ sec: Int?) -> String {
        guard let sec, sec > 0 else { return "—" }
        let m = sec / 60
        let s = sec % 60
        return String(format: "%d:%02d", m, s)
    }

    static let empty = DailyCoachMetrics(
        readiness: 0,
        steps: 0,
        stepsTarget: 9000,
        sleepMin: 0,
        restingHR: nil,
        baselineHR: 0,
        planAnalysisVersion: AISummaryBuilder.analysisVersion,
        hrMax: 0,
        proteinG: 0,
        kcal: 0,
        glucoseFlag: nil,
        weightKg: nil,
        weightDelta: nil,
        proteinTarget: 120,
        coachTag1: "—",
        coachTag2: "—",
        lastTrainingType: nil,
        hoursSinceLastTraining: nil,
        nextTrainingInHours: nil,
        recoveryProgress: nil,
        trainingReadiness: nil,
        trainingReadinessLabel: nil,
        lastTrainingScore: nil,
        lastTrainingSummary: nil,
        strengthAnalysisVersion: nil,
        strengthDurationMin: nil,
        strengthAvgHR: nil,
        strengthMaxHR: nil,
        strengthWaveCount: nil,
        strengthRestMedianSec: nil,
        strengthRestP90Sec: nil,
        strengthRecoveryDropMedianBpm: nil,
        strengthDriftBpm: nil,
        strengthEfficiencyScore: nil,
        strengthWeakSpot: nil,
        restRecommendedSec: nil,
        restDisciplineScore: nil,
        diaryTotalSets: nil,
        diaryExercisesCount: nil,
        diarySupersetExercisesCount: nil,
        diaryApproxTonnage: nil,
        diaryTopExercises: nil,
        strengthHasEnoughHR: nil,
        hiitAnalysisVersion: nil,
        hiitHasEnoughHR: nil,
        hiitDurationMin: nil,
        hiitAvgHR: nil,
        hiitMaxHR: nil,
        hiitHighThresholdBpm: nil,
        hiitLowThresholdBpm: nil,
        hiitTimeInHighZoneSec: nil,
        hiitTimeInHighZonePct: nil,
        hiitIntervalCount: nil,
        hiitWorkMedianSec: nil,
        hiitRestMedianSec: nil,
        hiitRecoverySlopeBpmPerMin: nil,
        hiitQualityScore: nil,
        hiitWeakSpot: nil
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
