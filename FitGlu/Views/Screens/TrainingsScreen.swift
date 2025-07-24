import SwiftUI

struct TrainingsScreen: View {
    @StateObject private var vm = DetailsViewModel()
    @State private var statusMessage = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("🏋️ Trainings")
                .font(.title)
                .padding(.top)

            Button("Анализировать и сохранить все сессии") {
                Task {
                    var message: String
                    do {
                        let added = try await vm.analyzeAndSaveAll()
                        message = added > 0
                            ? "✅ Добавлено \(added) новых сессий"
                            : "ℹ️ Новых сессий не обнаружено"
                    } catch {
                        message = "❌ Ошибка: \(error.localizedDescription)"
                    }
                    if let avg = try? AverageZonesDBManager.shared.fetchAverageZones() {
                        message += "\n🔄 Средние зоны:\n" +
                            "Z1 [\(avg.z1[0]),\(avg.z1[1])]  " +
                            "Z2 [\(avg.z2[0]),\(avg.z2[1])]  " +
                            "Z3 [\(avg.z3[0]),\(avg.z3[1])]  " +
                            "Z4 [\(avg.z4[0]),\(avg.z4[1])]  " +
                            "Z5 [\(avg.z5[0]),\(avg.z5[1])]"
                    }
                    statusMessage = message
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)

            // — Отладочная кнопка очистки обеих таблиц —
            Button("🗑️ Очистить session_zones и average_zones") {
                Task {
                    do {
                        try SessionZonesDBManager.shared.clearAll()
                        try AverageZonesDBManager.shared.clearAll()
                        TrainingsStateDBManager.shared.clearAll() // ✅ теперь без try
                        statusMessage = "🗑️ Все очищено"
                    } catch {
                        statusMessage = "❌ Ошибка очистки: \(error.localizedDescription)"
                    }
                }
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
            .padding(.horizontal)

            Text(statusMessage)
                .foregroundColor(.secondary)
                .padding(.top)

            Spacer()
        }
    }
}
