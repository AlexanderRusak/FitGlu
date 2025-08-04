import SwiftUI

/// Корневой экран вкладки «Trainings».
struct TrainingsScreen: View {

    // MARK: – UI State
    @State private var selectedDate     = Date()
    @State private var showPicker       = true
    @State private var isLoading        = false
    /// OFF — индивидуальные из БД, ON — «220 − возраст»
    @State private var useStandardZones = false

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

                    trainingsMetricsView
                }
                .padding()
            }
            .navigationTitle("🏋️ Trainings")
            .task { await loadData() }          // автозагрузка при первом появлении
        }
    }
}

// MARK: – UI-подкомпоненты
extension TrainingsScreen {

    /// Заголовок + кнопка «показать/скрыть календарь»
    var headerView: some View {
        HStack {
            Text(selectedDate, format: .dateTime.month(.wide).year())
                .font(.title3).bold()
            Spacer()
            Button(showPicker ? "Скрыть календарь" : "Показать календарь") {
                withAnimation { showPicker.toggle() }
            }
        }
    }

    /// Графический DatePicker
    var datePickerView: some View {
        DatePicker("Выберите дату", selection: $selectedDate, displayedComponents: .date)
            .datePickerStyle(.graphical)
            .onChange(of: selectedDate) { _, _ in Task { await loadData() } }
    }

    /// Тумблер «Стандартные зоны»
    var zoneModeToggle: some View {
        Toggle(isOn: $useStandardZones) {
            Label("Стандартные зоны (220−возраст)", systemImage: "heart.text.square")
        }
        .toggleStyle(.switch)
        .onChange(of: useStandardZones) { _, _ in Task { await computeQuality() } }
    }

    /// Блок карточек/заглушек
    var trainingsMetricsView: some View {
        Group {
            if isLoading {
                ProgressView("Загружаем данные…")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else if qualities.isEmpty {
                Text("Нет данных по тренировкам за выбранный день.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(qualities) { TrainingQualityCard(q: $0) }
                }
            }
        }
    }
}

// MARK: – Загрузка / расчёт
extension TrainingsScreen {

    @MainActor
    func loadData(force: Bool = false) async {
        guard !isLoading || force else { return }
        isLoading = true
        defer { isLoading = false }

        await detailsVM.load(for: selectedDate)        // подтягиваем тренировки/HR/глюкозу
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
    }

    /// OFF → индивидуальные из БД, ON → дефолт «220 − возраст»
    func currentThresholds() -> ZoneThresholds {
        if useStandardZones {
            return DefaultZonesProvider.estimate(age: detailsVM.userAge ?? 30)
        }
        return (try? AverageZonesDBManager.shared.fetchAverageZones())
            ?? DefaultZonesProvider.estimate(age: detailsVM.userAge ?? 30)
    }
}
