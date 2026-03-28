import SwiftUI

struct AllGlucoseScreen: View {
    @State private var trainingData: (training: TrainingRow?, heartRates: [HeartRateLogRow], glucoseValues: [GlucoseRow])?
    @State private var selectedTrainingID: Int64 = 1
    @State private var showMockTrainingSettings: Bool = false  // состояние для показа мокера
    @State private var selectedDate = Date()
    @State private var showDatePicker = false
    
    @StateObject private var vm = DetailsViewModel();
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
        VStack(spacing: 20) {
            Text("All Glucose Screen")
                .font(.title2)
                .bold()

            HStack {
                Text("Training ID:")
                TextField("Enter ID", value: $selectedTrainingID, formatter: NumberFormatter())
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
            }
            

            Button("Load Training Data") {
                let trainingRes = TrainingLogDBManager.shared.getTrainingWithHeartRates(trainingID: selectedTrainingID)
                if let training = trainingRes.training {
                    let start = training.startTime
                    let end = training.endTime

                    print("\u{1F3CB}\u{FE0F} Selected Training ID=\(training.id)")
                    print("\u{25B6}\u{FE0F} Start: \(formatDate(start))")
                    print("\u{23F9}\u{FE0F} End:   \(formatDate(end))")
                    
                    // Выводим пульсовые данные
                    print("\u{1F4AA} Loaded \(trainingRes.heartRates.count) heart rate entries")
                    for hr in trainingRes.heartRates {
                        let hrTimeStr = formatDate(hr.timestamp)
                        print("\u{1F4AA} Heart Rate=\(hr.heartRate), Time=\(hrTimeStr)")
                    }

                    let glucose = GlucoseLogDBManager.shared.getGlucoseInRange(start: start, end: end)
                    print("\u{1F522} Loaded \(glucose.count) glucose entries")
                    for g in glucose {
                        let timeStr = formatDate(g.timestamp)
                        let offsetStart = g.timestamp - start
                        let offsetEnd = g.timestamp - end
                        print("\u{1FA78} Glucose=\(g.glucoseValue), Time=\(timeStr), +\(Int(offsetStart))s from start, \(offsetEnd > 0 ? "+" : "")\(Int(offsetEnd))s from end")
                    }

                    trainingData = (training, trainingRes.heartRates, glucose)
                } else {
                    print("\u{274C} No training found for ID=\(selectedTrainingID)")
                    trainingData = nil
                }
            }

            Button("Show Glucose Logs") {
                let glucoseLogs = GlucoseLogDBManager.shared.getAllGlucose()
                for g in glucoseLogs {
                    print("\u{1FA78} ID=\(g.id), Value=\(g.glucoseValue), Time=\(Date(timeIntervalSince1970: g.timestamp))")
                }
            }

            Button("Show All Trainings") {
                let allTrainings = TrainingLogDBManager.shared.getAllTrainings()
                for t in allTrainings {
                    print("\u{1F3CB}\u{FE0F} Training ID=\(t.id), Type=\(t.type), Start=\(Date(timeIntervalSince1970: t.startTime)), End=\(Date(timeIntervalSince1970: t.endTime))")
                }
            }
            DateHeaderView(date: $selectedDate,
                           showPicker:  $showDatePicker)
            Button("Анализировать HR-CGM") {
                let sessions = SessionAnalyzer
                    .makeSessions(hrSegments: vm.hrSegments,
                                  glucose: vm.glucose,
                                  trainings: vm.trainings)
                print("📊 sessions =", sessions.count)
            }
            
            Divider()
                .padding(.vertical)
            
            // Кнопка для запуска мок тренировки
            Button("Запустить мок тренировку") {
                showMockTrainingSettings.toggle()
            }
            .sheet(isPresented: $showMockTrainingSettings) {
                MockTrainingSettingsView()
            }
        }
        .padding()
        .task(id: selectedDate) {
            do {
                try await vm.load(for: selectedDate)
            } catch {
                print("❌ Ошибка при загрузке данных за \(selectedDate):", error)
            }
        }
    }
}

private func formatDate(_ timestamp: Double) -> String {
    let date = Date(timeIntervalSince1970: timestamp)
    let f = DateFormatter()
    f.dateStyle = .short          // «28.04.24»
    f.timeStyle = .medium         // «14:37:05»
    return f.string(from: date)
}
