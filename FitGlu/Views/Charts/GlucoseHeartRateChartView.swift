import SwiftUI
import Charts

struct GlucoseHeartRateChartView: View {
    var glucoseData: [GlucoseRow]
    var heartRateData: [HeartRateLogRow]
    var hrDailyPoints : [HRPoint]
    var trainings: [TrainingRow]      // Массив тренировок (интервалы тренеровок)
    var domain: ClosedRange<Date>     // Исходный временной диапазон (например, за сутки)
    
    // Состояния для зума и смещения по оси X:
    @State private var scale: CGFloat = 1.0    // Коэффициент зума: 1.0 – исходный масштаб, > 1.0 – приближение
    @State private var offset: TimeInterval = 0 // Смещение (панорамирование) по оси X, в секундах
    
    // Состояния для интерактивной аннотации
    @State private var selectedTime: Date? = nil
    @State private var nearestGlucose: GlucoseRow? = nil
    @State private var nearestHeartRate: HeartRateLogRow? = nil
    
    // Исходная продолжительность интервала (в секундах)
    private var originalDomainInterval: TimeInterval {
        domain.upperBound.timeIntervalSince(domain.lowerBound)
    }
    
    /// Вычисленный домен для оси X с учетом зума и панорамирования
    private var currentDomain: ClosedRange<Date> {
        let center = domain.lowerBound.addingTimeInterval(originalDomainInterval / 2)
        let halfWidth = originalDomainInterval / (2 * Double(scale))
        let newCenter = center.addingTimeInterval(offset)
        let lower = newCenter.addingTimeInterval(-halfWidth)
        let upper = newCenter.addingTimeInterval(halfWidth)
        return lower ... upper
    }
    
    // Максимальные значения по оси Y для глюкозы и пульса
    private var yMaxGlucose: Double {
        (glucoseData.map { $0.glucoseValue }.max() ?? 10) * 1.2
    }
    
    private var yMaxHeartRate: Double {
        (Double(heartRateData.map { $0.heartRate }.max() ?? 120)) * 1.2
    }
    
    // Чтобы обе серии умещались на одной оси, вычисляем объединенный максимум
    private var combinedMax: Double {
        max(yMaxGlucose, yMaxHeartRate)
    }
    
