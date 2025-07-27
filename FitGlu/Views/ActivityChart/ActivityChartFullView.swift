import SwiftUI
import Charts

struct ActivityChartFullView: View {
    @ObservedObject var vm: ActivityChartViewModel

    var body: some View {
        // 0) сразу “выгружаем” границы
        let earliest = earliestTime
        let latest   = latestTime

        Chart {
            // 1) Фоновые зоны
            ForEach(vm.zones) { zone in
                RectangleMark(
                    xStart: .value("Start", earliest),
                    xEnd:   .value("End",   latest),
                    yStart: .value("BPM Low",  zone.range.lowerBound),
                    yEnd:   .value("BPM High", zone.range.upperBound)
                )
                .foregroundStyle(zone.color)
            }

            // 2) Пульс — по одному сегменту на каждую тренировку
            ForEach(vm.trainings, id: \.id) { training in
                let start = Date(timeIntervalSince1970: training.startTime)
                let end   = Date(timeIntervalSince1970: training.endTime)
                let color = TrainingPalette.color(for: training.type)

                // фильтруем точки именно этой тренировки
                let segmentPoints = vm.hrPoints.filter {
                    $0.trainingType == training.type &&
                    (start...end).contains($0.time)
                }

                // рисуем серию LineMark из этих точек
                if !segmentPoints.isEmpty {
                    ForEach(segmentPoints) { pt in
                        LineMark(
                            x: .value("Time", pt.time),
                            y: .value("BPM",  pt.bpm),
                            series: .value("Segment", training.type)
                        )
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
            }

            // 3) Глюкоза (пунктирная красная)
            if !vm.glucosePoints.isEmpty {
                ForEach(vm.glucosePoints) { pt in
                    LineMark(
                        x: .value("Time", pt.time),
                        y: .value("Glucose", pt.value),
                        series: .value("Metric", "Glucose")
                    )
                }
                .foregroundStyle(.pink)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6))
        }
        .frame(height: 300)
        .padding()
    }

    // MARK: — вычисляем min/max по времени
    private var earliestTime: Date {
        (vm.hrPoints.map(\.time) + vm.glucosePoints.map(\.time)).min() ?? Date()
    }
    private var latestTime: Date {
        (vm.hrPoints.map(\.time) + vm.glucosePoints.map(\.time)).max() ?? Date()
    }
}
