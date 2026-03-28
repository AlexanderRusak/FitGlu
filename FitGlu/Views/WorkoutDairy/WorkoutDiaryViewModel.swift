import Foundation
import Combine

@MainActor
final class WorkoutDiaryViewModel: ObservableObject {

    // MARK: - Published state

    /// Дата, за которую показываем дневник
    @Published var selectedDate: Date = Date()

    /// Самая поздняя тренировка за день (если есть, из LocalDB)
    @Published var currentTraining: TrainingRow?

    /// Сырые строки дневника из БД
    @Published var entries: [WorkoutDiaryRow] = []

    // MARK: - Dependencies

    private let local   = LocalDBProvider()
    private let manager = WorkoutDiaryDBManager.shared
    
    

    // MARK: - Init

    init() {
        load(for: Date())
    }

    // MARK: - Internal helpers

    /// Ключ дня для БД: startOfDay.timeIntervalSince1970 → Int64
    private var currentDayKey: Int64 {
        Int64(selectedDate.startOfDay.timeIntervalSince1970)
    }

    // MARK: - Loading

    /// Загрузка данных дневника на конкретный день
    func load(for date: Date) {
        selectedDate = date

        // 1) Подтянем тренировки за день (чисто для инфо в хедере)
        let from = date.startOfDay
        let to   = date.endOfDay

        let trainings = local.trainings(from: from, to: to)
        currentTraining = trainings.max(by: { $0.endTime < $1.endTime })

        // 2) Подтянем записи дневника из нашей таблицы
        reload()
    }
    
    func deleteGroup(_ group: WorkoutDiaryGroup) {
        manager.deleteBlock(dayKey: currentDayKey, blockId: group.blockId)
        reload()
    }

    /// Перечитать записи из БД по текущему дню
    func reload() {
        entries = manager.entries(for: currentDayKey)
    }

    // MARK: - Groups for UI

    /// Сгруппированные данные для карточек:
    /// упражнение + groupLabel → массив сетов
    var groups: [WorkoutDiaryGroup] {
        struct GroupKey: Hashable {
            let blockId: String
            let exerciseName: String
        }

        let dict = Dictionary(grouping: entries) { row in
            GroupKey(blockId: row.blockId, exerciseName: row.exerciseName)
        }

        return dict.map { key, rows in
            let sorted = rows.sorted { lhs, rhs in
                if lhs.setIndex != rhs.setIndex {
                    return lhs.setIndex < rhs.setIndex
                } else {
                    return lhs.id < rhs.id
                }
            }

            let sets = sorted.map { row in
                WorkoutDiarySet(
                    id: row.id,
                    setIndex: row.setIndex,
                    reps: row.reps,
                    weight: row.weight,
                    durationSec: row.durationSec,
                    notes: row.notes
                )
            }

            // groupLabel берём из первой строки в группе
            let label = sorted.first?.groupLabel

            return WorkoutDiaryGroup(
                blockId: key.blockId,
                exerciseName: key.exerciseName,
                groupLabel: label,
                sets: sets
            )
        }
        .sorted { $0.exerciseName < $1.exerciseName }
    }
    
