import Foundation
import SwiftUI

// Серия точек для отрисовки на Chart
struct HeartRateChartPoint: Identifiable {
    let id = UUID()
    let time: Date
    let bpm: Int
    let trainingType: String?   // nil — вне тренировки
}

struct GlucoseChartPoint: Identifiable {
    let id = UUID()
    let time: Date
    let value: Double
}
