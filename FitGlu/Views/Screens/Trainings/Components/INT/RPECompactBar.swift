import SwiftUI

/// Небольшая полоса 0–10 для свёрнутой шапки.
struct RPECompactBar: View {
    let rpe: Int   // 0...10

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                Capsule()
                    .fill(.blue)
                    .frame(width: max(6, min(CGFloat(rpe)/10.0 * w, w)))
            }
        }
        .frame(height: 8)
        .padding(.vertical, 4)
    }
}
