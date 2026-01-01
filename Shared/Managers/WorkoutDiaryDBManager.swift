import Foundation
import SQLite

public final class WorkoutDiaryDBManager {

    public static let shared = WorkoutDiaryDBManager()

    private let db = DatabaseService.shared.db

    // MARK: - Diary table & columns

    private let tableDiary = Table("workout_diary")

    private let colID          = SQLite.Expression<Int64>("id")
    private let colBlockID     = SQLite.Expression<String>("block_id")
    private let colDayKey      = SQLite.Expression<Int64>("day_key")
    private let colExercise    = SQLite.Expression<String>("exercise_name")
    private let colSetIndex    = SQLite.Expression<Int>("set_index")
    private let colReps        = SQLite.Expression<Int?>("reps")
    private let colWeight      = SQLite.Expression<Double?>("weight")
    private let colDurationSec = SQLite.Expression<Int?>("duration_sec")
    private let colGroupLabel  = SQLite.Expression<String?>("group_label")
    private let colNotes       = SQLite.Expression<String?>("notes")

    // MARK: - Templates tables

    private let tableTemplates     = Table("workout_templates")
    private let tableTemplateItems = Table("workout_template_items")

    private let colTplID          = SQLite.Expression<Int64>("id")
    private let colTplName        = SQLite.Expression<String>("name")
    private let colTplGroupLabel  = SQLite.Expression<String?>("group_label")
    private let colTplCreatedAt   = SQLite.Expression<Int64>("created_at")

    private let colTplItemID       = SQLite.Expression<Int64>("id")
    private let colTplItemTplID    = SQLite.Expression<Int64>("template_id")
    private let colTplItemExercise = SQLite.Expression<String>("exercise_name")
    private let colTplItemOrder    = SQLite.Expression<Int>("order_index")
    private let colTplItemNotes    = SQLite.Expression<String?>("notes")
    private let colTplItemSets     = SQLite.Expression<Int>("sets_count")
    private let colTplItemWeights  = SQLite.Expression<String>("weights_json")
    private let colTplItemReps     = SQLite.Expression<String>("reps_json")

    // MARK: - DEBUG

    private func dropTableForDebug() {
        do {
            try db.run(tableDiary.drop(ifExists: true))
            print("⚠️ DEBUG: table `workout_diary` dropped")
        } catch {
            print("❌ DEBUG: drop table error: \(error)")
        }
    }
    
    private func dropTemplatesForDebug() {
        do {
            try db.run(tableTemplateItems.drop(ifExists: true))
            try db.run(tableTemplates.drop(ifExists: true))
            print("⚠️ DEBUG: templates tables dropped")
        } catch {
            print("❌ DEBUG: drop templates error: \(error)")
        }
    }

    // MARK: - Init

    private init() {
        do {
            // ⚠️ DEBUG ONLY (раскомментировать на 1 запуск при смене схемы)
            // dropTableForDebug()
            // dropTemplatesForDebug()

            try createDiaryTable()
            try createTemplatesTables()
        } catch {
            print("❌ WorkoutDiaryDBManager init error: \(error)")
        }
    }

    // MARK: - Diary schema

    private func createDiaryTable() throws {
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

    // MARK: - Templates schema (9.1)

    private func createTemplatesTables() throws {

        try db.run(tableTemplates.create(ifNotExists: true) { t in
            t.column(colTplID, primaryKey: true)
            t.column(colTplName)
            t.column(colTplGroupLabel)
            t.column(colTplCreatedAt)
        })

        try db.run(tableTemplateItems.create(ifNotExists: true) { t in
            t.column(colTplItemID, primaryKey: true)
            t.column(colTplItemTplID)
            t.column(colTplItemExercise)
            t.column(colTplItemOrder)
            t.column(colTplItemNotes)
            t.column(colTplItemSets)
            t.column(colTplItemWeights)
            t.column(colTplItemReps)
        })

        print("✅ WorkoutDiaryDBManager: templates tables created/exists")
    }

    // MARK: - Fetch diary entries

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
            colBlockID     <- blockId,
            colExercise    <- exerciseName,
            colSetIndex    <- setIndex,
            colReps        <- reps,
            colWeight      <- weight,
            colDurationSec <- durationSec,
            colGroupLabel  <- groupLabel,
            colNotes       <- notes
        )

