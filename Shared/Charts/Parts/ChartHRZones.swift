import SwiftUI
import Charts

/// «Подложка» — горизонтальные полосы пульсовых зон
/// «Подложка» горизонтальных полос пульсовых зон
struct ChartHRZones: ChartContent {

    let zones: [HRZoneProvider.Zone]
    let xDomain: ClosedRange<Date>

    var body: some ChartContent {
        ForEach(zones) { z in
            RectangleMark(
                xStart: .value("Start", xDomain.lowerBound),
                xEnd:   .value("End",   xDomain.upperBound),
                yStart: .value("Min",   z.minBPM),
                yEnd:   .value("Max",   z.maxBPM)
            )
            .foregroundStyle(z.color)
            .zIndex(-2)                      // под тренировками
        }
    }
}

