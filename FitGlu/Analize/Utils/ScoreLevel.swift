import SwiftUI

enum ScoreLevel {
    case easy, fair, good, excellent, overload

    init(score: Double) {
        switch score {
        case ..<25:    self = .easy
        case ..<50:    self = .fair
        case ..<75:    self = .good
        case ..<90:    self = .excellent
        default:       self = .overload
        }
    }

    var label: String {
        switch self {
        case .easy:       "Easy"
        case .fair:       "Fair"
        case .good:       "Good"
        case .excellent:  "Excellent"
        case .overload:   "Overload"
        }
    }

    var color: Color {
        switch self {
        case .easy:      .gray
        case .fair:      .blue
        case .good:      .green
        case .excellent: .orange
        case .overload:  .red
        }
    }
}
