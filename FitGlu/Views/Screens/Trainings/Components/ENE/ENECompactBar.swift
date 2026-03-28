import SwiftUI

struct ENECompactBar: View {
    let eff: Double   // kcal per stress-min

    /// Нормируем эффективность в 0...1 (условная шкала).
    /// Например, 0–20 kcal/min: 0 → 0%, 20 → 100%.
    private var progress: Double {
        let capped = min(max(eff, 0), 20)
        return capped / 20.0
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray.opacity(0.35))
                Capsule()
                    .fill(Color.blue)
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(height: 12)
        .clipShape(Capsule())
    }
}
