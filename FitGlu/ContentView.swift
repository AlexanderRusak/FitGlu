import SwiftUI

struct ContentView: View {
    // Наблюдаем за синглтоном
    @StateObject private var provider = PhoneConnectivityProvider.shared
    @State private var trainings: [TrainingRow] = [] // Храним тренировки

    var body: some View {
        VStack(spacing: 20) {
            Text("Hello, iPhone DB!")
                .font(.headline)
            
            // Показать последнее сообщение от часов
            Text("Last Watch message:")
                .font(.subheadline)
            
            if let msg = provider.lastMessage {
                // Преобразуем словарь в удобный вид
                Text("\(msg)")
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
            } else {
                Text("No message received yet.")
                    .font(.footnote)
            }
            
            // Кнопка для загрузки тренировок
            Button("Load Trainings") {
                trainings = TrainingLogDBManager.shared.getAllTrainings()
            }
            .buttonStyle(.borderedProminent)
            
            // Показ тренировок
            if !trainings.isEmpty {
                List(trainings, id: \.id) { training in
                    VStack(alignment: .leading, spacing: 5) {
                        Text("ID: \(training.id)")
                        Text("Type: \(training.type)")
                        Text("Start: \(formatDate(training.startTime))")
                        Text("End: \(formatDate(training.endTime))")
                    }
                }
                .listStyle(.plain)
            } else {
                Text("No trainings found.")
                    .font(.footnote)
            }
        }
        .padding()
    }
    
    // Форматирование даты
    private func formatDate(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

#Preview {
    ContentView()
}
