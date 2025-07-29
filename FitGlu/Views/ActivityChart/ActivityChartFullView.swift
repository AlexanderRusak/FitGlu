// ActivityChartFullView.swift
import SwiftUI
import Charts

struct ActivityChartFullView: View {
    @ObservedObject var vm: ActivityChartViewModel

    // MARK: - Подготовка интервалов тренировок
    private var workoutRanges: [ClosedRange<Date>] {
        vm.trainings.map { tr in
            let s = Date(timeIntervalSince1970: tr.startTime)
            let e = Date(timeIntervalSince1970: tr.endTime)
            return s...e
        }
    }
    private func inWorkouts(_ t: Date) -> Bool {
        for r in workoutRanges {
            if r.contains(t) { return true }
        }
        return false
    }

    // MARK: - Активные точки только внутри тренировок
    private var hrActive: [HeartRateChartPoint] {
        vm.hrPoints.filter { inWorkouts($0.time) }
    }
    private var gluActive: [GlucoseChartPoint] {
        vm.glucosePoints.filter { inWorkouts($0.time) }
    }

    // MARK: - Диапазон X: от первой до последней тренировки (с запасом)
    private var xDomain: ClosedRange<Date>? {
        guard let start = workoutRanges.map(\.lowerBound).min(),
              let end   = workoutRanges.map(\.upperBound).max()
        else { return nil }

        let pad: TimeInterval = 10 * 60 // 10 минут
        return (start.addingTimeInterval(-pad))...(end.addingTimeInterval(pad))
    }

    // MARK: - Диапазон Y без «чёрного дна»
    private var yDomain: ClosedRange<Double> {
        // нижняя/верхняя по зонам
        let zoneLow  = vm.zones.map(\.range.lowerBound).min().map(Double.init)
        let zoneHigh = vm.zones.map(\.range.upperBound).max().map(Double.init)

        // минимально/максимальные значения по данным ВНУТРИ тренировок
        let hrMin = hrActive.map(\.bpm).min().map(Double.init)
        let hrMax = hrActive.map(\.bpm).max().map(Double.init)
        let gMin  = gluActive.map(\.value).min()
        let gMax  = gluActive.map(\.value).max()

        // Нижняя граница:
        // 1) минимум данных внутри тренировок (если есть)
        let dataMin = [hrMin, gMin].compactMap { $0 }.min()
        // 2) не опускаться ниже нижней границы зон
        var lower = dataMin ?? zoneLow ?? 0
        if let zLow = zoneLow { lower = max(lower, zLow) }

        // Верхняя граница — максимум из данных и зон
        let upperCandidates = [zoneHigh, hrMax, gMax].compactMap { $0 }
        var upper = upperCandidates.max() ?? (lower + 1)

        // маленькая «подушка», чтобы линии не липли к краю
        let pad = 2.0
        if upper <= lower { upper = lower + 1 }
        return (lower - pad)...(upper + pad)
    }

    // MARK: - Вспомогательные (чтобы зоны растягивать по ширине графика)
    private var earliestTime: Date {
        (vm.hrPoints.map(\.time) + vm.glucosePoints.map(\.time)).min() ?? Date()
    }
    private var latestTime: Date {
        (vm.hrPoints.map(\.time) + vm.glucosePoints.map(\.time)).max() ?? Date()
    }

    var body: some View {
        // заранее зафиксируем X‑границы, чтобы избежать «тяжёлых» вычислений внутри Chart
        let xDom = xDomain

        Chart {
            // 1) Фоновые зоны (оставляем все)
            ForEach(vm.zones) { zone in
                RectangleMark(
                    xStart: .value("Start", xDom?.lowerBound ?? earliestTime),
                    xEnd:   .value("End",   xDom?.upperBound ?? latestTime),
                    yStart: .value("BPM Low",  zone.range.lowerBound),
                    yEnd:   .value("BPM High", zone.range.upperBound)
                )
                .foregroundStyle(zone.color)
            }

            // 2) Пульс — сегменты по тренировкам
            ForEach(vm.trainings, id: \.id) { tr in
                let s = Date(timeIntervalSince1970: tr.startTime)
                let e = Date(timeIntervalSince1970: tr.endTime)
                let color = TrainingPalette.color(for: tr.type)

                let pts = vm.hrPoints.filter { $0.trainingType == tr.type && (s...e).contains($0.time) }
                if !pts.isEmpty {
                    ForEach(pts) { pt in
                        LineMark(
                            x: .value("Time", pt.time),
                            y: .value("BPM",  pt.bpm),
                            series: .value("Segment", tr.type)
                        )
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
            }

            // 3) Глюкоза — пунктир (оставляем как есть; если хочешь — тоже ограничили внутри тренировок выше)
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
        // Сжимаем X — только активный интервал тренировок (если он есть)
        .ifLet(xDom) { view, dom in
            view.chartXScale(domain: dom)
        }
        // И сжимаем Y под данные + зоны
        .chartYScale(domain: yDomain)

        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6))
        }
        .frame(height: 300)
        .padding()
    }
}

// MARK: - Небольшая удобная обёртка для условного модификатора
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
