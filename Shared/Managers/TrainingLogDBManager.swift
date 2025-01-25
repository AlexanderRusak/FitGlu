//
//  TrainingLogDBManager.swift
//  Shared
//
//  Created by (Your Name) on (Date).
//

import Foundation
import SQLite

#if os(watchOS)
import WatchConnectivity
#endif

public class TrainingLogDBManager {
    
    public static let shared = TrainingLogDBManager()
    
    // База данных (singleton)
    private let db = DatabaseService.shared.db
    
    // Таблица training_log
    private let tableTrainingLog = Table("training_log")
    
    // Поля
    private let colID = SQLite.Expression<Int64>("id")
    private let colType = SQLite.Expression<String>("training_type")
    private let colStartDate = SQLite.Expression<Double>("start_date")
    private let colEndDate = SQLite.Expression<Double?>("end_date")
    private let colIsSynced = SQLite.Expression<Bool>("isSynced")
    
    // Приватный инициализатор (Singleton)
    private init() {
        do {
            try createTable()
        } catch {
            print("TrainingLogDBManager: error createTable: \(error)")
        }
    }
    
    /// Создаём таблицу (если нет)
    private func createTable() throws {
        try db.run(tableTrainingLog.create(ifNotExists: true) { t in
            t.column(colID, primaryKey: true)
            t.column(colType)
            t.column(colStartDate)
            t.column(colEndDate)
            t.column(colIsSynced, defaultValue: false)
        })
    }
    
    // MARK: - CRUD: Start/Finish
    
    /// Начинаем новую тренировку
    @discardableResult
    public func startTraining(type: TrainingType) -> Int64? {
        let now = Date().timeIntervalSince1970
        let insert = tableTrainingLog.insert(
            colType <- type.rawValue,
            colStartDate <- now,
            colEndDate <- nil,
            colIsSynced <- false
        )
        do {
            let rowID = try db.run(insert)
            print("TrainingLogDBManager: Inserted training id=\(rowID) (type=\(type.rawValue))")
            return rowID
        } catch {
            print("TrainingLogDBManager startTraining error: \(error)")
            return nil
        }
    }
    
    public func rawUpdateStartEnd(_ id: Int64, _ start: Double, _ end: Double) {
        let row = tableTrainingLog.filter(colID == id)
        do {
            try db.run(row.update(
                colStartDate <- start,
                colEndDate <- end
            ))
            print("TrainingLogDBManager: Updated start/end for id=\(id)")
        } catch {
            print("rawUpdateStartEnd error: \(error)")
        }
    }
    
    
    /// Завершаем тренировку
    public func finishTraining(id: Int64) {
        let now = Date().timeIntervalSince1970
        let row = tableTrainingLog.filter(colID == id)
        do {
            try db.run(row.update(
                colEndDate <- now,
                colIsSynced <- false
            ))
            print("TrainingLogDBManager: finishTraining id=\(id)")
        } catch {
            print("finishTraining error: \(error)")
        }
    }
    
    // MARK: - markSynced / delete
    public func markSynced(_ id: Int64) {
        let row = tableTrainingLog.filter(colID == id)
        do {
            try db.run(row.update(colIsSynced <- true))
            print("TrainingLogDBManager: markSynced id=\(id)")
        } catch {
            print("markSynced error: \(error)")
        }
    }
    
    public func deleteTraining(_ id: Int64) {
        let row = tableTrainingLog.filter(colID == id)
        do {
            try db.run(row.delete())
            print("TrainingLogDBManager: deleted training id=\(id)")
        } catch {
            print("deleteTraining error: \(error)")
        }
    }
    
    // MARK: - Queries
    /// Выбрать все завершённые, но не синхронизированные
    public func getUnSyncedFinishedTrainings() -> [TrainingRow] {
        var results: [TrainingRow] = []
        let query = tableTrainingLog.filter(colEndDate != nil && colIsSynced == false)
        do {
            for row in try db.prepare(query) {
                let idVal   = try row.get(colID)
                let typeVal = try row.get(colType)
                let startVal = try row.get(colStartDate)
                let endVal  = try row.get(colEndDate) ?? 0
                
                results.append(TrainingRow(
                    id: idVal,
                    type: typeVal,
                    startTime: startVal,
                    endTime: endVal
                ))
            }
        } catch {
            print("getUnSyncedFinishedTrainings error: \(error)")
        }
        return results
    }
    
    /// Печать всех тренировок
    public func getAllTrainings() -> [TrainingRow] {
        var results: [TrainingRow] = []
        do {
            for row in try db.prepare(tableTrainingLog) {
                let idVal   = try row.get(colID)
                let typeVal = try row.get(colType)
                let startVal = try row.get(colStartDate)
                let endVal  = try row.get(colEndDate)
                
                let training = TrainingRow(
                    id: idVal,
                    type: typeVal,
                    startTime: startVal,
                    endTime: endVal ?? 0
                )
                results.append(training)
                
                print("Loaded training: \(training)")
            }
        } catch {
            print("getAllTrainings error: \(error)")
        }
        return results
    }

    
    // MARK: - Sync Logic (только watchOS)
    #if os(watchOS)
    public func syncAllUnSynced() {
        let unsyncedList = getUnSyncedFinishedTrainings()
        guard !unsyncedList.isEmpty else {
            print("No unsynced finished trainings.")
            return
        }
        
        for training in unsyncedList {
            let packet: [String: Any] = [
                "action": "finishWorkout",
                "localID": training.id,
                "type": training.type,
                "startTime": training.startTime,
                "endTime": training.endTime
            ]
            
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(packet, replyHandler: { response in
                    if let status = response["status"] as? String, status == "ok" {
                        self.markSynced(training.id)
                    }
                }, errorHandler: { err in
                    print("syncAllUnSynced error for training=\(training.id): \(err)")
                })
            } else {
                print("Phone not reachable, stop syncAllUnSynced.")
                break
            }
        }
    }
    #endif
}
