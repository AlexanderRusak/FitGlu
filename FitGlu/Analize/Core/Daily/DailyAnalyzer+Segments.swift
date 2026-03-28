import Foundation

extension DailyAnalyzer {
    /// Обрезаем HR-сегмент по интервалу тренировки и добавляем соседние точки
    func cutSegment(_ seg: [HRPoint], to interval: ClosedRange<Date>) -> [HRPoint] {
        guard !seg.isEmpty else { return [] }
        let s = seg.sorted { $0.time < $1.time }
        var out: [HRPoint] = []
        if let before = s.last(where: { $0.time < interval.lowerBound }) { out.append(before) }
        out.append(contentsOf: s.filter { interval.contains($0.time) })
        if let after  = s.first(where: { $0.time > interval.upperBound }) { out.append(after) }
        return out
    }

    /// Все точки внутри тренировки (подрезанные и отсортированные)
    func pointsForTraining(_ tr: TrainingRow, hrSegments: [[HRPoint]]) -> [HRPoint] {
        let interval = Date(timeIntervalSince1970: tr.startTime)...Date(timeIntervalSince1970: tr.endTime)
        return hrSegments
            .map { cutSegment($0, to: interval) }
            .filter { $0.count > 1 }
            .flatMap { $0 }
            .sorted { $0.time < $1.time }
    }
}