    // Вычисляем уникальные типы тренировок для формирования легенды
    private var trainingLegends: [TrainingType] {
        let types = trainings.compactMap { TrainingType(rawValue: $0.type) }
        return Array(Set(types)).sorted { $0.rawValue < $1.rawValue }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Над графиком – пояснение по единицам измерения оси Y
            Text("Left Axis: Glucose (mg/dL) / Heart Rate (bpm)")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            // Основной график
            Chart {
                // Рисуем цветные полосы для каждого тренировочного интервала
                ForEach(trainings, id: \.id) { t in
                    let startDate = Date(timeIntervalSince1970: t.startTime)
                    let endDate = Date(timeIntervalSince1970: t.endTime)
                    RectangleMark(
                        xStart: .value("Training Start", startDate),
                        xEnd: .value("Training End", endDate),
                        yStart: .value("Min", 0),
                        yEnd: .value("Max", combinedMax)
                    )
                    .foregroundStyle(trainingColor(for: t).opacity(0.2))
                    .zIndex(-1)
                }
                
                // Линия данных глюкозы
                ForEach(glucoseData, id: \.id) { entry in
                    LineMark(
                        x: .value("Time", Date(timeIntervalSince1970: entry.timestamp)),
                        y: .value("Glucose", entry.glucoseValue)
                    )
                    .foregroundStyle(.red)
                    .interpolationMethod(.catmullRom)
                }
                
                // 1) HR-точки внутри тренировок – яркие
                ForEach(hrDailyPoints.filter { $0.inWorkout }) { p in
                    PointMark(
                        x: .value("Time", p.time),
                        y: .value("Heart Rate", Double(p.bpm))
                    )
                    .foregroundStyle(.blue)
                    .symbolSize(30)
                }

                // 2) HR-точки вне тренировок – тусклые/серые
                ForEach(hrDailyPoints.filter { !$0.inWorkout }) { p in
                    PointMark(
                        x: .value("Time", p.time),
                        y: .value("Heart Rate", Double(p.bpm))
                    )
                    .foregroundStyle(.gray.opacity(0.5))
                    .symbolSize(20)
                }
            }
            // Устанавливаем ось X по вычисленному домену
            .chartXScale(domain: currentDomain)
            // Устанавливаем ось Y от 0 до объединенного максимума
            .chartYScale(domain: 0...combinedMax)
            // Отображаем ось Y только слева с числовыми метками (в английском виде числа)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    if let doubleValue = value.as(Double.self) {
                        AxisValueLabel("\(Int(doubleValue))")
                    }
                }
            }
            // Обработка жестов для аннотации – при касании определяем ближайшие записи
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { gesture in
                                    let location = gesture.location
                                    if let date: Date = proxy.value(atX: location.x) {
                                        selectedTime = date
                                        // По оси X находим ближайшую запись глюкозы
                                        if let nearestG = glucoseData.min(by: { abs($0.timestamp - date.timeIntervalSince1970) < abs($1.timestamp - date.timeIntervalSince1970) }) {
                                            nearestGlucose = nearestG
                                        }
                                        // По оси X находим ближайшую запись пульса
                                        if let nearestHR = heartRateData.min(by: { abs($0.timestamp - date.timeIntervalSince1970) < abs($1.timestamp - date.timeIntervalSince1970) }) {
                                            nearestHeartRate = nearestHR
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    // Если нужно, можно убрать аннотацию по окончании жеста:
                                    // selectedTime = nil
                                    // nearestGlucose = nil
                                    // nearestHeartRate = nil
                                }
                        )
                }
            }
            // Overlay с аннотацией; все надписи на английском
            .overlay {
                if let selTime = selectedTime, nearestGlucose != nil || nearestHeartRate != nil {
                    VStack(alignment: .leading, spacing: 4) {
                        if let hr = nearestHeartRate {
                            Text("Pulse: \(hr.heartRate) bpm")
                        }
                        if let gl = nearestGlucose {
                            Text("Glucose: \(gl.glucoseValue, specifier: "%.1f") mg/dL")
                        }
                        Text("Time: \(formattedTime(selTime))")
                    }
                    .font(.caption)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white).shadow(radius: 4))
                    // Фиксированное позиционирование; можно доработать, чтобы позиционировать рядом с касанием
                    .position(x: 80, y: 40)
                }
            }
            .frame(maxWidth: .infinity)
            .border(Color.gray.opacity(0.3))
            
            // Слайдер для зума
            VStack {
                Text("Zoom: \(String(format: "%.1f", scale))x")
                    .font(.subheadline)
                Slider(value: $scale, in: 1...10, step: 0.1)
                    .padding(.horizontal)
            }
            
            // Слайдер для панорамирования
            VStack {
                Text("Pan: \(Int(offset)) sec")
                    .font(.subheadline)
                Slider(value: $offset, in: -originalDomainInterval/2 ... originalDomainInterval/2, step: 1)
                    .padding(.horizontal)
            }
            
            // Легенда: две части – для данных и для тренинговых интервалов
            legendView
        }
        .padding(.horizontal)
    }
    
    /// Форматирование времени в формате "HH:mm:ss" (на английском)
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    /// Легенда под графиком: блок для Glucose / Heart Rate и блок для Training types
    private var legendView: some View {
        VStack {
            HStack(spacing: 16) {
                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                    Text("Glucose (mg/dL)")
                        .font(.footnote)
                }
                HStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)
                    Text("Heart Rate (bpm)")
                        .font(.footnote)
                }
            }
            .padding(.bottom, 4)
            HStack(spacing: 16) {
                ForEach(trainingLegends, id: \.id) { type in
                    HStack {
                        Rectangle()
                            .fill(trainingTypeColor(type))
                            .frame(width: 12, height: 12)
                        Text(type.rawValue)
                            .font(.footnote)
                    }
                }
            }
        }
        .padding(.top, 8)
    }
    
    /// Функция, возвращающая цвет для конкретного тренинга на основе его типа
    private func trainingColor(for training: TrainingRow) -> Color {
        if let type = TrainingType(rawValue: training.type) {
            return trainingTypeColor(type)
        }
        return .orange
    }
    
    /// Функция для получения цвета по типу тренировки
    private func trainingTypeColor(_ type: TrainingType) -> Color {
        switch type {
        case .fatBurning:
            return .green
        case .cardio:
            return .red
        case .strength:
            return .blue
        }
    }
}
