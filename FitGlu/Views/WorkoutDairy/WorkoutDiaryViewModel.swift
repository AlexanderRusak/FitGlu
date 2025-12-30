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
        let dict = Dictionary(grouping: groups) { $0.blockId }

        return dict.map { blockId, groups in
            let label = groups.first?.groupLabel
            let sorted = groups.sorted { $0.exerciseName < $1.exerciseName }

            return WorkoutDiaryBlock(
                blockId: blockId,
                groupLabel: label,
                exercises: sorted
            )
        }
        // сортировка блоков: по label, потом по имени первого упражнения (можно поменять)
        .sorted {
            ($0.groupLabel ?? "") < ($1.groupLabel ?? "")
        }
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
}
