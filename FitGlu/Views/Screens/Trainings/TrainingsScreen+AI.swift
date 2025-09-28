import SwiftUI

extension TrainingsScreen {
    @MainActor
    func aiPing() async {
        aiBusy = true
        print("ENV OPENAI_API_KEY:", ProcessInfo.processInfo.environment["OPENAI_API_KEY"] as Any)
        print("PLIST OPENAI_API_KEY:", Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as Any)
        print("CONFIG apiKey is empty?", OpenAIConfig.apiKey.isEmpty)
        defer { aiBusy = false }

        do {
            let reply = try await ai.send(messages: [
                .init(role: .system, content: "You are a concise assistant."),
                .init(role: .user, content: "Say 'pong' if you can hear me.")
            ])
            aiOutput = reply
        } catch {
            aiOutput = "Error: \(error.localizedDescription)"
        }
        showAISheet = true
    }

    @MainActor
    func aiAnalyzeDay() async {
        aiBusy = true
        defer { aiBusy = false }

        let dayPayload = buildAIDayMetrics()
        let perWorkoutPayload = buildAITrainingMetricsList()
        let prompt = makeDayPrompt(day: dayPayload, trainings: perWorkoutPayload)

        do {
            let reply: String = try await ai.send(messages: [
                .init(role: .system, content: "Ты краткий, точный и мотивирующий спортивный врач-аналитик."),
                .init(role: .user, content: prompt)
            ], temperature: 0.4)
            aiInfoText = reply.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            showAIInfo = true
        } catch {
            aiInfoText = "Ошибка: \(error.localizedDescription)"
            showAIInfo = true
        }
    }

    @MainActor
    func buildAITrainingMetricsList() -> [AITrainingMetrics] {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"

        // Индексы по id тренировки
        let qById:   [Int64: TrainingQuality]          = qualities.reduce(into: [:]) { $0[$1.training.id] = $1 }
        let intById: [Int64: TrainingIntensity]        = intensityList.reduce(into: [:]) { $0[$1.training.id] = $1 }
        let eneById: [Int64: EnergyTrainingEfficiency] = eneList.reduce(into: [:]) { $0[$1.training.id] = $1 }

        var result: [AITrainingMetrics] = []

        for tr in detailsVM.trainings {
            let start = Date(timeIntervalSince1970: tr.startTime)
            let end   = Date(timeIntervalSince1970: tr.endTime)

            // --- Zone Balance (из TrainingQuality) ---
            var zbs = AIDayMetrics.ZoneBalance(
                zbsScore: 0, timeRecovMin: 0, timeFatMin: 0, timeTransMin: 0, timeAnaMin: 0, timeStressMin: 0
            )
            if let q = qById[tr.id] {
                zbs = .init(
                    zbsScore: Int(q.zoneBalanceScore.rounded()),
                    timeRecovMin: q.tiz.rec.minutesRounded,
                    timeFatMin:   q.tiz.fat.minutesRounded,
                    timeTransMin: q.tiz.tran.minutesRounded,
                    timeAnaMin:   q.tiz.ana.minutesRounded,
                    timeStressMin:q.tiz.stress.minutesRounded
                )
            }

            // --- Intensity (per-workout; RPE берём дневной как прокси) ---
            var intn = AIDayMetrics.Intensity(rpe10: 0, peakHRPercent: 0, timeAt90plusMin: 0, sawRedZone: false, setsCount: nil)
            if let im = intById[tr.id] {
                intn = .init(
                    rpe10:           intensityDay.hrRPE10,
                    peakHRPercent:   Int(im.peakHRPercent),
                    timeAt90plusMin: (im.timeAbove90 as Double).minutesRounded,
                    sawRedZone:      im.sawRedZone,
                    setsCount:       nil
                )
            }

            // --- Energy (из EnergyTrainingEfficiency; фолбэк — словарь HK) ---
            var ene = AIDayMetrics.Energy(totalKcal: 0, stressSeconds: 0, kcalPerStressMin: nil)
            if let em = eneById[tr.id] {
                ene = .init(
                    totalKcal:        Int(em.kcal.rounded()),
                    stressSeconds:    Int(em.stressSec),
                    kcalPerStressMin: (em.kcalPerStressMin == 0 ? nil : em.kcalPerStressMin)
                )
            } else if let kcal = detailsVM.energyByTraining[tr.id] {
                ene = .init(totalKcal: Int(kcal.rounded()), stressSeconds: 0, kcalPerStressMin: nil)
            }

            result.append(
                AITrainingMetrics(
                    id: tr.id,
                    title: tr.type,
                    startHHmm: df.string(from: start),
                    endHHmm: df.string(from: end),
                    zoneBalance: zbs,
                    intensity: intn,
                    energy: ene
                )
            )
        }

        return result
    }

