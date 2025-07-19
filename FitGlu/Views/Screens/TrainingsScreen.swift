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
                    do {
                        let added = try await vm.analyzeAndSaveAll()
                        statusMessage = added > 0
                          ? "✅ Добавлено \(added) новых сессий"
                          : "ℹ️ Новых сессий не обнаружено"
                    } catch {
                        statusMessage = "❌ Ошибка: \(error.localizedDescription)"
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)

            Text(statusMessage)
                .foregroundColor(.secondary)
                .padding(.top)

            Spacer()
        }
    }

    @MainActor
    private func analyzeAll() async {
        do {
            // ViewModel внутри себя вызовет SessionAnalyzer + SessionZonesDBManager
            let newCount = try await vm.analyzeAndSaveAll()
            statusMessage = "✅ Сохранено \(newCount) новых сессий"
        } catch {
            statusMessage = "❌ Ошибка: \(error.localizedDescription)"
        }
    }
}

struct TrainingsScreen_Previews: PreviewProvider {
    static var previews: some View {
        TrainingsScreen()
    }
}


#Preview {
    TrainingsScreen()
}
