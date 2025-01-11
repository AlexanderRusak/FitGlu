import Foundation
import SQLite

/// Менеджер для работы с таблицей `training_log`, хранящей основные сведения о тренировке.
class TrainingLogDBManager {
    // Используем одно и то же соединение к БД из DatabaseService
    private let db = DatabaseService.shared.db
    
    // Определим нашу таблицу:
    private let tableTrainingLog = Table("training_log")
    
    // Колонки
    private let colID = SQLite.Expression<Int64>("id")
    private let colType = SQLite.Expression<String>("training_type")
    private let colStartDate = SQLite.Expression<Double>("start_date")
    private let colEndDate = SQLite.Expression<Double?>("end_date")
    
    init() {
        do {
            try createTable()
            print("TrainingLogDBManager: ensure `training_log` table created.")
        } catch {
            print("Ошибка при создании таблицы `training_log`: \(error)")
        }
    }
    
    /// Создаём (если нет) таблицу training_log
    private func createTable() throws {
        try db.run(tableTrainingLog.create(ifNotExists: true) { table in
            table.column(colID, primaryKey: true)
            table.column(colType)
            table.column(colStartDate)
            table.column(colEndDate)
        })
    }
    
    /// Начинаем новую тренировку, возвращаем ID записи
    @discardableResult
    func startTraining(type: TrainingType) -> Int64? {
        let now = Date().timeIntervalSince1970
        
        let insert = tableTrainingLog.insert(
            colType <- type.rawValue,
            colStartDate <- now,
            colEndDate <- (nil as Double?)
        )
        
        do {
            let rowId = try db.run(insert)
            print("Inserted training_log rowId = \(rowId), type = \(type.rawValue)")
            return rowId
        } catch {
            print("Ошибка вставки записи в training_log: \(error)")
            return nil
        }
    }
    
    /// Завершаем тренировку (записываем endDate)
    func finishTraining(id: Int64) {
        let now = Date().timeIntervalSince1970
        
        let row = tableTrainingLog.filter(colID == id)
        do {
            try db.run(row.update(colEndDate <- now))
            print("Updated training_log id=\(id), endDate=\(now)")
        } catch {
            print("Ошибка обновления записи: \(error)")
        }
    }
    
    /// Печатаем все записи (для отладки)
    func printAllTrainings() {
        do {
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
                
                print("TRAINING -> ID: \(idValue), type: \(typeValue), start: \(startDate), end: \(endDateString)")
            }
        } catch {
            print("Ошибка чтения training_log: \(error)")
        }
    }
    
    /// (Опционально) Метод для печати конкретной тренировки
    func printTraining(by trainingID: Int64) {
        let row = tableTrainingLog.filter(colID == trainingID)
        do {
            for r in try db.prepare(row) {
                let idValue = try r.get(colID)
                let typeValue = try r.get(colType)
                let startValue = try r.get(colStartDate)
                let endValue = try r.get(colEndDate)
                
                let startDate = Date(timeIntervalSince1970: startValue)
                let endDateStr = endValue != nil ? "\(Date(timeIntervalSince1970: endValue!))" : "Not finished"
                
                print("TRAINING -> ID: \(idValue), type: \(typeValue), start: \(startDate), end: \(endDateStr)")
            }
        } catch {
            print("Ошибка при чтении тренировки \(trainingID): \(error)")
        }
    }
}
