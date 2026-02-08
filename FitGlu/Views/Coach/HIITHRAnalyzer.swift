import Foundation

struct HIITStats {
    let analysisVersion: String
    let hasEnoughData: Bool

    let durationMin: Int
    let avgHR: Int
    let maxHR: Int

    // Простая сегментация “высоко/низко”
    let highThresholdBpm: Int
    let lowThresholdBpm: Int

    let timeInHighZoneSec: Int
    let timeInHighZonePct: Int

    // “Интервалы” по переходам low<->high
    let intervalCount: Int
    let workMedianSec: Int?
    let restMedianSec: Int?

    // Восстановление после пиков: грубо, по тренду в конце
    let recoverySlopeBpmPerMin: Int?
    let qualityScore: Int
    let weakSpot: String?
}

enum HIITHRAnalyzer {
    static let analysisVersion = "v1.0"

    /// points — HR точки уже ОТСОРТИРОВАНЫ по времени и уже отфильтрованы в окно HIIT тренировки
    static func analyze(points: [HRPoint]) -> HIITStats? {
        // Минимум данных, иначе шум
        guard points.count >= 60 else {
            return HIITStats(
                analysisVersion: analysisVersion,
                hasEnoughData: false,
                durationMin: Int(max(0, (points.last?.time.timeIntervalSince(points.first?.time ?? Date()) ?? 0) / 60.0)),
                avgHR: 0,
                maxHR: 0,
                highThresholdBpm: 0,
                lowThresholdBpm: 0,
                timeInHighZoneSec: 0,
                timeInHighZonePct: 0,
                intervalCount: 0,
                workMedianSec: nil,
                restMedianSec: nil,
                recoverySlopeBpmPerMin: nil,
                qualityScore: 0,
                weakSpot: "Not enough HR points"
            )
        }

        let sorted = points.sorted { $0.time < $1.time }
        guard let first = sorted.first, let last = sorted.last else { return nil }

        let durationSec = max(0, Int(last.time.timeIntervalSince(first.time)))
        let durationMin = Int(Double(durationSec) / 60.0)

        let bpmList = sorted.map(\.bpm)
        let maxHR = bpmList.max() ?? 0
        let avgHR = Int((Double(bpmList.reduce(0, +)) / Double(max(1, bpmList.count))).rounded())

        // Простая адаптивная пороговая логика:
        // high = avg + 12, low = avg - 8 (чтобы не ломалось на разных людях)
        let highTh = max(90, avgHR + 12)
        let lowTh  = max(70, avgHR - 8)

        // Считаем время в high зоне по delta-time между соседними точками
        var highSec = 0
        for i in 1..<sorted.count {
            let dt = Int(sorted[i].time.timeIntervalSince(sorted[i-1].time))
            if sorted[i-1].bpm >= highTh { highSec += max(0, dt) }
        }
        let highPct = durationSec > 0 ? Int((Double(highSec) / Double(durationSec) * 100.0).rounded()) : 0

        // Интервалы: считаем “work” как куски где bpm>=highTh,
        // “rest” как куски где bpm<=lowTh.
        // Это не идеальный HIIT-детектор, но стабильный MVP.
        func median(_ arr: [Int]) -> Int? {
            guard !arr.isEmpty else { return nil }
            let s = arr.sorted()
            let mid = s.count / 2
            if s.count % 2 == 1 { return s[mid] }
            return Int(((Double(s[mid - 1]) + Double(s[mid])) / 2.0).rounded())
        }

        var workChunks: [Int] = []
        var restChunks: [Int] = []

        enum State { case high, low, mid }
        func state(for bpm: Int) -> State {
            if bpm >= highTh { return .high }
            if bpm <= lowTh { return .low }
            return .mid
        }

        var curState = state(for: sorted[0].bpm)
        var chunkStart = sorted[0].time

        func closeChunk(end: Date) {
            let sec = max(0, Int(end.timeIntervalSince(chunkStart)))
            if sec <= 2 { return } // игнор микро-кусочки
            switch curState {
            case .high: workChunks.append(sec)
            case .low:  restChunks.append(sec)
            case .mid:  break
            }
        }

        for i in 1..<sorted.count {
            let st = state(for: sorted[i].bpm)
            if st != curState {
                closeChunk(end: sorted[i].time)
                curState = st
                chunkStart = sorted[i].time
            }
        }
        closeChunk(end: last.time)

        let workMed = median(workChunks)
        let restMed = median(restChunks)

        // intervalCount — сколько раз мы реально заходили в high
        let intervalCount = workChunks.count

        // Recovery slope: сравним средний HR в первых 20% и последних 20% тренировки.
        // Если в конце заметно ниже → восстановление/заминка ок.
        let n = sorted.count
        let w = max(10, Int(Double(n) * 0.2))
        let headAvg = Int((Double(sorted.prefix(w).map(\.bpm).reduce(0,+)) / Double(w)).rounded())
        let tailAvg = Int((Double(sorted.suffix(w).map(\.bpm).reduce(0,+)) / Double(w)).rounded())
        // Считаем "склон" как bpm/мин (грубо)
        let slope: Int? = durationMin > 0 ? Int(((Double(tailAvg - headAvg) / Double(max(1, durationMin))).rounded())) : nil

        // Quality score (очень простой):
        // + если есть интервалы, + если max достаточно выше avg, + если highPct не нулевой
        var score = 0
        if intervalCount >= 6 { score += 40 } else if intervalCount >= 3 { score += 25 } else { score += 10 }
        if maxHR >= avgHR + 20 { score += 30 } else if maxHR >= avgHR + 12 { score += 20 } else { score += 10 }
        if highPct >= 25 { score += 30 } else if highPct >= 12 { score += 20 } else { score += 10 }
        score = min(100, max(0, score))

        var weak: String? = nil
        if intervalCount < 3 {
            weak = "Few intervals (low intensity structure)"
        } else if highPct < 10 {
            weak = "Too little time in high zone"
        } else if maxHR < avgHR + 10 {
            weak = "Peaks are weak"
        }

        return HIITStats(
            analysisVersion: analysisVersion,
            hasEnoughData: true,
            durationMin: durationMin,
            avgHR: avgHR,
            maxHR: maxHR,
            highThresholdBpm: highTh,
            lowThresholdBpm: lowTh,
            timeInHighZoneSec: highSec,
            timeInHighZonePct: highPct,
            intervalCount: intervalCount,
            workMedianSec: workMed,
            restMedianSec: restMed,
            recoverySlopeBpmPerMin: slope,
            qualityScore: score,
            weakSpot: weak
        )
    }
}
