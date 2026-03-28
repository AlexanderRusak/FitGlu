import SwiftUI

struct TrainingQualityList: View {
    let qualities: [TrainingQuality]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(qualities) { TrainingQualityCard(q: $0) }
        }
    }
}
