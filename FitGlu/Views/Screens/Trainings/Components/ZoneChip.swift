import SwiftUI   
import Foundation

struct ZoneChip: View {
    let title: String
    let valueText: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(title).font(.caption2).lineLimit(1)
            Text(valueText)
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15), in: Capsule())
        .fixedSize()
    }
}
