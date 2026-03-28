import Foundation
import SQLite

final class DailySnapshotDBManager {
    static let shared = DailySnapshotDBManager()

    private let db: Connection = DatabaseService.shared.db
    private let table = Table("daily_snapshots")

    private let colID = SQLite.Expression<String>("id")
    private let colDate = SQLite.Expression<Double>("date")
    private let colSteps = SQLite.Expression<Int>("steps")
    private let colSleepMinutes = SQLite.Expression<Int>("sleep_minutes")
    private let colRestingHR = SQLite.Expression<Int>("resting_hr")
    private let colBaselineRHR = SQLite.Expression<Int>("baseline_rhr")
    private let colWeightKg = SQLite.Expression<Double?>("weight_kg")
    private let colProteinG = SQLite.Expression<Int>("protein_g")
    private let colKcalTotal = SQLite.Expression<Int?>("kcal_total")
    private let colReadiness = SQLite.Expression<Int>("readiness")
    private let colTrainingReadiness = SQLite.Expression<Int>("training_readiness")
    private let colTrainingReadinessLabel = SQLite.Expression<String>("training_readiness_label")
    private let colRecoveryProgress = SQLite.Expression<Double>("recovery_progress")
    private let colLastTrainingType = SQLite.Expression<String?>("last_training_type")
    private let colLastTrainingScore = SQLite.Expression<Int?>("last_training_score")
    private let colAnalysisVersion = SQLite.Expression<String>("analysis_version")
    private let colHasKcal = SQLite.Expression<Bool>("has_kcal")
    private let colCreatedAt = SQLite.Expression<Double>("created_at")

    private init() {
        createTableIfNeeded()
    }

    private func createTableIfNeeded() {
        do {
            try db.run(table.create(ifNotExists: true) { t in
                t.column(colID, primaryKey: true)
                t.column(colDate)
                t.column(colSteps)
                t.column(colSleepMinutes)
                t.column(colRestingHR)
                t.column(colBaselineRHR)
                t.column(colWeightKg)
                t.column(colProteinG)
                t.column(colKcalTotal)
                t.column(colReadiness)
                t.column(colTrainingReadiness)
                t.column(colTrainingReadinessLabel)
                t.column(colRecoveryProgress)
                t.column(colLastTrainingType)
                t.column(colLastTrainingScore)
                t.column(colAnalysisVersion)
                t.column(colHasKcal)
                t.column(colCreatedAt)
            })
        } catch {
            print("❌ DailySnapshotDBManager schema error: \(error)")
        }
    }

    func upsert(_ snapshot: DailySnapshot) {
        let insert = table.insert(or: .replace,
                                  colID <- snapshot.id,
                                  colDate <- snapshot.date.timeIntervalSince1970,
                                  colSteps <- snapshot.steps,
                                  colSleepMinutes <- snapshot.sleepMinutes,
                                  colRestingHR <- snapshot.restingHR,
                                  colBaselineRHR <- snapshot.baselineRHR,
                                  colWeightKg <- snapshot.weightKg,
                                  colProteinG <- snapshot.proteinG,
                                  colKcalTotal <- snapshot.kcalTotal,
                                  colReadiness <- snapshot.readiness,
                                  colTrainingReadiness <- snapshot.trainingReadiness,
                                  colTrainingReadinessLabel <- snapshot.trainingReadinessLabel,
                                  colRecoveryProgress <- snapshot.recoveryProgress,
                                  colLastTrainingType <- snapshot.lastTrainingType,
                                  colLastTrainingScore <- snapshot.lastTrainingScore,
                                  colAnalysisVersion <- snapshot.analysisVersion,
                                  colHasKcal <- snapshot.dataQuality.hasKcal,
                                  colCreatedAt <- snapshot.createdAt.timeIntervalSince1970)
        do {
            try db.run(insert)
        } catch {
            print("❌ DailySnapshotDBManager upsert error: \(error)")
        }
    }

    func get(dateID: String) -> DailySnapshot? {
        let query = table.filter(colID == dateID)
        do {
            guard let row = try db.pluck(query) else { return nil }
            return DailySnapshot(
                id: row[colID],
                date: Date(timeIntervalSince1970: row[colDate]),
                steps: row[colSteps],
                sleepMinutes: row[colSleepMinutes],
                restingHR: row[colRestingHR],
                baselineRHR: row[colBaselineRHR],
                weightKg: row[colWeightKg],
                proteinG: row[colProteinG],
                kcalTotal: row[colKcalTotal],
                readiness: row[colReadiness],
                trainingReadiness: row[colTrainingReadiness],
                trainingReadinessLabel: row[colTrainingReadinessLabel],
                recoveryProgress: row[colRecoveryProgress],
                lastTrainingType: row[colLastTrainingType],
                lastTrainingScore: row[colLastTrainingScore],
                analysisVersion: row[colAnalysisVersion],
                dataQuality: .init(hasKcal: row[colHasKcal]),
                createdAt: Date(timeIntervalSince1970: row[colCreatedAt])
            )
        } catch {
            print("❌ DailySnapshotDBManager get error: \(error)")
            return nil
        }
    }
}
