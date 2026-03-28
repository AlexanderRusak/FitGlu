import SwiftUI

struct MockTrainingSettingsView: View {
    @State private var trainingType: TrainingType = .fatBurning
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date().addingTimeInterval(3600)
    @State private var heartRateMin: Int = 60
    @State private var heartRateMax: Int = 180
    @State private var updateInterval: Double = 60 // интервал обновления в секундах
    
    // Для удаления тренировки
    @State private var trainingIDToDelete: Int64 = 0
    
    // Для ручного добавления одного значения пульса
    @State private var manualTrainingID: Int64 = 0
    @State private var manualHeartRate: Int = 0
    @State private var manualHeartRateTime: Date = Date() // время записи пульса


    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Тип тренировки")) {
                    Picker("Тип тренировки", selection: $trainingType) {
                        ForEach(TrainingType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section(header: Text("Время тренировки")) {
                    VStack(alignment: .leading) {
                        Text("Начало тренировки")
                        DatePickerWithSeconds(date: $startTime)
                    }
                    VStack(alignment: .leading) {
                        Text("Конец тренировки")
                        DatePickerWithSeconds(date: $endTime)
                    }
                }
                
                Section(header: Text("Пульс")) {
                    HStack {
                        Text("От:")
                        TextField("Мин. пульс", value: $heartRateMin, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                    }
                    HStack {
                        Text("До:")
                        TextField("Макс. пульс", value: $heartRateMax, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                    }
                }
                
                Section(header: Text("Интервал обновления (сек)")) {
                    Slider(value: $updateInterval, in: 10...300, step: 5)
                    Text("Интервал: \(Int(updateInterval)) сек")
                }
                
                Section {
                    Button("Начать мок тренировку") {
                        startMockTraining()
                    }
                }
                
                Section(header: Text("Удаление тренировки")) {
                    HStack {
                        Text("Training ID:")
                        TextField("Введите ID", value: $trainingIDToDelete, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                    }
                    Button("Удалить тренировку") {
                        HeartRateLogDBManager.shared.deleteHeartRates(for: trainingIDToDelete)
                        TrainingLogDBManager.shared.deleteTraining(trainingIDToDelete)
                    }
                }
                
                Section(header: Text("Добавить пульс вручную")) {
                    HStack {
                        Text("Training ID:")
                        TextField("Введите ID", value: $manualTrainingID, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                    }
                    HStack {
                        Text("Пульс:")
                        TextField("Введите пульс", value: $manualHeartRate, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                    }
                    // Используем кастомный DatePickerWithSeconds для выбора полной даты и времени с секундами
                    DatePickerWithSeconds(date: $manualHeartRateTime)
                    
                    Button("Добавить пульс") {
                        let timestamp = manualHeartRateTime.timeIntervalSince1970
                        HeartRateLogDBManager.shared.insertHeartRate(
                            trainingID: manualTrainingID,
                            hrValue: manualHeartRate,
                            timestamp: timestamp
                        )
                        print("✅ Добавлен пульс \(manualHeartRate) для тренировки \(manualTrainingID) в \(manualHeartRateTime)")
                    }
                }
            }
            .navigationTitle("Настройки тренировки")
        }
    }
    
    private func startMockTraining() {
        let newTraining = TrainingRow(
            id: 0,
            type: trainingType.rawValue,
            startTime: startTime.timeIntervalSince1970,
            endTime: endTime.timeIntervalSince1970
        )
        
        TrainingLogDBManager.shared.insertTraining(training: newTraining) { success, insertedTraining in
            guard success, let trainingInserted = insertedTraining else {
                print("❌ Ошибка при вставке тренировки")
                return
            }
            print("✅ Тренировка записана с ID: \(trainingInserted.id)")
            
            var currentTime = startTime
            while currentTime <= endTime {
                let heartRateValue = Int.random(in: heartRateMin...heartRateMax)
                let heartRateRecord = HeartRateLogRow(
                    id: 0,
                    trainingID: trainingInserted.id,
                    heartRate: heartRateValue,
                    timestamp: currentTime.timeIntervalSince1970,
                    isSynced: false
                )
                
                HeartRateLogDBManager.shared.insertHeartRate(
                    trainingID: heartRateRecord.trainingID,
                    hrValue: heartRateRecord.heartRate,
                    timestamp: heartRateRecord.timestamp
                )
                print("🫀 Вставлен пульс \(heartRateValue) на \(currentTime)")
                currentTime = currentTime.addingTimeInterval(updateInterval)
            }
            
            print("✅ Мок тренировка успешно записана в БД")
        }
    }
}

struct MockTrainingSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        MockTrainingSettingsView()
    }
}
