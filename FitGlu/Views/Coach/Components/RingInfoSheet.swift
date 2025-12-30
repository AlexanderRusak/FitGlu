import Foundation
import SwiftUI
import SwiftUI
struct RingInfoSheet: View {
    let info: RingInfoType
    let metrics: DailyCoachMetrics
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(info.title)
                        .font(.title2.bold())
                        .padding(.bottom, 8)
                    
                    switch info {
                    case .readiness:
                        Text("""
                        Readiness — общий дневной скор (0–100).

                        • Шаги: чем ближе к 8–9k за день, тем лучше.
                        • Сон: 7 часов ≈ 100%, меньше — даёт штраф.
                        • Пульс в покое: чем ближе к базовому, тем лучше.
                        • Белок: чем ближе к целевому количеству, тем лучше.

                        Все компоненты приводятся к 0–1 и усредняются, результат умножается на 100.
                        """)
                        
                    case .recovery:
                        Text("""
                        Recovery — готовность к следующей тренировке (0–100).

                        • Берётся последняя тяжёлая тренировка.
                        • Для её типа считается «окно восстановления» (12–36 ч).
                        • Recovery = (прошедшие часы / окно восстановления), ограничено 0–100%.

                        Если уже тренировка была сегодня — скор показывает больше режим восстановления, чем готовности.
                        """)
                        
                    case .quality:
                        Text("""
                        Quality — качество последней тренировки (0–100).

                        Считается как взвешенное среднее из трёх частей:

                        • Zone Balance (≈40%): насколько хорошо распределено время по твоим персональным пульсовым зонам.
                        • Intensity (≈40%): HR-RPE (0–10), умноженный на 10 → 0–100.
                        • Efficiency (≈20%): ккал за минуту «стресс-времени» (чем больше работы при том же стрессе — тем лучше).

                        Формула:
                        quality = 0.4 * ZBS + 0.4 * Intensity + 0.2 * Efficiency
                        (каждый компонент уже нормирован к 0–100).
                        """)
                    }
                }
                .padding()
            }
            .navigationTitle("How it’s calculated")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
