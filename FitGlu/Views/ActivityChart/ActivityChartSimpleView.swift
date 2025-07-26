import SwiftUI
import Charts

struct ActivityChartView: View {
    @ObservedObject var vm: ActivityChartViewModel

    var body: some View {
        VStack(spacing: 12) {
            Chart {
                // 1) Зоны
                ForEach(vm.zones) { zone in
                    RectangleMark(
                        xStart: .value("Start", earliestTime),
                        xEnd:   .value("End",   latestTime),
                        yStart: .value("Y Start", zone.range.lowerBound),
                        yEnd:   .value("Y End",   zone.range.upperBound)
                    )
                    .foregroundStyle(zone.color)
                }

                // 2) Пульс, цвет — по типу тренировки
                ForEach(vm.hrPoints) { pt in
                    LineMark(
                        x: .value("Time", pt.time),
                        y: .value("BPM", pt.bpm),
                        series: .value("Metric", "Pulse")
                    )
                    .foregroundStyle(
                        TrainingPalette.color(for: pt.trainingType ?? "")
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }

                // 3) Глюкоза
                if !vm.glucosePoints.isEmpty {
                    ForEach(vm.glucosePoints) { pt in
                        LineMark(
                            x: .value("Time", pt.time),
                            y: .value("Glucose", pt.value),
                            series: .value("Metric", "Glucose")
                        )
                        .foregroundStyle(.red)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5]))
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartForegroundStyleScale([
                "Pulse": Color.accentColor,
                "Glucose": .red
            ])
            .chartLegend(position: .bottom, spacing: 8)

            // 4) Доп. легенда по типам тренировок
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    Text("Segments:")
                        .font(.subheadline).bold()
                    ForEach(uniqueWorkoutTypes, id: \.self) { type in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(TrainingPalette.color(for: type))
                                .frame(width: 12, height: 12)
                            Text(type)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding()
    }

    // MARK: — вспомогательные
    private var uniqueWorkoutTypes: [String] {
        Array(Set(vm.hrPoints.compactMap { $0.trainingType })).sorted()
    }

    private var earliestTime: Date {
        let all = vm.hrPoints.map { $0.time } + vm.glucosePoints.map { $0.time }
        return all.min() ?? Date()
    }
    private var latestTime: Date {
        let all = vm.hrPoints.map { $0.time } + vm.glucosePoints.map { $0.time }
        return all.max() ?? Date()
    }
}
