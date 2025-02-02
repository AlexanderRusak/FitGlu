import SwiftUI

struct ContentView: View {
    @State private var trainingData: (training: TrainingRow?, heartRates: [HeartRateLogRow])?
    @State private var selectedTrainingID: Int64 = 1 // Можно выбрать ID вручную

    var body: some View {
        VStack(spacing: 20) {
            Text("Training + Heart Rates")
                .font(.title2)
                .bold()
            
            // Поле ввода ID тренировки
            HStack {
                Text("Training ID:")
                TextField("Enter ID", value: $selectedTrainingID, formatter: NumberFormatter())
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
            }
            
            // Кнопка для загрузки данных
            Button("Load Training + Heart Rates") {
                trainingData = TrainingLogDBManager.shared.getTrainingWithHeartRates(trainingID: selectedTrainingID)
            }
            .buttonStyle(.borderedProminent)
            
            // Вывод данных о тренировке
            if let training = trainingData?.training {
                VStack(alignment: .leading, spacing: 5) {
                    Text("🏋️ Training ID: \(training.id)")
                        .font(.headline)
                        .bold()
                    Text("🔥 Type: \(training.type)")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    Text("🕒 Start: \(formatDate(training.startTime))")
                    Text("🕒 End: \(formatDate(training.endTime))")
                        .padding(.bottom, 10)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            } else {
                Text("No training found.")
                    .font(.footnote)
                    .foregroundColor(.red)
            }
            
            // Вывод списка пульсовых записей
            if let heartRates = trainingData?.heartRates, !heartRates.isEmpty {
                List(heartRates, id: \.id) { hr in
                    VStack(alignment: .leading) {
                        Text("💓 HR: \(hr.heartRate) BPM")
                            .font(.headline)
                        Text("🕒 Time: \(formatDate(hr.timestamp))")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .listStyle(.plain)
            } else {
                Text("No heart rate data available.")
                    .font(.footnote)
                    .foregroundColor(.red)
            }
        }
        .padding()
    }
    
    // Функция для форматирования даты
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
