import Foundation

struct StrengthStats {
    let durationMin: Int
    let avgHR: Int
    let maxHR: Int

    let waveCount: Int

    let restMedianSec: Int
    let restP90Sec: Int

    let recoveryDropMedianBpm: Int
    let driftBpm: Int

    let efficiencyScore: Int
    let weakSpot: String

    let restRecommendedSec: Int
    let restDisciplineScore: Int

    let hasEnoughData: Bool
}

enum StrengthHRAnalyzer {

    static func analyze(points: [HRPoint]) -> StrengthStats? {
        let pts = points.sorted { $0.time < $1.time }
        guard pts.count >= 120 else {
            return StrengthStats(
                durationMin: Int(max(1, (pts.last?.time.timeIntervalSince(pts.first?.time ?? Date()) ?? 0) / 60)),
                avgHR: pts.map(\.bpm).averageInt(),
                maxHR: pts.map(\.bpm).max() ?? 0,
                waveCount: 0,
                restMedianSec: 0,
                restP90Sec: 0,
                recoveryDropMedianBpm: 0,
                driftBpm: 0,
                efficiencyScore: 0,
                weakSpot: "Not enough HR data",
                restRecommendedSec: 90,
                restDisciplineScore: 0,
                hasEnoughData: false
            )
        }

        let durationSec = pts.last!.time.timeIntervalSince(pts.first!.time)
        let durationMin = max(1, Int((durationSec / 60).rounded()))

        let hr = pts.map(\.bpm)
        let avgHR = hr.averageInt()
        let maxHR = hr.max() ?? 0

        let baseline = percentile(hr, p: 0.10) // p10
        let workThr = baseline + 18            // можно тюнить
        let restThr = baseline + 10

        // сегментация work/rest
        let flags: [Bool] = pts.map { $0.bpm >= workThr } // work=true
        let workIntervals = contiguousIntervals(flags: flags, times: pts.map(\.time), value: true, minSec: 40)
        let restIntervals = contiguousIntervals(flags: pts.map { $0.bpm <= restThr },
                                               times: pts.map(\.time),
                                               value: true,
                                               minSec: 20)

        let waveCount = workIntervals.count

        // rest durations: между work-волнами (окна отдыха)
        var rests: [Int] = []
        var drops: [Int] = []

        for i in 0..<workIntervals.count {
            let w = workIntervals[i]
            // отдых = от конца work до начала следующей work (если есть)
            if i + 1 < workIntervals.count {
                let next = workIntervals[i + 1]
                let restSec = Int(next.start.timeIntervalSince(w.end).rounded())
                if restSec > 0 { rests.append(restSec) }
            }

            // recovery drop: maxHR в волне минус minHR сразу после волны (в ближайшие 60–120с)
            let wavePts = pts.filter { $0.time >= w.start && $0.time <= w.end }
            let waveMax = wavePts.map(\.bpm).max() ?? 0

            let afterStart = w.end
            let afterEnd = w.end.addingTimeInterval(120) // 2 мин
            let afterPts = pts.filter { $0.time >= afterStart && $0.time <= afterEnd }
            if !afterPts.isEmpty {
                let afterMin = afterPts.map(\.bpm).min() ?? waveMax
                drops.append(max(0, waveMax - afterMin))
            }
        }

        let restMedianSec = rests.medianInt()
        let restP90Sec = percentile(rests, p: 0.90)

        let recoveryDropMedian = drops.medianInt()

        // drift: средний HR первой трети vs последней трети
        let third = max(1, hr.count / 3)
        let firstAvg = Array(hr.prefix(third)).averageInt()
        let lastAvg  = Array(hr.suffix(third)).averageInt()
        let driftBpm = max(0, lastAvg - firstAvg)

        // rest discipline: чем ближе p90 к median — тем лучше
        let disciplineScore: Int = {
            guard restMedianSec > 0 else { return 0 }
            let ratio = Double(restP90Sec) / Double(restMedianSec) // 1.0 идеал
            let penalty = min(1.0, max(0.0, (ratio - 1.0) / 1.0))   // ratio=2 => penalty=1
            return Int(((1.0 - penalty) * 100).rounded())
        }()

        // recommended rest: базово median, но если recovery drop маленький — увеличиваем
        let recommendedRest: Int = {
            var r = max(60, restMedianSec)
            if recoveryDropMedian < 12 { r += 45 }         // плохо восстанавливаешься
            if driftBpm >= 8 { r += 30 }                   // усталость копится
            return min(240, r)
        }()

        // efficiency score (0–100)
        // хотим: waves>0, recoveryDrop норм, drift не большой, отдых стабилен
        let efficiencyScore: Int = {
            let wavesScore = min(1.0, Double(waveCount) / 10.0) * 20.0
            let dropScore  = min(1.0, Double(recoveryDropMedian) / 25.0) * 30.0
            let driftScore = (1.0 - min(1.0, Double(driftBpm) / 12.0)) * 20.0
            let restScore  = Double(disciplineScore) * 0.30
            let total = wavesScore + dropScore + driftScore + restScore
            return Int(max(0, min(100, total.rounded())))
        }()

        let weakSpot: String = {
            if waveCount == 0 { return "No clear work waves" }
            if recoveryDropMedian < 12 { return "Low recovery (rest ↑)" }
            if driftBpm >= 8 { return "High drift (fatigue)" }
            if disciplineScore < 55 { return "Rest inconsistent" }
            if restMedianSec > 180 { return "Rest too long" }
            return "Good balance"
        }()

        return StrengthStats(
            durationMin: durationMin,
            avgHR: avgHR,
            maxHR: maxHR,
            waveCount: waveCount,
            restMedianSec: restMedianSec,
            restP90Sec: restP90Sec,
            recoveryDropMedianBpm: recoveryDropMedian,
            driftBpm: driftBpm,
            efficiencyScore: efficiencyScore,
            weakSpot: weakSpot,
            restRecommendedSec: recommendedRest,
            restDisciplineScore: disciplineScore,
            hasEnoughData: true
        )
    }

    // MARK: - helpers

    private struct Interval { let start: Date; let end: Date }

    private static func contiguousIntervals(flags: [Bool], times: [Date], value: Bool, minSec: TimeInterval) -> [Interval] {
        guard flags.count == times.count, !flags.isEmpty else { return [] }

        var res: [Interval] = []
        var i = 0
        while i < flags.count {
            if flags[i] != value { i += 1; continue }
            let start = times[i]
            var j = i
            while j < flags.count && flags[j] == value { j += 1 }
            let end = times[max(i, j - 1)]
            if end.timeIntervalSince(start) >= minSec {
                res.append(.init(start: start, end: end))
            }
            i = j
        }
        return res
    }

    private static func percentile(_ values: [Int], p: Double) -> Int {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let idx = Int((Double(sorted.count - 1) * p).rounded())
        return sorted[max(0, min(sorted.count - 1, idx))]
    }
}

// MARK: - array helpers
private extension Array where Element == Int {
    func averageInt() -> Int {
        guard !isEmpty else { return 0 }
        let s = reduce(0, +)
        return Int((Double(s) / Double(count)).rounded())
    }
    func medianInt() -> Int {
        guard !isEmpty else { return 0 }
        let s = sorted()
        if s.count % 2 == 1 { return s[s.count/2] }
        return Int(((Double(s[s.count/2 - 1] + s[s.count/2])) / 2.0).rounded())
    }
}

