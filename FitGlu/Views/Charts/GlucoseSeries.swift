import SwiftUI
import Charts

struct GlucoseSeries: ChartContent {
    let data: [GlucoseRow]

    var body: some ChartContent {
        ForEach(
            data.sorted { $0.timestamp < $1.timestamp },
            id: \.id                     // ← уникальный идентификатор
        ) { g in
            LineMark(
                x: .value("t", Date(timeIntervalSince1970: g.timestamp)),
                y: .value("G", g.glucoseValue)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(.red)
            .lineStyle(.init(lineWidth: 1.3))        // ← левая шкала
        }
    }
}

