import SwiftUI

/// На iOS 16 ключами шкал будут строки (rawValue).
public enum ZoneKind: String, CaseIterable {
    case rec, fat, tran, ana, stress
}

/// Палитры (используй свои цвета, если уже есть)
public enum ZonePalette {
    public static let rec    = Color(hue: 0.34, saturation: 0.70, brightness: 0.75) // зелёный
    public static let fat    = Color(hue: 0.13, saturation: 0.85, brightness: 0.95) // жёлтый
    public static let tran   = Color(hue: 0.10, saturation: 0.75, brightness: 0.90) // янтарный
    public static let ana    = Color(hue: 0.06, saturation: 0.80, brightness: 0.90) // оранжевый
    public static let stress = Color(hue: 0.00, saturation: 0.80, brightness: 0.90) // красный
}