    var blocks: [WorkoutDiaryBlock] {
        // 1) группируем записи по blockId
        let byBlock = Dictionary(grouping: entries) { $0.blockId }

        // 2) превращаем в массив блоков + считаем "порядок" блока
        let unsorted: [(block: WorkoutDiaryBlock, sortKey: Int64)] = byBlock.map { blockId, rows in
            // sortKey блока = минимальный row.id
            let blockSortKey = rows.map(\.id).min() ?? Int64.max

            let groupLabel = rows.first?.groupLabel

            // 3) внутри блока группируем по exerciseName
            let byExercise = Dictionary(grouping: rows) { $0.exerciseName }

            // 4) делаем exercises в правильном порядке (по min row.id)
            let exercises: [WorkoutDiaryGroup] = byExercise
                .map { exerciseName, exRows in
                    let exSortKey = exRows.map(\.id).min() ?? Int64.max

                    let sets = exRows
                        .sorted {
                            if $0.setIndex != $1.setIndex { return $0.setIndex < $1.setIndex }
                            return $0.id < $1.id
                        }
                        .map { row in
                            WorkoutDiarySet(
                                id: row.id,
                                setIndex: row.setIndex,
                                reps: row.reps,
                                weight: row.weight,
                                durationSec: row.durationSec,
                                notes: row.notes
                            )
                        }

                    return (WorkoutDiaryGroup(
                        blockId: blockId,
                        exerciseName: exerciseName,
                        groupLabel: groupLabel,
                        sets: sets
                    ), exSortKey)
                }
                .sorted { $0.1 < $1.1 }       // ✅ порядок добавления упражнений
                .map { $0.0 }

            let block = WorkoutDiaryBlock(
                blockId: blockId,
                groupLabel: groupLabel,
                exercises: exercises
            )

            return (block, blockSortKey)
        }

        // 5) сортируем блоки по sortKey (порядок добавления блоков)
        return unsorted
            .sorted { $0.sortKey < $1.sortKey }
            .map { $0.block }
    }

    // MARK: - Adding sets (из шита добавления)

    /// Добавляем сразу блок сетов (single / superset / HIIT)
    func addSets(
        blockId: String,
        exerciseName: String,
        weightsPerSet: [Double?],
        repsPerSet: [Int?],
        sets: Int,
        blockType: WorkoutBlockType,
        notes: String?
    ) {
        let dayKey = currentDayKey
        let groupLabel = blockType.groupLabel   // "Single" / "Superset" / "HIIT" или nil

        let totalSets = max(1, sets)
        let wList = weightsPerSet
        let rList = repsPerSet

        // Если вбили только один вес и/или одни повторы — размножаем на все сеты
        if wList.count <= 1 && rList.count <= 1 {
            let w = wList.first ?? nil
            let r = rList.first ?? nil

            for idx in 1...totalSets {
                _ = manager.insertSet(
                    dayKey: dayKey,
                    blockId: blockId,
                    exerciseName: exerciseName,
                    setIndex: idx,
                    reps: r,
                    weight: w,
                    durationSec: nil,
                    groupLabel: groupLabel,
                    notes: notes,
                )
            }
        } else {
            // Есть паттерны (например "60 70 80") → добиваем последним значением
            for idx in 1...totalSets {

                let wi: Double? = {
                    let i = idx - 1
                    if weightsPerSet.indices.contains(i) { return weightsPerSet[i] }
                    return weightsPerSet.last ?? nil
                }()

                let ri: Int? = {
                    let i = idx - 1
                    if repsPerSet.indices.contains(i) { return repsPerSet[i] }
                    return repsPerSet.last ?? nil
                }()

                _ = manager.insertSet(
                    dayKey: dayKey,
                    blockId: blockId,
                    exerciseName: exerciseName,
                    setIndex: idx,
                    reps: ri,
                    weight: wi,
                    durationSec: nil,
                    groupLabel: groupLabel,
                    notes: notes
                )
            }
        }

        reload()
    }

    // MARK: - Editing / deleting single set

    func updateSet(
        id: Int64,
        reps: Int?,
        weight: Double?,
        notes: String?
    ) {
        manager.updateSet(
            id: id,
            reps: reps,
            weight: weight,
            notes: notes
        )
        reload()
    }

    func deleteSet(id: Int64) {
        manager.deleteSet(id: id)
        reload()
    }
    
    func deleteBlock(blockId: String) {
        manager.deleteBlock(dayKey: currentDayKey, blockId: blockId)
        reload()
    }
    
    func saveTemplateFromBlock(blockId: String, name: String) {
        _ = WorkoutDiaryDBManager.shared.saveTemplateFromBlock(
            dayKey: currentDayKey,
            blockId: blockId,
            name: name
        )
    }
    
    func applyTemplate(templateId: Int64) {
        if let _ = manager.applyTemplate(templateId: templateId, dayKey: currentDayKey) {
            reload()
        }
    }

}
