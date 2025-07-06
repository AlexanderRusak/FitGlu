import SwiftUI

/// Stable color for every type we know (+ fallback “other”)
enum TrainingPalette {
    static func color(for type: String) -> Color {
        switch type {
        case "Running":                         .green
        case "Walking":                         .mint
        case "Cycling":                         .yellow
        case "Functional Strength Training":    .orange
        case "Traditional Strength Training":   .indigo
        case "HIIT":                            .red
        default:                                .gray
        }
    }
}
