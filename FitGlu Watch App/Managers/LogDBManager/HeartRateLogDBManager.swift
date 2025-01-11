import Foundation
import SQLite

/// Менеджер для работы с таблицей heart_rate_log (пульс).
class HeartRateLogDBManager {
    // Берём Connection из нашего синглтона DatabaseService:
    private let db = DatabaseService.shared.db
    
    // Определяем таблицу и её колонки:
    private let tableHeartRateLog = Table("heart_rate_log")
    
    private let colHRID = SQLite.Expression<Int64>("id")
    private let colTrainingID = SQLite.Expression<Int64>("training_id")
    private let colTimestamp = SQLite.Expression<Double>("timestamp")
    private let colHRValue = SQLite.Expression<Int>("hr_value")
    
    // В конструкторе создаём таблицу (если ещё нет)
    init() {
        do {
            try createTable()
            print("HeartRateLogDBManager: ensure `heart_rate_log` table created.")
        } catch {
            print("Ошибка при создании таблицы `heart_rate_log`: \(error)")
        }
    }
    
    /// Создаём таблицу heart_rate_log, если она отсутствует
    private func createTable() throws {
        try db.run(tableHeartRateLog.create(ifNotExists: true) { table in
            table.column(colHRID, primaryKey: true)     // Автоинкремент ID
            table.column(colTrainingID)                 // Ссылка на training_log.id
            table.column(colTimestamp)                  // Время измерения (например, UNIX time)
            table.column(colHRValue)                    // Само значение пульса
        })
    }
    
    /// Вставляем новую запись пульса (heart rate)
    /// - trainingID: идентификатор записи в training_log
    /// - hrValue: значение пульса (например, 80)
    /// - timestamp: время (Date().timeIntervalSince1970)
    func insertHeartRate(trainingID: Int64, hrValue: Int, timestamp: Double) {
        let insert = tableHeartRateLog.insert(
            colTrainingID <- trainingID,
            colTimestamp <- timestamp,
            colHRValue <- hrValue
        )
        do {
            let rowID = try db.run(insert)
            print("Inserted heart_rate_log rowID = \(rowID) for trainingID = \(trainingID)")
        } catch {
            print("Ошибка вставки пульса: \(error)")
        }
    }
    
    /// Выбираем все записи пульса (timestamp, hrValue) для заданной тренировки
    func getHeartRates(for trainingID: Int64) -> [(timestamp: Double, hrValue: Int)] {
        var results: [(Double, Int)] = []
        
        // Фильтруем по trainingID, сортируем по возрастанию времени
        let query = tableHeartRateLog
            .filter(colTrainingID == trainingID)
            .order(colTimestamp.asc)
        
        do {
            for row in try db.prepare(query) {
                let ts = try row.get(colTimestamp)
                let hr = try row.get(colHRValue)
                results.append((ts, hr))
            }
        } catch {
            print("Ошибка при выборке пульса: \(error)")
        }
        
        return results
    }
    
    /// Печатает ВСЕ записи (для отладки)
    func printAllHeartRates() {
        let query = tableHeartRateLog.order(colTimestamp.asc)
        
        do {
            for row in try db.prepare(query) {
                let idVal       = try row.get(colHRID)
                let trainingVal = try row.get(colTrainingID)
                let tsVal       = try row.get(colTimestamp)
                let hrVal       = try row.get(colHRValue)
                
                let time = Date(timeIntervalSince1970: tsVal)
                print("HEARTRATE -> rowID=\(idVal), trainingID=\(trainingVal), time=\(time), HR=\(hrVal)")
            }
        } catch {
            print("Ошибка при чтении heart_rate_log: \(error)")
        }
    }
    
    /// Печатает записи пульса только для конкретной тренировки
    func printHeartRates(for trainingID: Int64) {
        let query = tableHeartRateLog
            .filter(colTrainingID == trainingID)
            .order(colTimestamp.asc)
        
        do {
            for row in try db.prepare(query) {
                let idVal       = try row.get(colHRID)
                let trainingVal = try row.get(colTrainingID)
                let tsVal       = try row.get(colTimestamp)
                let hrVal       = try row.get(colHRValue)
                let time = Date(timeIntervalSince1970: tsVal)
                
                print("HEARTRATE for training=\(trainingVal): rowID=\(idVal), time=\(time), HR=\(hrVal)")
            }
        } catch {
            print("Ошибка при чтении heart_rate_log для trainingID=\(trainingID): \(error)")
        }
    }
}
