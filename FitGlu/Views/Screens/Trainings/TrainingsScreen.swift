import SwiftUI

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
                    } else if qualities.isEmpty {
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

