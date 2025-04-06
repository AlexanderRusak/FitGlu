import SwiftUI
import Charts

struct GlucoseHeartRateChartView: View {
    var glucoseData: [GlucoseRow]
    var heartRateData: [HeartRateLogRow]
    var training: TrainingRow

    // Фиксируем общий временной диапазон (например, весь день или от тренировки)
    private var domain: ClosedRange<Date> {
        let start = Date(timeIntervalSince1970: training.startTime)
        let end = Date(timeIntervalSince1970: training.endTime)
        // Если нужно расширить диапазон, можно добавить запас времени:
        return start.addingTimeInterval(-300)...end.addingTimeInterval(300)
    }

    // Вычисляем максимальные значения для каждой оси
    private var yMaxGlucose: Double {
        (glucoseData.map { $0.glucoseValue }.max() ?? 10) * 1.2
    }

    private var yMaxHeartRate: Double {
        (Double(heartRateData.map { $0.heartRate }.max() ?? 120)) * 1.2
    }

    var body: some View {
        VStack(spacing: 16) {
            // Верхний график для глюкозы
            VStack(alignment: .leading) {
                Text("🔴 Glucose")
                    .font(.headline)
                Chart {
                    // Фон зоны тренировки
                    RectangleMark(
                        xStart: .value("Start", Date(timeIntervalSince1970: training.startTime)),
                        xEnd: .value("End", Date(timeIntervalSince1970: training.endTime)),
                        yStart: .value("Min", 0),
                        yEnd: .value("Max", yMaxGlucose)
                    )
                    .foregroundStyle(Color.orange.opacity(0.15))
                    .zIndex(-1)
                    
                    // График глюкозы (линия)
                    ForEach(glucoseData, id: \.id) { entry in
                        LineMark(
                            x: .value("Time", Date(timeIntervalSince1970: entry.timestamp)),
                            y: .value("Glucose", entry.glucoseValue)
                        )
                        .foregroundStyle(.red)
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartXScale(domain: domain)
                .frame(height: 150)
            }
            
            // Нижний график для пульса
            VStack(alignment: .leading) {
                Text("💙 Heart Rate")
                    .font(.headline)
                Chart {
                    // Фон зоны тренировки
                    RectangleMark(
                        xStart: .value("Start", Date(timeIntervalSince1970: training.startTime)),
                        xEnd: .value("End", Date(timeIntervalSince1970: training.endTime)),
                        yStart: .value("Min", 0),
                        yEnd: .value("Max", yMaxHeartRate)
                    )
                    .foregroundStyle(Color.orange.opacity(0.15))
                    .zIndex(-1)
                    
                    // График пульса (точки)
                    ForEach(heartRateData, id: \.id) { hr in
                        PointMark(
                            x: .value("Time", Date(timeIntervalSince1970: hr.timestamp)),
                            y: .value("Heart Rate", hr.heartRate)
                        )
                        .foregroundStyle(.blue)
                        .symbolSize(40)
                    }
                }
                .chartXScale(domain: domain)
                .frame(height: 150)
            }
        }
        .padding()
    }
}
