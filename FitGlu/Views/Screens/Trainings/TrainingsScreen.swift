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

    // MARK: – Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    headerView
                    if showPicker { datePickerView }

                    zoneModeToggle
                    if let t = activeThresholds { ZonesBarView(thresholds: t) }

                    // ———————————  ЭТОТ кусок заменяет старый вывод карточек ——————————
                    if isLoading {
                        ProgressView("Loading…")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 24)

                    } else if qualities.isEmpty {
                        Text("No trainings for the selected day.")
                            .foregroundStyle(.secondary)

                    } else {

                        // Средний балл + суммарные минуты
                        let avg = qualities.map(\.zoneBalanceScore).reduce(0, +)
                                  / Double(qualities.count)

                        MetricAccordion(
                            title: "Zone Balance",
                            summary: { showChips in
                                ZBSSummary(
                                    avg: avg,
                                    totals: dayTotals,
                                    showChips: showChips
                                )
                            },
                            content: { TrainingQualityList(qualities: qualities) }
                        )
                        .environment(\.initialExpanded, false) // кастомный env, см. ниже
                        .padding(.vertical, 4)
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

        await detailsVM.load(for: selectedDate)   // тренировки / HR / глюкоза
        await computeQuality()
    }

    @MainActor
    func computeQuality() async {
        let thresholds = currentThresholds()
        activeThresholds = thresholds

        let analyzer = DailyAnalyzer(thresholds: thresholds)
        qualities = analyzer.analyzeDay(
            trainings: detailsVM.trainings,
            hrSegments: detailsVM.hrSegments
        )

        // суммарные зоны за день — для чипов в шапке
        dayTotals = qualities.reduce(TimeInZone()) { acc, q in
            var t = acc;  let m = q.tiz
            t.rec += m.rec; t.fat += m.fat; t.tran += m.tran
            t.ana += m.ana; t.stress += m.stress; return t
        }
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
