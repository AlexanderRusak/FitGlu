import Foundation

extension DailyAnalyzer {

    func analyzeDay(trainings: [TrainingRow],
                    hrSegments: [[HRPoint]]) -> [TrainingQuality] {

        trainings.map { tr in
            let interval = Date(timeIntervalSince1970: tr.startTime)...Date(timeIntervalSince1970: tr.endTime)
            let segs = hrSegments.map { cutSegment($0, to: interval) }.filter { $0.count > 1 }
            let tiz = accumulateTIZ(from: segs, within: interval)
            let score = zoneBalance(tiz: tiz)
            return TrainingQuality(id: tr.id, training: tr, tiz: tiz, zoneBalanceScore: score)
        }
    }

    /// Hold-to-next интегрирование по зонам
    func accumulateTIZ(from segments: [[HRPoint]],
                       within interval: ClosedRange<Date>) -> TimeInZone {
        var tiz = TimeInZone()
        for seg in segments where seg.count >= 2 {
            for i in 0..<(seg.count - 1) {
                let p = seg[i], q = seg[i + 1]
                let t0 = max(p.time, interval.lowerBound)
                let t1 = min(q.time, interval.upperBound)
                guard t1 > t0 else { continue }
                let dt = t1.timeIntervalSince(t0)
                let bpmForSlice = (p.time < interval.lowerBound) ? q.bpm : p.bpm
                switch zone(for: bpmForSlice) {
                case .rec: tiz.rec += dt
                case .fat: tiz.fat += dt
                case .tran: tiz.tran += dt
                case .ana: tiz.ana += dt
                case .stress: tiz.stress += dt
                }
            }
        }
        return tiz
    }

    /// TRIMP по Эдвардсу (на будущее)
    func trimpEdwards(from tiz: TimeInZone) -> Double {
        let m = tiz.minutes
        return 1.0*m.rec + 2.0*m.fat + 3.0*m.tran + 4.0*m.ana + 5.0*m.stress
    }
}
