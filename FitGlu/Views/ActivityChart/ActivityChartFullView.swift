// ActivityChartFullView.swift
import SwiftUI
import Charts

struct ActivityChartFullView: View {
    @ObservedObject var vm: ActivityChartViewModel

    // MARK: - Интервалы тренировок
    private var workoutRanges: [ClosedRange<Date>] {
        vm.trainings.map { tr in
            let s = Date(timeIntervalSince1970: tr.startTime)
            let e = Date(timeIntervalSince1970: tr.endTime)
            return s...e
        }
    }
    private func inWorkouts(_ t: Date) -> Bool {
        for r in workoutRanges where r.contains(t) { return true }
        return false
    }

    // Точки только внутри тренировок
    private var hrActive: [HeartRateChartPoint] {
        vm.hrPoints.filter { inWorkouts($0.time) }
    }
    private var gluActive: [GlucoseChartPoint] {
        vm.glucosePoints.filter { inWorkouts($0.time) }
    }

    // MARK: - Диапазон X = от первой до последней тренировки (+10 мин паддинг)
    private var xDomain: ClosedRange<Date>? {
        guard let start = workoutRanges.map(\.lowerBound).min(),
              let end   = workoutRanges.map(\.upperBound).max()
        else { return nil }
        let pad: TimeInterval = 10 * 60
        return (start.addingTimeInterval(-pad))...(end.addingTimeInterval(pad))
    }

    // MARK: - Диапазон Y по правилам: min(zoneLow, hrMin, gluMin) ... max(zoneHigh, hrMax, gluMax)
    private var yDomain: ClosedRange<Double> {
        // зоны
        let zoneLowMin  = vm.zones.map(\.range.lowerBound).min().map(Double.init)
        let zoneHighMax = vm.zones.map(\.range.upperBound).max().map(Double.init)

        // данные (внутри тренировок)
        let hrMin = hrActive.map(\.bpm).min().map(Double.init)
        let hrMax = hrActive.map(\.bpm).max().map(Double.init)
        let gMin  = gluActive.map(\.value).min()
        let gMax  = gluActive.map(\.value).max()

        let lower = [zoneLowMin, hrMin, gMin].compactMap { $0 }.min() ?? 0
        var upper = [zoneHighMax, hrMax, gMax].compactMap { $0 }.max() ?? (lower + 1)

        if upper <= lower { upper = lower + 1 }
        let pad = 2.0
        return (lower - pad)...(upper + pad)
    }

    // Для фона зон, если тренировок нет
    private var earliestTime: Date {
        (vm.hrPoints.map(\.time) + vm.glucosePoints.map(\.time)).min() ?? Date()
    }
    private var latestTime: Date {
        (vm.hrPoints.map(\.time) + vm.glucosePoints.map(\.time)).max() ?? Date()
    }

    var body: some View {
        let xDom = xDomain

        Chart {
            // 1) Фоновые зоны (всегда рисуем все)
            ForEach(vm.zones) { zone in
                RectangleMark(
                    xStart: .value("Start", xDom?.lowerBound ?? earliestTime),
                    xEnd:   .value("End",   xDom?.upperBound ?? latestTime),
                    yStart: .value("BPM Low",  zone.range.lowerBound),
                    yEnd:   .value("BPM High", zone.range.upperBound)
                )
                .foregroundStyle(zone.color)
            }

            // 2) Пульс — отдельная серия на каждую тренировку (series = training.id)
            ForEach(vm.trainings, id: \.id) { tr in
                let s = Date(timeIntervalSince1970: tr.startTime)
                let e = Date(timeIntervalSince1970: tr.endTime)
                let color = TrainingPalette.color(for: tr.type)

                let pts = vm.hrPoints
                    .filter { $0.trainingType == tr.type && (s...e).contains($0.time) }
                    .sorted { $0.time < $1.time }

                if !pts.isEmpty {
                    ForEach(pts) { pt in
                        LineMark(
                            x: .value("Time", pt.time),
                            y: .value("BPM",  pt.bpm),
                            // главное: уникальная серия = конкретная сессия
                            series: .value("Session", "\(tr.id)") // String на случай, если id не Plottable
                        )
                        .foregroundStyle(color)                  // цвет — по типу
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
            }

            // 3) Глюкоза — пунктир, только внутри тренировок
            if !gluActive.isEmpty {
                let sortedGlucose = gluActive.sorted { $0.time < $1.time }
                ForEach(sortedGlucose) { pt in
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
        // X — только активный интервал (если он есть)
        .ifLet(xDom) { view, dom in
            view.chartXScale(domain: dom)
        }
        // Y — по min/max (зоны/пульс/глюкоза)
        .chartYScale(domain: yDomain)

        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 6)) }
        .frame(height: 300)
        .padding()
    }
}

// MARK: - Условный модификатор
private extension View {
    @ViewBuilder
    func ifLet<T>(_ value: T?, transform: (Self, T) -> some View) -> some View {
        if let v = value {
            transform(self, v)
        } else {
            self
        }
    }
}
