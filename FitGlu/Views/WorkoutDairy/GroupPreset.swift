import Foundation

enum WorkoutGroupPreset: String, CaseIterable, Identifiable {
    case none       // обычное упражнение / без группы
    case superset   // супerset-блок
    case hiit       // HIIT-блок
    case custom     // своё название

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return "No group"
        case .superset:
            return "Superset"
        case .hiit:
            return "HIIT block"
        case .custom:
            return "Custom…"
        }
    }

    /// Короткий текст, который пойдёт в базу, если не custom.
    var labelValue: String? {
        switch self {
        case .none:
            return nil
        case .superset:
            return "Superset"
        case .hiit:
            return "HIIT"
        case .custom:
            return nil   // для custom берём строку из TextField
        }
    }
}

struct WorkoutDiarySet: Identifiable {
    let id: Int64           // ← id из БД (primary key)
    let setIndex: Int       // номер сета (1,2,3…)
    let reps: Int?
    let weight: Double?
    let durationSec: Int?
    let notes: String?
}

/// Группа сетов по упражнению + ярлык блока (single/superset/HIIT)
struct WorkoutDiaryGroup: Identifiable {
    let blockId: String
    let exerciseName: String
    let groupLabel: String?
    let sets: [WorkoutDiarySet]

    var id: String { "\(blockId)|\(exerciseName)" }
}
