import SwiftUI
import Charts

struct HeartRateSeries: ChartContent {

    let data:       [HRPoint]
    let showAsLine: Bool

    var body: some ChartContent {
        if showAsLine {
            ForEach(data.sorted { $0.time < $1.time }) { p in
                LineMark(
                    x: .value("Time", p.time),
                    y: .value("HR", Double(p.bpm))
                )
                .foregroundStyle(.blue)
            }
        } else {
            ForEach(data) { p in
                PointMark(
                    x: .value("Time", p.time),
                    y: .value("HR", Double(p.bpm))
                )
                .symbolSize(p.inWorkout ? 32 : 22)
                .foregroundStyle(p.inWorkout ? .blue : .gray.opacity(0.45))
            }
        }
    }
}
