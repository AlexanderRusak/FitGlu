import SwiftUI

/// Корневой экран вкладки «Trainings».
struct TrainingsScreen: View {

    // MARK: – UI State
    @State private var selectedDate     = Date()
    @State private var showPicker       = true
    @State private var isLoading        = false
    /// OFF — индивидуальные из БД, ON — «220 − возраст»
    @State private var useStandardZones = false
    @State private var dayTotals = TimeInZone()

    // MARK: – Data
    @StateObject private var detailsVM = DetailsViewModel()
    @State private var qualities: [TrainingQuality]      = []
    @State private var activeThresholds: ZoneThresholds? = nil
    @State private var showZBSInfo = false
    @State private var showINTInfo = false
    @State private var showENEInfo = false

    // NEW: интенсивность
    @State private var intensityDay  = DayIntensity(peakHRPercent: 0, timeAbove90: 0, sawRedZone: false, hrRPE10: 0)
    @State private var intensityList: [TrainingIntensity] = []
    
    @State private var eneList: [EnergyTrainingEfficiency] = []
    @State private var eneDay  = EnergyDayEfficiency(totalKcal: 0, totalStressSec: 0, kcalPerStressMin: 0)

    // ADD: AI (ChatGPT)
    @State private var showAISheet = false
    @State private var aiBusy = false
    @State private var aiOutput = "—"
    @State private var showAIInfo = false
    @State private var aiInfoText = "—"
    private let ai = ChatGPTProvider()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerView
                    if showPicker { datePickerView }

                    zoneModeToggle
                    if let t = activeThresholds { ZonesBarView(thresholds: t) }

