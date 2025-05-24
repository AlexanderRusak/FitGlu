// Utils/HRZoneProvider.swift
import HealthKit
import SwiftUICore

enum HRZoneProvider {

    struct Zone: Identifiable {
        let id      : Int
        let name    : String
        let minBPM  : Int
        let maxBPM  : Int
        let color   : Color
    }

    /// Возвращает массив зон с учётом пола / возраста
    static func ranges(for age: Int, sex: HKBiologicalSex?) -> [Zone] {

        // 1. HRmax
        let hrMax: Double
        switch sex {
        case .some(.female): hrMax = 206 - 0.88 * Double(age)
        case .some(.male):   hrMax = 208 - 0.70 * Double(age)
        default:             hrMax = 220 - Double(age)
        }

        // 2. Шаблон диапазонов
        let percents: [(String, Double, Double, Color)] = [
            ("Z1", 0.50, 0.60, .green.opacity(0.18)),
            ("Z2", 0.60, 0.70, .mint .opacity(0.18)),
            ("Z3", 0.70, 0.80, .yellow.opacity(0.18)),
            ("Z4", 0.80, 0.90, .orange.opacity(0.18)),
            ("Z5", 0.90, 1.00, .red.opacity(0.18))
        ]

        return percents.enumerated().map { idx, tpl in
            let min = Int(hrMax * tpl.1)
            let max = Int(hrMax * tpl.2)
            return Zone(id: idx, name: tpl.0, minBPM: min, maxBPM: max, color: tpl.3)
        }
    }
}