    // ADD: собираем объект на основе уже посчитанных метрик экрана
    @MainActor
        func buildAIDayMetrics() -> AIDayMetrics {
            // --- ZBS ---
            let z = dayTotals
            let zbsScore = Int(
                qualities.map(\.zoneBalanceScore).reduce(0, +) / max(1, Double(qualities.count))
            )
            let zone = AIDayMetrics.ZoneBalance(
                zbsScore: zbsScore,
                timeRecovMin: z.rec.minutesRounded,
                timeFatMin:   z.fat.minutesRounded,
                timeTransMin: z.tran.minutesRounded,
                timeAnaMin:   z.ana.minutesRounded,
                timeStressMin:z.stress.minutesRounded
            )

            // --- Intensity ---
            let intnt = AIDayMetrics.Intensity(
                rpe10:           intensityDay.hrRPE10,
                peakHRPercent:   Int(intensityDay.peakHRPercent),
                timeAt90plusMin: (intensityDay.timeAbove90 as Double).minutesRounded,
                sawRedZone:      intensityDay.sawRedZone,
                setsCount:       intensityList.count
            )

            // --- Energy ---
            let ene = AIDayMetrics.Energy(
                totalKcal:        Int(eneDay.totalKcal.rounded()),
                stressSeconds:    Int(eneDay.totalStressSec),
                kcalPerStressMin: eneDay.kcalPerStressMin == 0 ? nil : eneDay.kcalPerStressMin
            )

            // --- Context (индивидуальные зоны) ---
            var ctx: AIDayMetrics.Context? = nil
            if let t = activeThresholds {
                let hrMax  = computedHRMax
                let hrRest = computedHRRest
                let zonesBPM = t.asBPMDictionary()

                ctx = .init(
                    hrMax: hrMax,
                    hrRest: hrRest,
                    zonesBPM: zonesBPM,
                    steps: detailsVM.dailySteps,
                    sleepMin: detailsVM.dailySleepMin,
                    proteinG: detailsVM.dailyProteinG,
                    age: detailsVM.userAge,
                    sex: detailsVM.userSex?.stringValue,
                    bodyMassKg: detailsVM.dailyBodyMassKg
                )
            }

            return AIDayMetrics(
                dateISO: selectedDate.isoDate,
                zoneBalance: zone,
                intensity: intnt,
                energy: ene,
                context: ctx
            )
        }

