import Foundation
import SwiftUI
import SwiftUICore
struct TodayScoreCard: View {
    @ObservedObject var vm: DailyCoachViewModel
    
    @State private var activeRingInfo: RingInfoType? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today score")
                .font(.headline)
            
            // 🔵 КОЛЬЦА ВВЕРХУ
            HStack(spacing: 16) {
                ringButton(
                    score: vm.metrics.readiness,
                    caption: vm.metrics.coachTag1,
                    info: .readiness
                )
                
                ringButton(
                    score: vm.metrics.trainingReadiness ?? 0,
                    caption: vm.metrics.trainingReadinessLabel ?? "Recover",
                    info: .recovery
                )
                
                if let q = vm.metrics.lastTrainingScore {
                    ringButton(
                        score: q,
                        caption: "Quality",
                        info: .quality
                    )
                }
            }
            
            // 📦 БЛОКИ ВЕС / ПУЛЬС / СОН
            HStack(spacing: 12) {
                TodayStatBlock(
                    title: "Weight",
                    value: vm.metrics.weightString,
                    subtitle: nil
                )
                
                TodayStatBlock(
                    title: "Resting HR",
                    value: vm.metrics.baselineHR.map { "\($0)bpm" } ?? "—",
                    subtitle: nil
                )
                
                TodayStatBlock(
                    title: "Sleep",
                    value: vm.metrics.sleepString,
                    subtitle: nil
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .sheet(item: $activeRingInfo) { info in
            RingInfoSheet(info: info, metrics: vm.metrics)
        }
    }
    
    // Обёртка, чтобы по тапу на кольцо открывать инфо
    private func ringButton(
        score: Int,
        caption: String,
        info: RingInfoType
    ) -> some View {
        Button {
            activeRingInfo = info
        } label: {
            ScoreRing(score: score, caption: caption)
                .frame(width: 80, height: 80)
        }
        .buttonStyle(.plain)
    }
}
