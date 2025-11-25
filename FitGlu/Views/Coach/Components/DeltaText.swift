import SwiftUI

struct DeltaText: View {
    let title: String
    let value: String
    let delta: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Text(value).font(.body.weight(.semibold))
                if let d = delta {
                    Text(d)
                        .font(.caption2)
                        .foregroundStyle(d.contains("+") ? .red : .green)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.thinMaterial, in: Capsule())
                }
            }
        }
    }
}
