import SwiftUI

enum RingInfoType: Int, Identifiable {
    case readiness
    case recovery
    case quality
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .readiness: return "Readiness score"
        case .recovery:  return "Recovery score"
        case .quality:   return "Training quality"
        }
    }
}

struct ScoreRing: View {
    let score: Int
    let caption: String

    var body: some View {
        ZStack {
            Circle().stroke(.secondary.opacity(0.2), lineWidth: 10)
            Circle()
                .trim(from: 0, to: CGFloat(min(1, max(0, Double(score)/100.0))))
                .stroke(AngularGradient(gradient: Gradient(colors: [.green, .yellow, .orange, .red]),
                                        center: .center),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 4) {
                Text("\(score)").font(.title2.weight(.semibold))
                Text(caption).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
