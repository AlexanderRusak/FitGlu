import SwiftUI

enum HRZone: Int, CaseIterable, Hashable {
    case z1 = 1, z2, z3, z4, z5

    /// Короткая подпись для чипов TIZ
    var short: String {
        switch self {
        case .z1: "Recovery"
        case .z2: "Fat"
        case .z3: "Trans"
        case .z4: "Ana"
        case .z5: "Stress"
        }
    }

    /// Полное название (EN) — можно использовать в подсказках, легендах, FAQ
    var full: String {
        switch self {
        case .z1: "Recovery"
        case .z2: "Fat Burn"
        case .z3: "Transition (Aerobic Threshold)"
        case .z4: "Anaerobic / Anabolic"
        case .z5: "High Stress (Red Zone)"
        }
    }

    /// Подпись для `ZonesBarView`: «Z3 • Transition …»
    var long: String { "Z\(rawValue) • \(short)" }

    /// Стандартный цвет зоны
    var color: Color {
        switch self {
        case .z1: .blue
        case .z2: .green
        case .z3: .yellow
        case .z4: .orange
        case .z5: .red
        }
    }
}

extension ZoneThresholds {
    subscript(_ zone: HRZone) -> [Int] {
        switch zone {
        case .z1: z1
        case .z2: z2
        case .z3: z3
        case .z4: z4
        case .z5: z5
        }
    }
}
