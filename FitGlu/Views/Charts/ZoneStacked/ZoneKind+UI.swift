// Views/Charts/ZonesStacked/ZoneKind+UI.swift
import SwiftUI

extension ZoneKind {
    var shortTitle: String {
        switch self {
        case .rec: return "rec"
        case .fat: return "fat"
        case .tran: return "tran"
        case .ana: return "ana"
        case .stress: return "stress"
        }
    }

    var color: Color {
        switch self {
        case .rec:    return ZonePalette.rec
        case .fat:    return ZonePalette.fat
        case .tran:   return ZonePalette.tran
        case .ana:    return ZonePalette.ana
        case .stress: return ZonePalette.stress
        }
    }
}
