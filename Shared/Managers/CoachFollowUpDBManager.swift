import Foundation
import SQLite

final class CoachFollowUpDBManager {
    static let shared = CoachFollowUpDBManager()

    private let db: Connection = DatabaseService.shared.db
    private let table = Table("coach_followups")

    private let colID = SQLite.Expression<String>("id")
    private let colDate = SQLite.Expression<Double>("date")
    private let colPlanDateId = SQLite.Expression<String>("plan_date_id")
    private let colProteinHit = SQLite.Expression<Bool?>("protein_hit")
    private let colStepsHit = SQLite.Expression<Bool?>("steps_hit")
    private let colSleepHit = SQLite.Expression<Bool?>("sleep_hit")
    private let colTrainingDone = SQLite.Expression<Bool?>("training_done")
    private let colWeightDelta = SQLite.Expression<Double?>("weight_delta")
    private let colRestingHRDelta = SQLite.Expression<Int?>("resting_hr_delta")
    private let colCreatedAt = SQLite.Expression<Double>("created_at")

    private init() {
        createTableIfNeeded()
    }

    private func createTableIfNeeded() {
        do {
            try db.run(table.create(ifNotExists: true) { t in
                t.column(colID, primaryKey: true)
                t.column(colDate)
                t.column(colPlanDateId)
                t.column(colProteinHit)
                t.column(colStepsHit)
                t.column(colSleepHit)
                t.column(colTrainingDone)
                t.column(colWeightDelta)
                t.column(colRestingHRDelta)
                t.column(colCreatedAt)
            })
        } catch {
            print("❌ CoachFollowUpDBManager schema error: \(error)")
        }
    }

    func upsert(_ followUp: CoachFollowUp) {
        let insert = table.insert(or: .replace,
                                  colID <- followUp.id,
                                  colDate <- followUp.date.timeIntervalSince1970,
                                  colPlanDateId <- followUp.planDateId,
                                  colProteinHit <- followUp.proteinHit,
                                  colStepsHit <- followUp.stepsHit,
                                  colSleepHit <- followUp.sleepHit,
                                  colTrainingDone <- followUp.trainingDone,
                                  colWeightDelta <- followUp.weightDelta,
                                  colRestingHRDelta <- followUp.restingHRDelta,
                                  colCreatedAt <- followUp.createdAt.timeIntervalSince1970)
        do {
            try db.run(insert)
        } catch {
            print("❌ CoachFollowUpDBManager upsert error: \(error)")
        }
    }

    func get(dateID: String) -> CoachFollowUp? {
        let query = table.filter(colID == dateID)
        do {
            guard let row = try db.pluck(query) else { return nil }
            return CoachFollowUp(
                id: row[colID],
                date: Date(timeIntervalSince1970: row[colDate]),
                planDateId: row[colPlanDateId],
                proteinHit: row[colProteinHit],
                stepsHit: row[colStepsHit],
                sleepHit: row[colSleepHit],
                trainingDone: row[colTrainingDone],
                weightDelta: row[colWeightDelta],
                restingHRDelta: row[colRestingHRDelta],
                createdAt: Date(timeIntervalSince1970: row[colCreatedAt])
            )
        } catch {
            print("❌ CoachFollowUpDBManager get error: \(error)")
            return nil
        }
    }
}
