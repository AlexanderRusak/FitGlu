import Foundation
import SQLite

public final class WorkoutDiaryDBManager {

    public static let shared = WorkoutDiaryDBManager()

    private let db = DatabaseService.shared.db

    // MARK: - Table & columns
    private let tableDiary     = Table("workout_diary")

    private let colID          = SQLite.Expression<Int64>("id")
    private let colBlockID = SQLite.Expression<String>("block_id")
    private let colDayKey      = SQLite.Expression<Int64>("day_key")
    private let colExercise    = SQLite.Expression<String>("exercise_name")
    private let colSetIndex    = SQLite.Expression<Int>("set_index")
    private let colReps        = SQLite.Expression<Int?>("reps")
    private let colWeight      = SQLite.Expression<Double?>("weight")
    private let colDurationSec = SQLite.Expression<Int?>("duration_sec")
    private let colGroupLabel  = SQLite.Expression<String?>("group_label")
    private let colNotes       = SQLite.Expression<String?>("notes")

    private func dropTableForDebug() {
        do {
            try db.run(tableDiary.drop(ifExists: true))
            print("⚠️ DEBUG: table `workout_diary` dropped")
        } catch {
            print("❌ DEBUG: drop table error: \(error)")
        }
    }
    
    private init() {
        do {
            // ⚠️ DEBUG ONLY
            // dropTableForDebug()

            try createTable()
        } catch {
            print("❌ WorkoutDiaryDBManager init error: \(error)")
        }
    }

    // MARK: - Table

    private func createTable() throws {
        try db.run(tableDiary.create(ifNotExists: true) { t in
            t.column(colID, primaryKey: true)
            t.column(colBlockID)
            t.column(colDayKey)
            t.column(colExercise)
            t.column(colSetIndex)
            t.column(colReps)
            t.column(colWeight)
            t.column(colDurationSec)
            t.column(colGroupLabel)
            t.column(colNotes)
        })
        print("✅ WorkoutDiaryDBManager: table `workout_diary` created/exists")
    }

    // MARK: - Fetch

    /// Все записи дневника для конкретного дня (dayKey = startOfDay.timeIntervalSince1970).
    public func entries(for dayKey: Int64) -> [WorkoutDiaryRow] {
        var result: [WorkoutDiaryRow] = []

        let query = tableDiary
            .filter(colDayKey == dayKey)
            .order(colExercise.asc, colSetIndex.asc, colID.asc)

        do {
            for row in try db.prepare(query) {
                result.append(
                    WorkoutDiaryRow(
                        id:          try row.get(colID),
                        dayKey:      try row.get(colDayKey),
                        exerciseName:try row.get(colExercise),
                        setIndex:    try row.get(colSetIndex),
                        blockId:     try row.get(colBlockID),
                        reps:        try row.get(colReps),
                        weight:      try row.get(colWeight),
                        durationSec: try row.get(colDurationSec),
                        groupLabel:  try row.get(colGroupLabel),
                        notes:       try row.get(colNotes)
                    )
                )
            }
        } catch {
            print("❌ WorkoutDiaryDBManager entries(for:) error: \(error)")
        }

        return result
    }

    // MARK: - Insert one set

    /// Добавить один сет (подход) в дневник.
    @discardableResult
    public func insertSet(
        dayKey: Int64,
        blockId: String,
        exerciseName: String,
        setIndex: Int,
        reps: Int?,
        weight: Double?,
        durationSec: Int?,
        groupLabel: String?,
        notes: String?
    ) -> Int64? {
        let insert = tableDiary.insert(
            colDayKey      <- dayKey,
            colExercise    <- exerciseName,
            colSetIndex    <- setIndex,
            colReps        <- reps,
            colWeight      <- weight,
            colDurationSec <- durationSec,
            colGroupLabel  <- groupLabel,
            colNotes       <- notes,
            colBlockID <- blockId,
        )

        do {
            let rowID = try db.run(insert)
            print("✅ WorkoutDiaryDBManager: inserted set id=\(rowID) for dayKey=\(dayKey)")
            return rowID
        } catch {
            print("❌ WorkoutDiaryDBManager insertSet error: \(error)")
            return nil
        }
    }

    // MARK: - Update one set

    /// Обновить один подход (сет) по его id.
    public func updateSet(
        id: Int64,
        reps: Int?,
        weight: Double?,
        notes: String?
    ) {
        let row = tableDiary.filter(colID == id)

        do {
            try db.run(row.update(
                colReps   <- reps,
                colWeight <- weight,
                colNotes  <- notes
            ))
            print("✅ WorkoutDiaryDBManager: updated set id=\(id)")
        } catch {
            print("❌ WorkoutDiaryDBManager updateSet error: \(error)")
        }
    }

    // MARK: - Delete

    /// Удалить один сет.
    public func deleteSet(id: Int64) {
        let row = tableDiary.filter(colID == id)
        do {
            let count = try db.run(row.delete())
            print("🗑 WorkoutDiaryDBManager: deleted set id=\(id), count=\(count)")
        } catch {
            print("❌ WorkoutDiaryDBManager deleteSet error: \(error)")
        }
    }

    /// Удалить все записи за день (опционально, если нужно).
    public func deleteAll(for dayKey: Int64) {
        let q = tableDiary.filter(colDayKey == dayKey)
        do {
            let count = try db.run(q.delete())
            print("🗑 WorkoutDiaryDBManager: deleted \(count) entries for dayKey=\(dayKey)")
        } catch {
            print("❌ WorkoutDiaryDBManager deleteAll error: \(error)")
        }
    }
}

// MARK: - Delete block

extension WorkoutDiaryDBManager {

    /// Удалить весь блок упражнения за день: все сеты для (dayKey + exerciseName + groupLabel)
    public func deleteBlock(dayKey: Int64, blockId: String) {
        let q = tableDiary
            .filter(colDayKey == dayKey)
            .filter(colBlockID == blockId)

        do {
            let count = try db.run(q.delete())
            print("🗑 deleted block blockId=\(blockId), count=\(count)")
        } catch {
            print("❌ deleteBlock(blockId) error: \(error)")
        }
    }
}


