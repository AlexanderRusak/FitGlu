import Foundation
import SQLite

class TrainingLogDBManager {
    
    // Свойство для «базы» SQLite.swift
    private var db: Connection?
    
    // Названия таблицы и столбцов
    private let tableTrainingLog = SQLite.Table("training_log")
    private let colID = SQLite.Expression<Int64>("id")
    private let colType = SQLite.Expression<String>("training_type")
    private let colStartDate = SQLite.Expression<Double>("start_date")
    private let colEndDate = SQLite.Expression<Double?>("end_date")
    
    init() {
        do {
            let documentsUrl = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let fileUrl = documentsUrl.appendingPathComponent("training.db")
            
            db = try Connection(fileUrl.path)
            try createTable()
            
            print("TrainingLogDBManager init: DB created/opened at \(fileUrl.path)")
        } catch {
            print("Ошибка инициализации базы: \(error)")
        }
    }
    
    private func createTable() throws {
        guard let db = db else { return }
        
        try db.run(tableTrainingLog.create(ifNotExists: true) { table in
            table.column(colID, primaryKey: true)
            table.column(colType)
            table.column(colStartDate)
            table.column(colEndDate)
        })
    }
    
    /// Начинаем новую тренировку
    @discardableResult
    func startTraining(type: TrainingType) -> Int64? {
        guard let db = db else { return nil }
        
        let now = Date().timeIntervalSince1970
        let insert = tableTrainingLog.insert(
            colType <- type.rawValue,
            colStartDate <- now,
            colEndDate <- (nil as Double?)
        )
        
        do {
            let rowId = try db.run(insert)
            print("Inserted training log rowId = \(rowId)")
            return rowId
        } catch {
            print("Ошибка вставки записи: \(error)")
            return nil
        }
    }
    
    /// Завершаем тренировку по ID
    func finishTraining(id: Int64) {
        guard let db = db else { return }
        
        let now = Date().timeIntervalSince1970
        let row = tableTrainingLog.filter(colID == id)
        
        do {
            try db.run(row.update(colEndDate <- now))
            print("Updated training log, id = \(id), endDate = \(now)")
        } catch {
            print("Ошибка обновления записи: \(error)")
        }
    }
    
    /// NEW: Печатаем все записи в консоль
    func printAllTrainings() {
        guard let db = db else { return }
        
        do {
            // Перебираем все строки из таблицы
            for row in try db.prepare(tableTrainingLog) {
                let idValue     = try row.get(colID)
                let typeValue   = try row.get(colType)
                let startValue  = try row.get(colStartDate)
                let endValue    = try row.get(colEndDate)
                
                let startDate = Date(timeIntervalSince1970: startValue)
                let endDateString: String
                if let endTime = endValue {
                    let endDate = Date(timeIntervalSince1970: endTime)
                    endDateString = "\(endDate)"
                } else {
                    endDateString = "Not finished"
                }
                
                print("ID: \(idValue), Type: \(typeValue), Start: \(startDate), End: \(endDateString)")
            }
        } catch {
            print("Ошибка чтения записей: \(error)")
        }
    }
}
