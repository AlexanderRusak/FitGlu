import Foundation

struct WorkoutDiarySummary {
    let totalSets: Int
    let exercisesCount: Int
    let supersetExercisesCount: Int
    let approxTonnage: Double?
    let topExercises: [String]   // короткие строки
}

enum WorkoutDiarySummaryBuilder {

    static func makeSummary(for day: Date) -> WorkoutDiarySummary {
        let dayKey = Int64(day.startOfDay.timeIntervalSince1970)
        let rows = WorkoutDiaryDBManager.shared.entries(for: dayKey)

        let totalSets = rows.count

        let byExercise = Dictionary(grouping: rows) { $0.exerciseName }
        let exercisesCount = byExercise.keys.count

        // superset: считаем упражнения, которые хотя бы раз встречались в блоках с groupLabel == "Superset"
        let supersetExercises = Set(rows.compactMap { r -> String? in
            guard (r.groupLabel ?? "").lowercased() == "superset" else { return nil }
            return r.exerciseName
        })
        let supersetExercisesCount = supersetExercises.count

        // tonnage: sum(weight * reps)
        var tonnageByExercise: [String: Double] = [:]
        var totalTonnage: Double = 0

        for r in rows {
            guard let w = r.weight, let reps = r.reps else { continue }
            let t = w * Double(reps)
            totalTonnage += t
            tonnageByExercise[r.exerciseName, default: 0] += t
        }

        let approxTonnage: Double? = totalTonnage > 0 ? totalTonnage : nil

        // top exercises: если есть тоннаж — сортируем по нему, иначе по количеству сетов
        let top: [String]
        if !tonnageByExercise.isEmpty {
            top = tonnageByExercise
                .sorted { $0.value > $1.value }
                .prefix(3)
                .map { name, t in "\(name) \(Int(t.rounded()))" } // можно убрать цифры в UI позже
        } else {
            top = byExercise
                .sorted { $0.value.count > $1.value.count }
                .prefix(3)
                .map { name, rows in "\(name) \(rows.count) sets" }
        }

        return WorkoutDiarySummary(
            totalSets: totalSets,
            exercisesCount: exercisesCount,
            supersetExercisesCount: supersetExercisesCount,
            approxTonnage: approxTonnage,
            topExercises: top
        )
    }
}
