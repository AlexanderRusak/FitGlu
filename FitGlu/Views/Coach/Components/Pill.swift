import SwiftUI

struct Pill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.thickMaterial, in: Capsule())
    }
}
