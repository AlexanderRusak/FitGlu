import SwiftUI

struct WRInfoSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Work / Rest (Peaks)")
                .font(.title2).bold()
            Text("""
Алгоритм находит ярко выраженные пики ЧСС (рабочие подходы) и последующий отдых. \
Показываем количество сетов и средние времена Work/Rest. \
Пороги автоматически подстраиваются под тип тренировки.
""")
            .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .presentationDetents([.medium, .large])
    }
}
