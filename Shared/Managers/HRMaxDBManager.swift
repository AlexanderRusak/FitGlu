import Foundation
import SQLite

/// Единичная «активная» запись HRmax + история изменений.
/// Храним последнее известное значение, когда/откуда получено и
/// сколько секунд было ≥90% HR в «доказательстве» (если есть).
public struct HRMaxRecord {
    public let hrmax: Int
    public let recordedAt: Int              // unix time (сек)
    public let sourceTrainingId: Int64?     // id тренировки, если известно
    public let evidenceSecAt90: Int         // секунд ≥90% HRmax в сессии (если есть)
    public let updatedAt: Int               // unix time последнего апдейта
}

/// Хранилище HRmax (SQLite.swift)
public final class HRMaxDBManager {

    // MARK: - Singleton
    public static let shared = HRMaxDBManager()
    private init() {
        createTablesIfNeeded()
    }

    // MARK: - DB
    private let db: Connection = DatabaseService.shared.db

    // Текущая запись (одна строка)
    private let currentTable = Table("hrmax_current")
    private let c_id         = SQLite.Expression<Int64>("id")
    private let c_hrmax      = SQLite.Expression<Int>("hrmax")
    private let c_recordedAt = SQLite.Expression<Int>("recorded_at")
    private let c_sourceTrId = SQLite.Expression<Int64?>("source_training_id")
    private let c_evid90     = SQLite.Expression<Int>("evidence_sec_at90")
    private let c_updatedAt  = SQLite.Expression<Int>("updated_at")

    // История изменений
    private let historyTable = Table("hrmax_history")
    private let h_id         = SQLite.Expression<Int64>("id")
    private let h_hrmax      = SQLite.Expression<Int>("hrmax")
    private let h_recordedAt = SQLite.Expression<Int>("recorded_at")
    private let h_sourceTrId = SQLite.Expression<Int64?>("source_training_id")
    private let h_evid90     = SQLite.Expression<Int>("evidence_sec_at90")
    private let h_createdAt  = SQLite.Expression<Int>("created_at")

    // MARK: - Schema
    private func createTablesIfNeeded() {
        do {
            try db.run(currentTable.create(ifNotExists: true) { t in
                t.column(c_id, primaryKey: .autoincrement)
                t.column(c_hrmax)
                t.column(c_recordedAt)
                t.column(c_sourceTrId)
                t.column(c_evid90)
                t.column(c_updatedAt)
            })
            try db.run(historyTable.create(ifNotExists: true) { t in
                t.column(h_id, primaryKey: .autoincrement)
                t.column(h_hrmax)
                t.column(h_recordedAt)
                t.column(h_sourceTrId)
                t.column(h_evid90)
                t.column(h_createdAt)
            })
        } catch {
            print("❌ HRMaxDBManager schema error:", error)
        }
    }

    // MARK: - Read
    /// Текущая запись (если есть)
    public func current() -> HRMaxRecord? {
        do {
            if let row = try db.pluck(currentTable.limit(1)) {
                return HRMaxRecord(
                    hrmax: row[c_hrmax],
                    recordedAt: row[c_recordedAt],
                    sourceTrainingId: row[c_sourceTrId],
                    evidenceSecAt90: row[c_evid90],
                    updatedAt: row[c_updatedAt]
                )
            }
        } catch {
            print("❌ HRMaxDBManager current() error:", error)
        }
        return nil
    }

    /// Удобное получение числа (если нет — nil)
    public func currentValue() -> Int? {
        current()?.hrmax
    }

    /// Возврат значения с дефолтом 220−age (с клампом 160…230), если в БД пусто.
    public func valueOrDefault(age: Int?) -> Int {
        if let v = currentValue() { return v }
        let fallback: Int
        if let age {
            fallback = Swift.min(230, Swift.max(160, 220 - age))
        } else {
            fallback = 190
        }
        return fallback
    }

    // MARK: - Write
    /// Жёсткая установка (например, ручная правка в настройках).
    /// Также добавляет запись в историю.
    @discardableResult
    public func set(hrmax: Int,
                    recordedAt: TimeInterval,
                    sourceTrainingId: Int64? = nil,
                    evidenceSecAt90: Int = 0) throws -> HRMaxRecord {

        let now = Int(Date().timeIntervalSince1970)
        let recAt = Int(recordedAt)

        do {
            if let row = try db.pluck(currentTable.limit(1)) {
                // апдейт существующей строки
                let idValue = row[c_id]
                let record  = currentTable.filter(c_id == idValue)
                try db.run(record.update(
                    c_hrmax      <- hrmax,
                    c_recordedAt <- recAt,
                    c_sourceTrId <- sourceTrainingId,
                    c_evid90     <- evidenceSecAt90,
                    c_updatedAt  <- now
                ))
            } else {
                // первая запись
                try db.run(currentTable.insert(
                    c_hrmax      <- hrmax,
                    c_recordedAt <- recAt,
                    c_sourceTrId <- sourceTrainingId,
                    c_evid90     <- evidenceSecAt90,
                    c_updatedAt  <- now
                ))
            }

            // всегда логируем в историю
            try db.run(historyTable.insert(
                h_hrmax      <- hrmax,
                h_recordedAt <- recAt,
                h_sourceTrId <- sourceTrainingId,
                h_evid90     <- evidenceSecAt90,
                h_createdAt  <- now
            ))

            return HRMaxRecord(hrmax: hrmax,
                               recordedAt: recAt,
                               sourceTrainingId: sourceTrainingId,
                               evidenceSecAt90: evidenceSecAt90,
                               updatedAt: now)

        } catch {
            print("❌ HRMaxDBManager set() error:", error)
            throw error
        }
    }

    /// «Подними, если выше»: используется при автоматическом обнаружении пика.
    /// Возвращает true, если значение было обновлено.
    @discardableResult
    public func bumpIfHigher(observed: Int,
                             recordedAt: TimeInterval,
                             sourceTrainingId: Int64? = nil,
                             evidenceSecAt90: Int = 0) -> Bool {

        // Фильтруем «мусорные» пики
        guard (120...240).contains(observed) else { return false }

        let current = currentValue() ?? 0
        guard observed > current else { return false }

        do {
            _ = try set(hrmax: observed,
                        recordedAt: recordedAt,
                        sourceTrainingId: sourceTrainingId,
                        evidenceSecAt90: evidenceSecAt90)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Maintenance
    /// Полная очистка (и текущего, и истории) — для отладки.
    public func clearAll() {
        do {
            try db.run(currentTable.delete())
            try db.run(historyTable.delete())
        } catch {
            print("❌ HRMaxDBManager clearAll() error:", error)
        }
    }
}

extension HRMaxDBManager {
    /// Текущая запись HRmax с метаданными (если есть)
    func currentRecord() -> (value: Int, recordedAt: TimeInterval)? {
        do {
            if let row = try db.pluck(currentTable) {
                return (row[c_hrmax], TimeInterval(row[c_recordedAt]))
            }
        } catch {
            print("HRMaxDB.currentRecord() error:", error)
        }
        return nil
    }
}