        do {
            let rowID = try db.run(insert)
            print("✅ WorkoutDiaryDBManager: inserted set id=\(rowID)")
            return rowID
        } catch {
            print("❌ WorkoutDiaryDBManager insertSet error: \(error)")
            return nil
        }
    }

    // MARK: - Update set

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
            print("✅ updated set id=\(id)")
        } catch {
            print("❌ updateSet error: \(error)")
        }
    }

    // MARK: - Delete

    public func deleteSet(id: Int64) {
        let row = tableDiary.filter(colID == id)
        do {
            try db.run(row.delete())
            print("🗑 deleted set id=\(id)")
        } catch {
            print("❌ deleteSet error: \(error)")
        }
    }

    public func deleteAll(for dayKey: Int64) {
        let q = tableDiary.filter(colDayKey == dayKey)
        do {
            try db.run(q.delete())
            print("🗑 deleted all entries for dayKey=\(dayKey)")
        } catch {
            print("❌ deleteAll error: \(error)")
        }
    }
}

// MARK: - Delete block

extension WorkoutDiaryDBManager {

    public func deleteBlock(dayKey: Int64, blockId: String) {
        let q = tableDiary
            .filter(colDayKey == dayKey)
            .filter(colBlockID == blockId)

        do {
            let count = try db.run(q.delete())
            print("🗑 deleted block blockId=\(blockId), count=\(count)")
        } catch {
            print("❌ deleteBlock error: \(error)")
        }
    }
}

// MARK: - Templates (9.2)

extension WorkoutDiaryDBManager {

