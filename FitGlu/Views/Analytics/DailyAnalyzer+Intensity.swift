import Foundation

public struct IntensityTrainingMetrics: Identifiable {
    public let id: Int64
    public let training: TrainingRow
    public let duration: TimeInterval  // фактическое время по HR
    public let avgHR: Int
    public let peakHR: Int
    public let peakPercent: Double     // 0...100 (от HRmax)
    public let rpeIndex: Double        // 0...10

    public init(id: Int64, training: TrainingRow, duration: TimeInterval, avgHR: Int, peakHR: Int, peakPercent: Double, rpeIndex: Double) {
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

public extension DailyAnalyzer {

    /// Метрики по всем тренировкам дня
    private func intensityForTrainings(trainings: [TrainingRow],
                               hrSegments: [[HRPoint]],
                               hrMax: Int,
                               hrRest: Int) -> [IntensityTrainingMetrics] {

        trainings.compactMap { intensityForTraining(training: $0, hrSegments: hrSegments, hrMax: hrMax, hrRest: hrRest) }
    }

    /// Сводка за день (весим средние по длительности, пик — максимум)
    private func intensityForDay(trainings: [TrainingRow],
                         hrSegments: [[HRPoint]],
                         hrMax: Int,
                         hrRest: Int) -> IntensityDayMetrics {

        let list = intensityForTrainings(trainings: trainings, hrSegments: hrSegments, hrMax: hrMax, hrRest: hrRest)
        let total = list.map(\.duration).reduce(0, +)

        guard total > 0, let maxPeak = list.max(by: { $0.peakHR < $1.peakHR }) else {
            return .init(duration: 0, avgHR: 0, peakHR: 0, peakPercent: 0, rpeIndex: 0)
        }

        // взвешенный avgHR и rpe
        let wAvgHR = Int(round(list.reduce(0.0) { $0 + Double($1.avgHR) * ($1.duration / total) }))
        let wRPE   = list.reduce(0.0) { $0 + $1.rpeIndex * ($1.duration / total) }

        return .init(duration: total,
                     avgHR: wAvgHR,
                     peakHR: maxPeak.peakHR,
                     peakPercent: maxPeak.peakPercent,
                     rpeIndex: wRPE)
    }

    // MARK: private

    /// Метрики для одной тренировки (временная усреднёнка по «ступеням»)
    private func intensityForTraining(training: TrainingRow,
                                      hrSegments: [[HRPoint]],
                                      hrMax: Int,
                                      hrRest: Int) -> IntensityTrainingMetrics? {

        let interval = Date(timeIntervalSince1970: training.startTime) ... Date(timeIntervalSince1970: training.endTime)

        // подрезаем сегменты под тренировку, как в TIZ
        let segs: [[HRPoint]] = hrSegments
            .map { (seg: [HRPoint]) in cutSegment(seg, to: interval) }
            .filter { $0.count > 1 }

        var dur: TimeInterval = 0
        var sumHRdt: Double = 0
        var peak = 0

        for seg in segs {
            for i in 0..<(seg.count - 1) {
                let p = seg[i], q = seg[i+1]
                let t0 = max(p.time, interval.lowerBound)
                let t1 = min(q.time, interval.upperBound)
                guard t1 > t0 else { continue }

                let dt = t1.timeIntervalSince(t0)
                dur += dt
                sumHRdt += Double(p.bpm) * dt
                peak = max(peak, p.bpm, q.bpm)
            }
        }
        guard dur > 0 else { return nil }

        let avg = Int(round(sumHRdt / dur))
        let peakPct = min(100, max(0, Double(peak) / Double(hrMax) * 100))
        let rpe = min(10, max(0, Double(avg - hrRest) / Double(max(1, hrMax - hrRest)) * 10.0))

        return .init(id: training.id,
                     training: training,
                     duration: dur,
                     avgHR: avg,
                     peakHR: peak,
                     peakPercent: peakPct,
                     rpeIndex: rpe)
    }
}
