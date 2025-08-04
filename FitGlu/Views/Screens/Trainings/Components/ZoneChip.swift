import SwiftUI   
import Foundation

struct ZoneChip: View {
    let title: String
    let valueText: String
    let color: Color

    var body: some View {
        HStack(spacing: 2) {                  // 2 вместо 4
            Text(title).font(.caption2)
            Text(valueText)
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 6)              // 8 → 6
        .padding(.vertical, 3)                // 4 → 3
        .background(color.opacity(0.15), in: Capsule())
    }
}
