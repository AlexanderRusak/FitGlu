import Foundation
import SwiftUI

// Точка пульса
struct HeartRateChartPoint: Identifiable {
  let id = UUID()
  let time: Date
  let bpm: Int
  let trainingType: String?  // nil — вне тренировки
}

// Точка глюкозы
struct GlucoseChartPoint: Identifiable {
  let id = UUID()
  let time: Date
  let value: Double
}
