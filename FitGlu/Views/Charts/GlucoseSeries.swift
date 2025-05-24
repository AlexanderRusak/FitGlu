import SwiftUI
import Charts

struct GlucoseSeries: ChartContent {
    let data: [GlucoseRow]

    var body: some ChartContent {
        ForEach(data, id: \.id) { g in
            LineMark(
                x: .value("Time", Date(timeIntervalSince1970: g.timestamp)),
                y: .value("Glucose", g.glucoseValue)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(.red)
        }
    }
}
