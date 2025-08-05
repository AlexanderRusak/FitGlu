import SwiftUI

struct TrimpCard: View {
    let trimp: Double                 // TRIMP (AU)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TRIMP")
                .font(.headline)
            Text(String(format: "%.0f AU", trimp))
                .font(.title2).bold()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
