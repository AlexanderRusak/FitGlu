import Foundation
import SwiftUI

struct ZBSInfoSheet: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Zone Balance Score")
                        .font(.title3).bold()
                    Text("""
                         **Zone Balance Score** показывает, \
                         какую долю тренировки вы провели в «полезных» зонах.

                         * Easy < 25   — слишком лёгко  
                         * Fair 25-49 — нормальная лёгкая работа  
                         * Good 50-74 — оптимальная нагрузка  
                         * Excellent 75-89 — сильная нагрузка  
                         * Overload ≥ 90 — возможен перетрен
                         """)
                }
                .padding()
            }
            .navigationTitle("About score")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
