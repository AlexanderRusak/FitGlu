import SwiftUI
import Charts

struct TrainingBackground: ChartContent {

    let trainings: [TrainingRow]
    let yMax:     Double

    var body: some ChartContent {
        ForEach(trainings, id: \.id) { t in
            RectangleMark(
                xStart: .value("Start", Date(timeIntervalSince1970: t.startTime)),
                xEnd:   .value("End",   Date(timeIntervalSince1970: t.endTime)),
                yStart: .value("Min", 0),
                yEnd:   .value("Max", yMax)
            )
            .foregroundStyle(
                TrainingPalette.color(for: t.type).opacity(0.20)
            )
            .zIndex(-1)
        }
    }
}
