import SwiftUI

/// Узкая капсула, повторяющая стиль полосы на карточках.
struct ZBSCompactBar: View {
    /// 0...100
    let score: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.12))
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(0, min(1, score / 100.0)) * geo.size.width)
            }
        }
        .frame(height: 12)
    }
}