    /// Сохранить шаблон из существующего блока дневника
    @discardableResult
    public func saveTemplateFromBlock(
        dayKey: Int64,
        blockId: String,
        name: String
    ) -> Int64? {

        // 1. Забираем все строки блока
        let rows = tableDiary
            .filter(colDayKey == dayKey)
            .filter(colBlockID == blockId)

        var diaryRows: [WorkoutDiaryRow] = []

        do {
            for row in try db.prepare(rows) {
                diaryRows.append(
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
            print("❌ saveTemplateFromBlock: fetch rows error: \(error)")
            return nil
        }

        guard !diaryRows.isEmpty else {
            print("⚠️ saveTemplateFromBlock: empty block")
            return nil
        }

        let groupLabel = diaryRows.first?.groupLabel
        let createdAt = Int64(Date().timeIntervalSince1970)

        // 2. Создаём шаблон
        let templateInsert = tableTemplates.insert(
            colTplName       <- name,
            colTplGroupLabel <- groupLabel,
            colTplCreatedAt  <- createdAt
        )

        let templateId: Int64
        do {
            templateId = try db.run(templateInsert)
        } catch {
            print("❌ saveTemplateFromBlock: insert template error: \(error)")
            return nil
        }

        // 3. Группируем по упражнениям
        let grouped = Dictionary(grouping: diaryRows) { $0.exerciseName }

        let exercises = grouped.keys.sorted()

        for (orderIndex, exerciseName) in exercises.enumerated() {
            let sets = grouped[exerciseName]!
                .sorted { $0.setIndex < $1.setIndex }

            let weights = sets.map { $0.weight }
            let reps    = sets.map { $0.reps }
            let notes   = sets.compactMap { $0.notes }.first

            let weightsJSON = (try? JSONEncoder().encode(weights))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

            let repsJSON = (try? JSONEncoder().encode(reps))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

            let itemInsert = tableTemplateItems.insert(
                colTplItemTplID    <- templateId,
                colTplItemExercise <- exerciseName,
                colTplItemOrder    <- orderIndex,
                colTplItemNotes    <- notes,
                colTplItemSets     <- sets.count,
                colTplItemWeights  <- weightsJSON,
                colTplItemReps     <- repsJSON
            )

            do {
                _ = try db.run(itemInsert)
            } catch {
                print("❌ saveTemplateFromBlock: insert item error: \(error)")
            }
        }

        print("✅ Template saved from blockId=\(blockId), templateId=\(templateId)")
        return templateId
    }
    
    public func applyTemplate(templateId: Int64, dayKey: Int64) -> String? {
        // 1) читаем шапку, чтобы взять group_label
        let tplQ = tableTemplates.filter(colTplID == templateId)

        let groupLabel: String?
        do {
            guard let row = try db.pluck(tplQ) else {
                print("❌ applyTemplate: template not found id=\(templateId)")
                return nil
            }
            groupLabel = try row.get(colTplGroupLabel)
        } catch {
            print("❌ applyTemplate: fetch template error: \(error)")
            return nil
        }

        // 2) читаем items
        let itemsQ = tableTemplateItems
            .filter(colTplItemTplID == templateId)
            .order(colTplItemOrder.asc)

        struct Item {
            let exerciseName: String
            let notes: String?
            let setsCount: Int
            let weights: [Double?]
            let reps: [Int?]
        }

        var items: [Item] = []

        do {
            for r in try db.prepare(itemsQ) {
                let exerciseName = try r.get(colTplItemExercise)
                let notes        = try r.get(colTplItemNotes)
                let setsCount    = try r.get(colTplItemSets)
                let wJSON        = try r.get(colTplItemWeights)
                let rJSON        = try r.get(colTplItemReps)

                let weights = (try? JSONDecoder().decode([Double?].self, from: Data(wJSON.utf8))) ?? []
                let reps    = (try? JSONDecoder().decode([Int?].self,    from: Data(rJSON.utf8))) ?? []

                items.append(Item(
                    exerciseName: exerciseName,
                    notes: notes,
                    setsCount: setsCount,
                    weights: weights,
                    reps: reps
                ))
            }
        } catch {
            print("❌ applyTemplate: fetch items error: \(error)")
            return nil
        }

        guard !items.isEmpty else {
            print("⚠️ applyTemplate: no items for templateId=\(templateId)")
            return nil
        }

        // 3) новый blockId
        let newBlockId = UUID().uuidString

        // 4) вставка в дневник
        for item in items {
            let totalSets = max(1, item.setsCount)

            for idx in 1...totalSets {
                let i = idx - 1
                let weight: Double? = item.weights.indices.contains(i) ? item.weights[i] : item.weights.last ?? nil
                let reps: Int?      = item.reps.indices.contains(i)    ? item.reps[i]    : item.reps.last ?? nil

                _ = insertSet(
                    dayKey: dayKey,
                    blockId: newBlockId,
                    exerciseName: item.exerciseName,
                    setIndex: idx,
                    reps: reps,
                    weight: weight,
                    durationSec: nil,
                    groupLabel: groupLabel,
                    notes: item.notes
                )
            }
        }

        print("✅ applyTemplate: templateId=\(templateId) applied to dayKey=\(dayKey), newBlockId=\(newBlockId)")
        return newBlockId
    }
    
    public func fetchTemplates() -> [WorkoutTemplateRow] {
        var res: [WorkoutTemplateRow] = []
        let q = tableTemplates.order(colTplCreatedAt.desc)

        do {
            for r in try db.prepare(q) {
                res.append(
                    WorkoutTemplateRow(
                        id: try r.get(colTplID),
                        name: try r.get(colTplName),
                        groupLabel: try r.get(colTplGroupLabel),
                        createdAt: try r.get(colTplCreatedAt)
                    )
                )
            }
        } catch {
            print("❌ fetchTemplates error: \(error)")
        }
        return res
    }

    public func deleteTemplate(templateId: Int64) {
        do {
            // сначала items
            let itemsQ = tableTemplateItems.filter(colTplItemTplID == templateId)
            _ = try db.run(itemsQ.delete())

            // потом header
            let tplQ = tableTemplates.filter(colTplID == templateId)
            _ = try db.run(tplQ.delete())

            print("🗑 deleted template id=\(templateId)")
        } catch {
            print("❌ deleteTemplate error: \(error)")
        }
    }
    
    public func fetchTemplateItems(templateId: Int64) -> [WorkoutTemplateItemRow] {
        var res: [WorkoutTemplateItemRow] = []

        let q = tableTemplateItems
            .filter(colTplItemTplID == templateId)
            .order(colTplItemOrder.asc)

        do {
            for r in try db.prepare(q) {
                let id        = try r.get(colTplItemID)
                let exercise  = try r.get(colTplItemExercise)
                let order     = try r.get(colTplItemOrder)
                let notes     = try r.get(colTplItemNotes)
                let setsCount = try r.get(colTplItemSets)

                let wJSON = try r.get(colTplItemWeights)
                let rJSON = try r.get(colTplItemReps)

                let weights = (try? JSONDecoder().decode([Double?].self, from: Data(wJSON.utf8))) ?? []
                let reps    = (try? JSONDecoder().decode([Int?].self,    from: Data(rJSON.utf8))) ?? []

                res.append(
                    WorkoutTemplateItemRow(
                        id: id,
                        templateId: templateId,
                        exerciseName: exercise,
                        orderIndex: order,
                        notes: notes,
                        setsCount: setsCount,
                        weights: weights,
                        reps: reps
                    )
                )
            }
        } catch {
            print("❌ fetchTemplateItems error: \(error)")
        }

        return res
    }

    public func renameTemplate(templateId: Int64, newName: String) {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let q = tableTemplates.filter(colTplID == templateId)
        do {
            _ = try db.run(q.update(colTplName <- name))
            print("✅ renamed template id=\(templateId) -> '\(name)'")
        } catch {
            print("❌ renameTemplate error: \(error)")
        }
    }

    @discardableResult
    public func duplicateTemplate(templateId: Int64, newName: String? = nil) -> Int64? {
        // 1) читаем оригинал
        let tplQ = tableTemplates.filter(colTplID == templateId)

        let original: WorkoutTemplateRow
        do {
            guard let row = try db.pluck(tplQ) else { return nil }
            original = WorkoutTemplateRow(
                id: try row.get(colTplID),
                name: try row.get(colTplName),
                groupLabel: try row.get(colTplGroupLabel),
                createdAt: try row.get(colTplCreatedAt)
            )
        } catch {
            print("❌ duplicateTemplate: fetch template error: \(error)")
            return nil
        }

        // 2) читаем items
        let items = fetchTemplateItems(templateId: templateId)
        guard !items.isEmpty else { return nil }

        // 3) создаём новый template
        let createdAt = Int64(Date().timeIntervalSince1970)
        let name = (newName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? "\(original.name) (copy)"

        let insertTpl = tableTemplates.insert(
            colTplName       <- name,
            colTplGroupLabel <- original.groupLabel,
            colTplCreatedAt  <- createdAt
        )

        let newTplId: Int64
        do {
            newTplId = try db.run(insertTpl)
        } catch {
            print("❌ duplicateTemplate: insert new template error: \(error)")
            return nil
        }

        // 4) копируем items
        for it in items.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            let wJSON = (try? JSONEncoder().encode(it.weights))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            let rJSON = (try? JSONEncoder().encode(it.reps))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

            let insItem = tableTemplateItems.insert(
                colTplItemTplID    <- newTplId,
                colTplItemExercise <- it.exerciseName,
                colTplItemOrder    <- it.orderIndex,
                colTplItemNotes    <- it.notes,
                colTplItemSets     <- it.setsCount,
                colTplItemWeights  <- wJSON,
                colTplItemReps     <- rJSON
            )

            do {
                _ = try db.run(insItem)
            } catch {
                print("❌ duplicateTemplate: insert item error: \(error)")
            }
        }

        print("✅ duplicated template \(templateId) -> \(newTplId)")
        return newTplId
    }

}

