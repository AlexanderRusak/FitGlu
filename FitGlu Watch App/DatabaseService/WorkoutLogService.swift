import Foundation

class WorkoutLogService {
    private let trainingManager = TrainingLogDBManager.shared
    private let heartRateManager = HeartRateLogDBManager.shared  // Добавляем менеджер пульса
    
    /// Начать тренировку
    @discardableResult
    func startWorkout(type: TrainingType) -> Int64? {
        print("=== WorkoutLogService: startWorkout(\(type.rawValue)) ===")
        let trainingID = trainingManager.startTraining(type: type)
        if let tid = trainingID {
            print("✅ Workout started with ID = \(tid), type = \(type.rawValue)")
        }
        return trainingID
    }
    
    /// Завершить тренировку
    func stopWorkout(trainingID: Int64) {
        print("=== WorkoutLogService: stopWorkout(\(trainingID)) ===")
        trainingManager.finishTraining(id: trainingID)
        HeartRateLogDBManager.shared.printAllHeartRates()
    }
    
    /// Записать пульс (heart rate) для указанной тренировки
    func recordHeartRate(trainingID: Int64, hrValue: Int) {
        print("=== WorkoutLogService: recordHeartRate(\(hrValue)) for trainingID=\(trainingID) ===")
        let now = Date().timeIntervalSince1970
        
        // ✅ Записываем пульс в БД
        heartRateManager.insertHeartRate(trainingID: trainingID, hrValue: hrValue, timestamp: now)
    }
    
    /// Вывести в консоль данные об одной тренировке и её пульсовых записях
    func debugPrintAll(for trainingID: Int64) {
        print("=== WorkoutLogService: debugPrintAll(for: \(trainingID)) ===")
        
        // Выводим информацию о тренировке
        let training = trainingManager.getAllTrainings().first { $0.id == trainingID }
        if let training = training {
            print("TRAINING -> ID=\(training.id), type=\(training.type), start=\(training.startTime), end=\(training.endTime)")
        } else {
            print("⚠️ Training ID=\(trainingID) not found.")
        }

        // Выводим записи пульса
        let heartRates = heartRateManager.getUnSyncedHeartRates(for: trainingID)
        heartRates.forEach { hr in
            print("💓 HEARTRATE -> ID=\(hr.id), trainingID=\(hr.trainingID), value=\(hr.heartRate), time=\(Date(timeIntervalSince1970: hr.timestamp))")
        }
    }
}
