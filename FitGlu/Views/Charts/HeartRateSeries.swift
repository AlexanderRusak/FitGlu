import SwiftUI
import Charts
import Foundation

extension Array where Element == HRPoint {
    /// Делит массив на подпоследовательности, где интервал между соседними
    /// точками ≤ `gap` секунд. При разрыве начинается новый сегмент.
    func splitBy(gap: TimeInterval = 5 * 60) -> [[HRPoint]] {
        guard var prev = first else { return [] }
        var bucket: [HRPoint] = [prev]
        var result: [[HRPoint]] = []

        for curr in dropFirst() {
            if curr.time.timeIntervalSince(prev.time) > gap {
                result.append(bucket)
                bucket = []
            }
            bucket.append(curr)
            prev = curr
        }
        result.append(bucket)
        return result
    }
}


struct HeartRateSeries: ChartContent {
    let segments: [[HRPoint]]
    let asLine:   Bool
    let useRightY: Bool        // пока не используем

    var body: some ChartContent {

        if asLine {
            // enumerated → получаем индекс сегмента (segmentIndex)
            ForEach(Array(segments.enumerated()), id: \.offset) { segmentIndex, segment in
                ForEach(segment, id: \.time) { p in
                    LineMark(
                        x:      .value("t",  p.time),
                        y:      .value("HR", Double(p.bpm)),
                        series: .value("segment", segmentIndex)   // ← ★ ключевая строка
                    )
                    .interpolationMethod(.linear)                // или .monotone
                    .foregroundStyle(.blue)                      // цвет един для всех
                    .lineStyle(.init(lineWidth: 1.4))
                }
            }
        } else {
            // режим точек — без изменений
            ForEach(segments.flatMap { $0 }) { p in
                PointMark(
                    x: .value("t",  p.time),
                    y: .value("HR", Double(p.bpm))
                )
                .symbolSize(p.inWorkout ? 30 : 22)
                .foregroundStyle(p.inWorkout ? .blue
                                             : .gray.opacity(0.45))
            }
        }
    }
}
