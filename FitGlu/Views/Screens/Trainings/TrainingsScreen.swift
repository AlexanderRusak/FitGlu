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
            .task { await loadData() }
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
        
        print("energyByTraining:", detailsVM.energyByTraining)
    }

    /// OFF → индивидуальные из БД, ON → «220 − возраст»
    func currentThresholds() -> ZoneThresholds {
        if useStandardZones {
            return DefaultZonesProvider.estimate(age: detailsVM.userAge ?? 30)
        }
        return (try? AverageZonesDBManager.shared.fetchAverageZones())
            ?? DefaultZonesProvider.estimate(age: detailsVM.userAge ?? 30)
    }
    
}
