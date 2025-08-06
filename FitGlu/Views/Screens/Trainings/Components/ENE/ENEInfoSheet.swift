import SwiftUI

struct ENEInfoSheet: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Energy Efficiency (kcal / Stress-min)")
                        .font(.title2.bold())

                    Text("Показывает, сколько активных килокалорий вы расходуете на каждую минуту перегруза (в зоне Z5 и выше).")
                        .foregroundStyle(.secondary)

                    Group {
                        Text("Как считаем").font(.headline)
                        Text("""
                        • **Stress-min** — минуты в зоне Z5+ по вашим порогам.
                        • **kcal** — активные калории за тренировку (HealthKit или из записи тренировки).
                        • **Итог** = kcal / Stress-min. Если Stress-min = 0, показывается 0.
                        """)
                    }

                    Group {
                        Text("Как использовать").font(.headline)
                        Text("""
                        • Чем **выше** эффективность при сопоставимых тренировках, тем «дороже» обходится перегруз: много калорий за каждую минуту стресса.
                        • Если цель — «умнее тратить» стресс, следите, чтобы значение **не росло без необходимости** (выкрученная интенсивность, но мало пользы).
                        """)
                    }
                }
                .padding()
            }
            .navigationTitle("About Energy Efficiency")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
}
