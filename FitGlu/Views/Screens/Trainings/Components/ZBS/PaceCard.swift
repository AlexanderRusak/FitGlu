import SwiftUI

struct PaceCard: View {
    let pace: TimeInterval   // сек / км
    let distance: Double     // км

    private var paceText: String {
        let m = Int(pace) / 60, s = Int(pace) % 60
        return String(format: "%d:%02d /км", m, s)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Средний темп")
                .font(.headline)
            Text(paceText)
                .font(.title2).bold()
            Text(String(format: "Дистанция %.2f км", distance))
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
