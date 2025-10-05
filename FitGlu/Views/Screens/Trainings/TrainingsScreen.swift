import SwiftUI
import Charts

/// Корневой экран вкладки «Trainings».
struct TrainingsScreen: View {

    // MARK: – UI State
    @State var selectedDate = Date()
    @State var rangeStart: Date? = nil
    @State var rangeEnd: Date?   = nil

    @State var isLoading        = false
    /// OFF — индивидуальные из БД, ON — «220 − возраст»
    @State var useStandardZones = false
    @State var dayTotals = TimeInZone()

    // MARK: – Data
    @StateObject var detailsVM = DetailsViewModel()
    @State var qualities: [TrainingQuality]      = []
    @State var zoneChartData: [ZoneDayPoint] = []
    @State var chartMode: ZonesChartMode = .minutes
    @State var chartShowLegend: Bool = true
    @State var chartShowLabels: Bool = true
    @State var chartShowAvgBand: Bool = true
    @State var activeThresholds: ZoneThresholds? = nil
    @State var showZBSInfo = false
    @State var showINTInfo = false
    @State var showENEInfo = false

    // NEW: интенсивность
    @State var intensityDay  = DayIntensity(peakHRPercent: 0, timeAbove90: 0, sawRedZone: false, hrRPE10: 0)
    @State var intensityList: [TrainingIntensity] = []
    
    @State var eneList: [EnergyTrainingEfficiency] = []
    @State var eneDay  = EnergyDayEfficiency(totalKcal: 0, totalStressSec: 0, kcalPerStressMin: 0)
    
    @State var computedHRMax: Int = 0
    @State var computedHRRest: Int = 0

    // ADD: AI (ChatGPT)
    @State var showAISheet = false
    @State var aiBusy = false
    @State var aiOutput = "—"
    @State var showAIInfo = false
    @State var aiInfoText = "—"
    let ai = ChatGPTProvider()
    
    private var periodInfo: PeriodHeaderView.Info? {
        guard let s = rangeStart, let e = rangeEnd, !zoneChartData.isEmpty else { return nil }
        let days = Set(zoneChartData.map { Calendar.current.startOfDay(for: $0.date) }).count
        let totalMin = Int(zoneChartData.reduce(0) { $0 + $1.total }.rounded())
        let avgPerDay = days > 0 ? Int((Double(totalMin)/Double(days)).rounded()) : totalMin
        let workouts = qualities.count // у тебя TrainingQuality на тренировку
        let kcal = Int(eneDay.totalKcal.rounded())
        // ZBS среднее по тренировкам, если хочется
        let avgZBS = qualities.isEmpty
            ? nil
            : Int((qualities.map(\.zoneBalanceScore).reduce(0,+) / Double(qualities.count)).rounded())
        return .init(start: s, end: e, daysCount: days, workoutsCount: workouts,
                     totalMinutes: totalMin, avgPerDay: avgPerDay, avgZBS: avgZBS, kcal: kcal)
    }
    
    private var isRangeMode: Bool {
        if let s = rangeStart, let e = rangeEnd {
            return Calendar.current.startOfDay(for: s) < Calendar.current.startOfDay(for: e)
        }
        return false
    }
    
    private var chartPointsForUI: [ZoneDayPoint] {
        guard isRangeMode else { return [] }
        switch chartMode {
        case .minutes: return zoneChartData
        case .percent: return zoneChartData.map { $0.asPercent() }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // ⬇️ НОВЫЙ УМНЫЙ КАЛЕНДАРЬ (день/диапазон + пресеты)
                    DateSmartHeader(
                        selectedDate: $selectedDate,
                        rangeStart: $rangeStart,
                        rangeEnd: $rangeEnd,
                        supportsRange: true
                    )
                    .onChange(of: selectedDate) { _, _ in Task { await loadData() } }
                    .onChange(of: rangeStart)   { _, _ in Task { await loadData() } }
                    .onChange(of: rangeEnd)     { _, _ in Task { await loadData() } }

                    zoneModeToggle
                    if let t = activeThresholds { ZonesBarView(thresholds: t) }

                    if isLoading {
                        ProgressView("Loading…")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 24)
                    }
                    else if isRangeMode {
                        if let info = periodInfo {
                            PeriodHeaderView(info: info)
                        }
                        Picker("", selection: $chartMode) {
                            Text("Minutes").tag(ZonesChartMode.minutes)
                            Text("Percent").tag(ZonesChartMode.percent)
                        }
                        .pickerStyle(.segmented)
                        
                        HStack(spacing: 12) {
                            Toggle("Legend", isOn: $chartShowLegend)
                                .toggleStyle(.switch).font(.caption)
                            Toggle("Labels", isOn: $chartShowLabels)
                                .toggleStyle(.switch).font(.caption)
                            Toggle("Avg band", isOn: $chartShowAvgBand)
                                .toggleStyle(.switch).font(.caption)
                                .disabled(chartMode == .percent) // в процентах нет среднего
                                .opacity(chartMode == .percent ? 0.5 : 1)
                        }
                        .padding(.top, 4)

                        if zoneChartData.isEmpty {
                            Text("No trainings for the selected period.")
                                .foregroundStyle(.secondary)
                        } else {
                            ZonesStackedChart(
                                data: zoneChartData,
                                mode: chartMode,
                                showLegend: true,
                                showValueLabels: true,
                                showPeriodSummary: true
                            )
                            .frame(height: 260)
                            .padding(.vertical, 8)
                        }
                    }
                    else if qualities.isEmpty {
                        Text(rangeStart != nil && rangeEnd != nil ? "No trainings for the selected period." : "No trainings for the selected day.")
                            .foregroundStyle(.secondary)
                    } else {
                        // Средний балл (по треням)
                        let avgScore = qualities.map(\.zoneBalanceScore).reduce(0, +) / Double(max(1, qualities.count))

                        MetricAccordion(
                            title: "Zone Balance",
                            summary: { showChips in
                                ZBSSummary(avg: avgScore, totals: dayTotals, showChips: showChips)
                            },
                            collapsedBar: { ZBSCompactBar(score: avgScore) },
                            content: { TrainingQualityList(qualities: qualities) },
                            onInfoTap: { showZBSInfo = true }
                        )
                        .environment(\.initialExpanded, false)
                        .sheet(isPresented: $showZBSInfo) { ZBSInfoSheet() }
                        .padding(.vertical, 4)

                        // Интенсивность
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
                        
                        // Энергия
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
                        .sheet(isPresented: $showENEInfo) { ENEInfoSheet() }
                    }
                }
                .padding()
            }
            .navigationTitle("🏋️ Trainings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await aiAnalyzeDay() }
                    } label: {
                        Label("Ask AI", systemImage: "sparkles")
                    }
                    .disabled(aiBusy)
                }
            }
            .sheet(isPresented: $showAIInfo) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AI анализ")
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
    var zoneModeToggle: some View {
        Toggle(isOn: $useStandardZones) {
            Label("Standard zones (220 − age)", systemImage: "heart.text.square")
        }
        .toggleStyle(.switch)
        .onChange(of: useStandardZones) { _, _ in Task { await loadData(force: true) } }
    }
}

