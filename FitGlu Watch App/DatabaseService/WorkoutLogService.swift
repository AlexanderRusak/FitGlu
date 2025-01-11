//
//  WorkoutLogService.swift
//  FitGlu Watch App
//
//  Created by Александр Русак on 11/01/2025.
//

import Foundation

class WorkoutLogService {
    private let trainingManager = TrainingLogDBManager()
    private let heartRateManager = HeartRateLogDBManager()
    
    /// Начать тренировку
    @discardableResult
    func startWorkout(type: TrainingType) -> Int64? {
        print("=== WorkoutLogService: startWorkout(\(type.rawValue)) ===")
        let trainingID = trainingManager.startTraining(type: type)
        if let tid = trainingID {
            print("Workout started with ID = \(tid), type = \(type.rawValue)")
        }
        return trainingID
    }
    
    /// Завершить тренировку
    func stopWorkout(trainingID: Int64) {
        print("=== WorkoutLogService: stopWorkout(\(trainingID)) ===")
        trainingManager.finishTraining(id: trainingID)
    }
    
    /// Записать пульс (heart rate) для указанной тренировки
    func recordHeartRate(trainingID: Int64, hrValue: Int) {
        print("=== WorkoutLogService: recordHeartRate(\(hrValue)) for trainingID=\(trainingID) ===")
        let now = Date().timeIntervalSince1970
        heartRateManager.insertHeartRate(trainingID: trainingID, hrValue: hrValue, timestamp: now)
    }
    
    /// Вывести в консоль данные об одной тренировке и её пульсовых записях
    func debugPrintAll(for trainingID: Int64) {
        print("=== WorkoutLogService: debugPrintAll(for: \(trainingID)) ===")
        
        // 1. Печатаем саму тренировку
        trainingManager.printTraining(by: trainingID)
        
        // 2. Печатаем все heart rate записи, связанные с этой тренировкой
        heartRateManager.printHeartRates(for: trainingID)
    }
}