    func makeDayPrompt(day m: AIDayMetrics, trainings tm: [AITrainingMetrics]) -> String {
        let zoneInfo: String = {
            guard let c = m.context else { return "" }
            return "\nИндивидуальные зоны (bpm): \(formatZones(c.zonesBPM)). HRmax=\(c.hrMax)\(c.hrRest.map { ", HRrest=\($0)" } ?? "")."
        }()

        let perWorkout: String = tm.map { t in
            "• \(t.title) (\(t.startHHmm)–\(t.endHHmm)): ZBS \(t.zoneBalance.zbsScore)/100; " +
            "зоны (мин): Rec \(t.zoneBalance.timeRecovMin), Fat \(t.zoneBalance.timeFatMin), Trans \(t.zoneBalance.timeTransMin), Ana \(t.zoneBalance.timeAnaMin), Stress \(t.zoneBalance.timeStressMin); " +
            "Intensity: RPE \(t.intensity.rpe10)/10, пик \(t.intensity.peakHRPercent)%, ≥90% \(t.intensity.timeAt90plusMin) мин; " +
            "Energy: \(t.energy.totalKcal) ккал" +
            (t.energy.kcalPerStressMin != nil ? ", \(String(format: "%.1f", t.energy.kcalPerStressMin!)) ккал/стресс-мин" : "")
        }.joined(separator: "\n")

        let lifestyle = lifestyleLine(m.context)
        
        let personal: String = {
            guard let c = m.context else { return "" }
            var parts: [String] = []
            if let a = c.age { parts.append("возраст \(a)") }
            if let s = c.sex { parts.append("пол \(s)") }
            if let w = c.bodyMassKg { parts.append("вес \(Int(w.rounded())) кг") }
            return parts.isEmpty ? "" : "\nПерсональные данные: " + parts.joined(separator: ", ") + "."
        }()
        
        let prompt = """
        Ты — строгий и поддерживающий эксперт по фитнесу и композиции тела. Твоя цель — помочь человеку выглядеть лучше (жиросжигание, рельеф, осанка), при этом сохранять здоровье, мотивацию и прогресс. Пиши по-русски, кратко и уверенно.

        Проанализируй день \(m.dateISO).

        [Тренировки по отдельности]
        \(perWorkout)

        [Итоги дня]
        • Zone Balance дня: \(m.zoneBalance.zbsScore)/100; суммарные минуты — Rec \(m.zoneBalance.timeRecovMin), Fat \(m.zoneBalance.timeFatMin), Trans \(m.zoneBalance.timeTransMin), Ana \(m.zoneBalance.timeAnaMin), Stress \(m.zoneBalance.timeStressMin).
        • Intensity & Peaks: RPE \(m.intensity.rpe10)/10; пик HR \(m.intensity.peakHRPercent)% от HRmax; ≥90% HR — \(m.intensity.timeAt90plusMin) мин; красная зона: \(m.intensity.sawRedZone ? "да" : "нет").
        • Energy: всего \(m.energy.totalKcal) ккал; стресс \(m.energy.stressSeconds/60) мин; ккал/стресс-мин \(m.energy.kcalPerStressMin.map { String(format: "%.1f", $0) } ?? "—").\(zoneInfo)\(lifestyle)\(personal)

        [Задача]
        1) Короткий разбор КАЖДОЙ тренировки: что сработало для формы (жир/тонус), что лишнее/опасно.
        2) Общий вывод дня: баланс зон, интенсивность, эффективность с точки зрения цели «выглядеть лучше».
        3) Учитывая шаги/сон/белок из контекста, дай 1–3 конкретных рекомендации на завтра (зона, объём, интенсивность/шаги; при необходимости — ремарка по восстановлению/сну/питанию).
        4) Признаки прогресса или перегрузки и что сегодня/завтра лучше не делать.
        5) Заверши одной мотивирующей фразой тренера.

        Пиши списком, без воды. Если данных недостаточно — явно укажи, чего не хватает (но всё равно дай краткий план).
        """
        
        return prompt
    }

    func formatZones(_ zones: [String: ClosedRange<Int>]) -> String {
        // Сортнём по «типичному» порядку
        let order = ["Recovery","Fat","Trans","Ana","Stress"]
        return order.compactMap { key in
            guard let r = zones[key] else { return nil }
            return "\(key): \(r.lowerBound)–\(r.upperBound) bpm"
        }.joined(separator: ", ")
    }
    
    func lifestyleLine(_ c: AIDayMetrics.Context?) -> String {
        guard let c else { return "" }
        var parts: [String] = []
        if let s  = c.steps,     s  > 0 { parts.append("шаги \(s)") }
        if let sl = c.sleepMin,  sl > 0 { parts.append("сон \(sl) мин") }
        if let p  = c.proteinG,  p  > 0 { parts.append("белок \(Int(p.rounded())) г") }
        return parts.isEmpty ? "" : "\nДоп. контекст: " + parts.joined(separator: ", ") + "."
    }
}
