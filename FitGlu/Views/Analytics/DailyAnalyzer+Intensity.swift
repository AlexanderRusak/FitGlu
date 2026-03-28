// DailyAnalyzer+Intensity.swift
import Foundation

// MARK: - Модели метрик

public struct IntensityTrainingMetrics: Identifiable {
    public let id: Int64
    public let training: TrainingRow
    public let duration: TimeInterval      // фактическое время (по HR)
    public let avgHR: Int                  // средний HR
    public let peakHR: Int                 // пик HR (сглаженный)
    public let peakPercent: Double         // 0...100 (от HRmax)
    public let rpeIndex: Double            // 0...10 (proxy по Карвонен + надбавка за ≥90%)

    public init(id: Int64,
                training: TrainingRow,
                duration: TimeInterval,
                avgHR: Int,
                peakHR: Int,
                peakPercent: Double,
                rpeIndex: Double) {
        self.id = id
        self.training = training
        self.duration = duration
        self.avgHR = avgHR
        self.peakHR = peakHR
        self.peakPercent = peakPercent
        self.rpeIndex = rpeIndex
    }
}

public struct IntensityDayMetrics {
    public let duration: TimeInterval
    public let avgHR: Int
    public let peakHR: Int
    public let peakPercent: Double
    public let rpeIndex: Double
}

// MARK: - Расчёты

public extension DailyAnalyzer {

    /// Метрики по всем тренировкам дня
    internal func intensityForTrainings(
        trainings: [TrainingRow],
        hrSegments: [[HRPoint]],
        hrMax: Int,
        hrRest: Int
    ) -> [IntensityTrainingMetrics] {
        trainings.compactMap {
            intensityForTraining(training: $0,
                                 hrSegments: hrSegments,
                                 hrMax: hrMax,
                                 hrRest: hrRest)
        }
    }

    /// Сводка за день (взвешиваем средние по длительности, пик — максимум)
    internal  func intensityForDay(
        trainings: [TrainingRow],
        hrSegments: [[HRPoint]],
        hrMax: Int,
        hrRest: Int
    ) -> IntensityDayMetrics {

        let list = intensityForTrainings(trainings: trainings,
                                         hrSegments: hrSegments,
                                         hrMax: hrMax,
                                         hrRest: hrRest)
        let total = list.map(\.duration).reduce(0, +)

        guard total > 0,
              let maxPeak = list.max(by: { $0.peakHR < $1.peakHR }) else {
            return .init(duration: 0, avgHR: 0, peakHR: 0, peakPercent: 0, rpeIndex: 0)
        }

        // взвешенный avgHR и RPE
        let wAvgHR = Int(round(list.reduce(0.0) { $0 + Double($1.avgHR) * ($1.duration / total) }))
        let wRPE   = list.reduce(0.0) { $0 + $1.rpeIndex * ($1.duration / total) }

        return .init(duration: total,
                     avgHR: wAvgHR,
                     peakHR: maxPeak.peakHR,
                     peakPercent: maxPeak.peakPercent,
                     rpeIndex: wRPE)
    }

    // MARK: - Частные расчёты по тренировке

