import Foundation
import SQLite

public class HeartRateLogDBManager {
    
    public static let shared = HeartRateLogDBManager()
    
    // Ссылка на базу данных
    private let db = DatabaseService.shared.db
    
    private let tableHeartRateLog = Table("heart_rate_log")

    private let colID = SQLite.Expression<Int64>("id")
    private let colTrainingID = SQLite.Expression<Int64>("training_id") // Ссылка на training_log
    private let colHeartRate = SQLite.Expression<Int>("heart_rate")
    private let colTimestamp = SQLite.Expression<Double>("timestamp")
    private let colIsSynced = SQLite.Expression<Bool>("isSynced") // Отметка синхронизации

    
    private init() {
        do {
            try createTable()
        } catch {
            print("HeartRateLogDBManager: error createTable: \(error)")
        }
    }
    
    /// Создание таблицы
    private func createTable() throws {
        try db.run(tableHeartRateLog.create(ifNotExists: true) { t in
              t.column(colID, primaryKey: true) // ID записи
              t.column(colTrainingID)          // ID тренировки
              t.column(colHeartRate)           // Значение пульса
              t.column(colTimestamp)           // Время фиксации
              t.column(colIsSynced, defaultValue: false) // Флаг синхронизации
          })
        print("✅ HeartRateLogDBManager: Table `heart_rate_log` created successfully.")
    }
    
    // MARK: - Методы работы с таблицей
    
    public func insertHeartRate(trainingID: Int64, hrValue: Int, timestamp: Double) -> Int64? {
        let insert = tableHeartRateLog.insert(
            colTrainingID <- trainingID,
            colHeartRate <- hrValue,
            colTimestamp <- timestamp,
            colIsSynced <- false
        )
        do {
            let rowID = try db.run(insert)
            print("✅ HeartRateLogDBManager: Inserted heart rate id=\(rowID) for trainingID=\(trainingID)")
            return rowID
        } catch {
            print("❌ HeartRateLogDBManager insertHeartRate error: \(error)")
            return nil
        }
    }
        
    public func getUnSyncedHeartRates(for trainingID: Int64) -> [HeartRateLogRow] {
        var results: [HeartRateLogRow] = []
        let query = tableHeartRateLog.filter(colTrainingID == trainingID && colIsSynced == false)
        do {
            for row in try db.prepare(query) {
                let idVal = try row.get(colID)
                let hrVal = try row.get(colHeartRate)
                let timeVal = try row.get(colTimestamp)
                let item = HeartRateLogRow(id: idVal, trainingID: trainingID, heartRate: hrVal, timestamp: timeVal, isSynced: false)
                results.append(item)
            }
        } catch {
            print("❌ Error fetching unsynced heart rates: \(error)")
        }
        return results
    }
    
    public func markSyncedHeartRates(for trainingID: Int64) {
        let rows = tableHeartRateLog.filter(colTrainingID == trainingID && colIsSynced == false)
        do {
            try db.run(rows.update(colIsSynced <- true))
            print("✅ Marked heart rates as synced for trainingID=\(trainingID)")
        } catch {
            print("❌ Error marking heart rates as synced: \(error)")
        }
    }
    
    public func deleteHeartRates(for trainingID: Int64) {
        let query = tableHeartRateLog.filter(colTrainingID == trainingID)
        do {
            try db.run(query.delete())
            print("✅ HeartRateLogDBManager: Deleted heart rates for trainingID=\(trainingID)")
        } catch {
            print("❌ HeartRateLogDBManager deleteHeartRates error: \(error)")
        }
    }
    
    public func printAllHeartRates() {
        print("=== HeartRateLogDBManager: All Heart Rate Records ===")
        do {
            for row in try db.prepare(tableHeartRateLog) {
                let idVal = try row.get(colID)
                let trainingIDVal = try row.get(colTrainingID)
                let heartRateVal = try row.get(colHeartRate)
                let timeVal = try row.get(colTimestamp)
                let isSyncedVal = try row.get(colIsSynced)
                
                let date = Date(timeIntervalSince1970: timeVal)
                let formattedDate = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .medium)

                print("💓 HR Record -> ID=\(idVal), TrainingID=\(trainingIDVal), BPM=\(heartRateVal), Time=\(formattedDate), Synced=\(isSyncedVal)")
            }
        } catch {
            print("❌ Error fetching heart rate records: \(error)")
        }
    }
    
    public func getHeartRates(for trainingID: Int64) -> [HeartRateLogRow] {
        var results: [HeartRateLogRow] = []
        let query = tableHeartRateLog.filter(colTrainingID == trainingID)

        do {
            for row in try db.prepare(query) {
                let idVal = try row.get(colID)
                let hrVal = try row.get(colHeartRate)
                let timeVal = try row.get(colTimestamp)
                let isSyncedVal = try row.get(colIsSynced)

                let item = HeartRateLogRow(
                    id: idVal,
                    trainingID: trainingID,
                    heartRate: hrVal,
                    timestamp: timeVal,
                    isSynced: isSyncedVal
                )
                results.append(item)
            }
        } catch {
            print("Error fetching heart rates: \(error)")
        }
        
        return results
    }

}
