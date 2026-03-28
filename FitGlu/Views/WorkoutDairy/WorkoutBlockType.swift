import Foundation

enum WorkoutBlockType: String, CaseIterable, Identifiable {
    case single     // обычное упражнение
    case superset   // 2+ упражнений подряд
    case hiit       // HIIT блок

    var id: String { rawValue }

    var title: String {
        switch self {
        case .single:   return "Single"
        case .superset: return "Superset"
        case .hiit:     return "HIIT"
        }
    }

    /// Что будет храниться в groupLabel в БД
    var groupLabel: String? {
        switch self {
        case .single:   return nil
        case .superset: return "Superset"
        case .hiit:     return "HIIT"
        }
    }

    /// Маленькое описание под переключателем
    var hint: String {
        switch self {
        case .single:
            return "One exercise block."
        case .superset:
            return "Several exercises performed back-to-back as one block."
        case .hiit:
            return "HIIT style block with short rest and high intensity."
        }
    }
}