    /// Метрики одной тренировки.
    /// - Пик считаем по сглаживанию «скользящим максимумом» окна ~12 сек, чтобы отсеять иголки.
    /// - RPE считаем по Карвонену от среднего HR и добавляем надбавку за минуты ≥90% HRmax
    ///   (порог согласуем: `max(верх Z4, 0.9*HRmax)`).
    internal func intensityForTraining(
        training: TrainingRow,
        hrSegments: [[HRPoint]],
        hrMax: Int,
        hrRest: Int
    ) -> IntensityTrainingMetrics? {

        let interval = Date(timeIntervalSince1970: training.startTime)
        ...
        Date(timeIntervalSince1970: training.endTime)

        // Подрезаем сегменты под тренировку
        let segs: [[HRPoint]] = hrSegments
            .map { cutSegment($0, to: interval) }
            .filter { $0.count > 1 }

        var dur: TimeInterval = 0
        var sumHRdt: Double = 0

        // --- Сглаживание пика (скользящий max окна 12 c)
        let windowSec: TimeInterval = 12
        var smoothedPeak = 0

        // Порог «90%» согласуем с зонами
        let thr90 = max(self.z4.upperBound, Int(round(0.90 * Double(hrMax))))
        var secondsAt90: TimeInterval = 0

        for seg in segs {
            // средний и длительность
            for i in 0..<(seg.count - 1) {
                let p = seg[i], q = seg[i+1]
                let t0 = max(p.time, interval.lowerBound)
                let t1 = min(q.time, interval.upperBound)
                guard t1 > t0 else { continue }

                let dt = t1.timeIntervalSince(t0)
                dur += dt
                sumHRdt += Double(p.bpm) * dt
            }

            // сглаженный пик
            smoothedPeak = max(smoothedPeak, movingMaxBPM(seg, window: windowSec))

            // минуты ≥90% HR
            secondsAt90 += secondsAbove(seg, threshold: thr90, within: interval)
        }

        guard dur > 0 else { return nil }

        let avg = Int(round(sumHRdt / dur))
        let peakPct = min(100, max(0, Double(smoothedPeak) / Double(hrMax) * 100))

        // Базовый RPE (Карвонен) от среднего HR
        let baseRPE = clamp(
            (Double(avg - hrRest) / Double(max(1, hrMax - hrRest))) * 10.0,
            0, 10
        )

        // Надбавка за минуты ≥90% HR: +0.05 RPE за минуту, потолок +2.0
        let minutesAt90 = secondsAt90 / 60.0
        let addRPE = min(2.0, minutesAt90 * 0.05)

        let rpe = min(10.0, baseRPE + addRPE)

        return .init(id: training.id,
                     training: training,
                     duration: dur,
                     avgHR: avg,
                     peakHR: smoothedPeak,
                     peakPercent: peakPct,
                     rpeIndex: rpe)
    }
}

// MARK: - Вспомогательные утилиты (локальные)

private func clamp(_ x: Double, _ lo: Double, _ hi: Double) -> Double {
    return min(hi, max(lo, x))
}

/// Подрезает отрезок HRPoint под интервал тренировки
private func cutSegment(_ seg: [HRPoint], to interval: ClosedRange<Date>) -> [HRPoint] {
    guard !seg.isEmpty else { return [] }
    // быстрый выход если сегмент вне интервала
    if seg.last!.time < interval.lowerBound || seg.first!.time > interval.upperBound { return [] }
    return seg.filter { $0.time >= interval.lowerBound && $0.time <= interval.upperBound }
}

/// Скользящий максимум bpm по окну window (сек)
/// Алгоритм: обходим отрезки p->q и поддерживаем окно по времени.
private func movingMaxBPM(_ seg: [HRPoint], window: TimeInterval) -> Int {
    guard seg.count > 1 else { return seg.first?.bpm ?? 0 }
    var maxVal = 0
    var j = 0
    for i in 0..<seg.count {
        let ti = seg[i].time
        // сдвигаем левую границу окна
        while j < i && ti.timeIntervalSince(seg[j].time) > window { j += 1 }
        // максимум в окне [j...i]
        for k in j...i {
            maxVal = max(maxVal, seg[k].bpm)
        }
    }
    return maxVal
}

/// Считает количество секунд, где HR >= threshold, в заданном интервале
private func secondsAbove(_ seg: [HRPoint],
                          threshold: Int,
                          within interval: ClosedRange<Date>) -> TimeInterval {
    guard seg.count > 1 else { return 0 }
    var sum: TimeInterval = 0
    for i in 0..<(seg.count - 1) {
        let p = seg[i], q = seg[i+1]
        let t0 = max(p.time, interval.lowerBound)
        let t1 = min(q.time, interval.upperBound)
        guard t1 > t0 else { continue }

        // считаем «время над порогом» как среднее по отрезку (ступенька по p.bpm)
        if p.bpm >= threshold {
            sum += t1.timeIntervalSince(t0)
        }
    }
    return sum
}