                    if isLoading {
                        ProgressView("Loading…")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 24)
                    } else if qualities.isEmpty {
                        Text("No trainings for the selected day.")
                            .foregroundStyle(.secondary)
                    } else {
                        // Средний балл дня (ZBS)
                        let avgScore = qualities.map(\.zoneBalanceScore).reduce(0, +) / Double(qualities.count)

                        MetricAccordion(
                            title: "Zone Balance",
                            summary: { showChips in
                                ZBSSummary(avg: avgScore, totals: dayTotals, showChips: showChips)
                            },
                            collapsedBar: { ZBSCompactBar(score: avgScore) },
                            content: { TrainingQualityList(qualities: qualities) },
                            onInfoTap: { showZBSInfo = true }          // ← это рисует и активирует «i»
                        )
                        .environment(\.initialExpanded, false)
                        .sheet(isPresented: $showZBSInfo) { ZBSInfoSheet() }
                        .padding(.vertical, 4)

                        // Новая метрика — Intensity & Peaks
                        MetricAccordion(
                            title: "Intensity & Peaks",
                            summary: { showChips in INTSummary(day: intensityDay, showChips: showChips) },
                            collapsedBar: { RPECompactBar(rpe: intensityDay.hrRPE10) },
                            content: { IntensityList(metrics: intensityList) },
                            onInfoTap: { showINTInfo = true }
                        )
                        .environment(\.initialExpanded, false)
                        .sheet(isPresented: $showINTInfo) { INTInfoSheet() }
                        .padding(.vertical, 4)
                        
                        MetricAccordion(
                            title: "Energy Efficiency",
                            summary: { showChips in
                                ENESummary(day: eneDay, showChips: showChips)
                            },
                            collapsedBar: {
                                ENECompactBar(eff: eneDay.kcalPerStressMin)
                            },
                            content: {
                                ENEList(items: eneList)
                            },
                            onInfoTap: { showENEInfo = true }
                        )
                        .environment(\.initialExpanded, false)
                        .padding(.vertical, 4)
                        .sheet(isPresented: $showENEInfo) { ENEInfoSheet() } // ↓ см. ниже
                    }
                }
                .padding()
            }
            .navigationTitle("🏋️ Trainings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await aiAnalyzeDay() }   // было aiPing()
                    } label: {
                        Label("Ask AI", systemImage: "sparkles")
                    }
                    .disabled(aiBusy)
                }
            }
            .sheet(isPresented: $showAIInfo) {   // NEW
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AI анализ дня")
                            .font(.headline)
                        Text(aiInfoText)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                    }
                    .padding()
                }
                .presentationDetents([.medium, .large])
            }
            .alert("AI reply", isPresented: $showAISheet) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(aiOutput)
            }
            .task { await loadData() }
            .overlay {
                if aiBusy {
                    ProgressView("AI…")
                        .padding(16)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

// MARK: – UI sub-views
extension TrainingsScreen {

    var headerView: some View {
        HStack {
            Text(selectedDate, format: .dateTime.month(.wide).year())
                .font(.title3).bold()
            Spacer()
            Button(showPicker ? "Hide calendar" : "Show calendar") {
                withAnimation { showPicker.toggle() }
            }
        }
    }

    var datePickerView: some View {
        DatePicker("Pick a date", selection: $selectedDate, displayedComponents: .date)
            .datePickerStyle(.graphical)
            .onChange(of: selectedDate) { _, _ in Task { await loadData() } }
    }

    var zoneModeToggle: some View {
        Toggle(isOn: $useStandardZones) {
            Label("Standard zones (220 − age)", systemImage: "heart.text.square")
        }
        .toggleStyle(.switch)
        .onChange(of: useStandardZones) { _, _ in Task { await computeQuality() } }
    }
}

// MARK: – Loading / calculations
extension TrainingsScreen {

    @MainActor
    func loadData(force: Bool = false) async {
        guard !isLoading || force else { return }
        isLoading = true
        defer { isLoading = false }

        // очистим предыдущее
        qualities = []
        intensityList = []
        intensityDay = DayIntensity(peakHRPercent: 0, timeAbove90: 0, sawRedZone: false, hrRPE10: 0)
        dayTotals = .init()

        await detailsVM.load(for: selectedDate)   // тренировки / HR / глюкоза
        await computeQuality()
    }

    @MainActor
    func computeQuality() async {
        let thresholds = currentThresholds()
        activeThresholds = thresholds

        let analyzer = DailyAnalyzer(thresholds: thresholds)

        // 1) Качество (TIZ/ZBS)
        qualities = analyzer.analyzeDay(
            trainings: detailsVM.trainings,
            hrSegments: detailsVM.hrSegments
        )

        // 2) Индивидуальные HRmax/HRrest
        let hrMax  = DailyAnalyzer.estimateHRMax(from: thresholds, age: detailsVM.userAge)
        let hrRest = DailyAnalyzer.estimateHRRest(from: detailsVM.hrDailyPoints)

        // 3) Интенсивность
        intensityList = analyzer.intensityForTrainings(
            trainings: detailsVM.trainings,
            hrSegments: detailsVM.hrSegments,
            hrMax: hrMax,
            hrRest: hrRest
        )
        intensityDay = analyzer.intensityForDay(
            trainings: detailsVM.trainings,
            hrSegments: detailsVM.hrSegments,
            hrMax: hrMax,
            hrRest: hrRest
        )

        // 4) Сумма зон за день — для чипов в свёрнутой шапке ZBS
        dayTotals = qualities.reduce(TimeInZone()) { acc, q in
            var t = acc;  let m = q.tiz
            t.rec += m.rec; t.fat += m.fat; t.tran += m.tran
            t.ana += m.ana; t.stress += m.stress; return t
        }
        
        // Провайдер калорий ровно под сигнатуру: (TrainingRow) -> Double?
        let eneProvider: (TrainingRow) -> Double? = { tr in
            detailsVM.energyByTraining[tr.id]    // вернёт Double? (nil если нет)
        }

        let list: [EnergyTrainingEfficiency] =  analyzer.energyEfficiencyForTrainings(
            trainings: detailsVM.trainings,
            hrSegments: detailsVM.hrSegments,
            kcalProvider: eneProvider
        )
        let day: EnergyDayEfficiency =  analyzer.energyEfficiencyForDay(
            trainings: detailsVM.trainings,
            hrSegments: detailsVM.hrSegments,
            kcalProvider: eneProvider
        )

        self.eneList = list
        self.eneDay  = day
    }
    
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
                let hrMax  = DailyAnalyzer.estimateHRMax(from: t, age: detailsVM.userAge)
                let hrRest = DailyAnalyzer.estimateHRRest(from: detailsVM.hrDailyPoints)

                let zonesBPM = t.asBPMDictionary()   // ← используем расширение
                if !zonesBPM.isEmpty {
                    ctx = .init(hrMax: hrMax, hrRest: hrRest, zonesBPM: zonesBPM)
                }
            }

            return AIDayMetrics(
                dateISO: selectedDate.isoDate,
                zoneBalance: zone,
                intensity: intnt,
                energy: ene,
                context: ctx
            )
        }

    /// OFF → индивидуальные из БД, ON → «220 − возраст»
    func currentThresholds() -> ZoneThresholds {
        if useStandardZones {
            return DefaultZonesProvider.estimate(age: detailsVM.userAge ?? 30)
        }
        return (try? AverageZonesDBManager.shared.fetchAverageZones())
            ?? DefaultZonesProvider.estimate(age: detailsVM.userAge ?? 30)
    }
    
    private func formatZones(_ zones: [String: ClosedRange<Int>]) -> String {
        // Сортнём по «типичному» порядку
        let order = ["Recovery","Fat","Trans","Ana","Stress"]
        return order.compactMap { key in
            guard let r = zones[key] else { return nil }
            return "\(key): \(r.lowerBound)–\(r.upperBound) bpm"
        }.joined(separator: ", ")
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

        return """
        Ты — строгий и поддерживающий эксперт по фитнесу и композиции тела. Твоя цель — помочь человеку выглядеть лучше (жиросжигание, рельеф, осанка), при этом сохранять здоровье, мотивацию и прогресс. Пиши по-русски, кратко и уверенно.

        Проанализируй день \(m.dateISO).

        [Тренировки по отдельности]
        \(perWorkout)

        [Итоги дня]
        • Zone Balance дня: \(m.zoneBalance.zbsScore)/100; суммарные минуты — Rec \(m.zoneBalance.timeRecovMin), Fat \(m.zoneBalance.timeFatMin), Trans \(m.zoneBalance.timeTransMin), Ana \(m.zoneBalance.timeAnaMin), Stress \(m.zoneBalance.timeStressMin).
        • Intensity & Peaks: RPE \(m.intensity.rpe10)/10; пик HR \(m.intensity.peakHRPercent)% от HRmax; ≥90% HR — \(m.intensity.timeAt90plusMin) мин; красная зона: \(m.intensity.sawRedZone ? "да" : "нет").
        • Energy: всего \(m.energy.totalKcal) ккал; стресс \(m.energy.stressSeconds/60) мин; ккал/стресс-мин \(m.energy.kcalPerStressMin.map { String(format: "%.1f", $0) } ?? "—").\(zoneInfo)

        [Задача]
        1) Короткий разбор КАЖДОЙ тренировки: что сработало для формы (жир/тонус), что лишнее/опасно.
        2) Общий вывод дня: баланс зон, интенсивность, эффективность с точки зрения цели «выглядеть лучше».
        3) 1–3 конкретных рекомендации на завтра (зона, объём, интенсивность/шаги; при необходимости — короткая ремарка по восстановлению/сну).
        4) Признаки прогресса или перегрузки и что сегодня/завтра лучше не делать.
        5) Заверши одной мотивирующей фразой тренера.

        Пиши списком, без воды. Если данных недостаточно — явно укажи, что не хватает (но всё равно дай краткий план).
        """
    }
}
