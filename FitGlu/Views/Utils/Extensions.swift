import Foundation
import SwiftUI

// MARK: - String helpers
public extension String {
    /// Убирает пробелы/переводы строк по краям
    var cleaned: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Comparable helpers
public extension Comparable {
    /// Ограничивает значение рамками диапазона
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - DateFormatter presets
public extension DateFormatter {

    /// «HH:mm:ss»
    static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    /// «14:37» – системный shortTime
    static let shortTime: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()
}

// MARK: - SwiftUI helpers
public extension Color {
    /// Быстрый Color из HEX-кода 0xRRGGBB
    init(hex: UInt, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >>  8) & 0xFF) / 255
        let b = Double((hex      ) & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

public extension ClosedRange where Bound == Date {
    /// Длина диапазона в секундах
    var seconds: TimeInterval { upperBound.timeIntervalSince(lowerBound) }
    var length: TimeInterval { seconds }   // proxy-свойство
}
