import Foundation
import SQLite

final class CoachPlanDBManager {
    static let shared = CoachPlanDBManager()

    private let db: Connection = DatabaseService.shared.db
    private let table = Table("coach_plans")

    private let colID = SQLite.Expression<String>("id")
    private let colDate = SQLite.Expression<Double>("date")
    private let colGoal = SQLite.Expression<String>("goal")
    private let colSnapshotId = SQLite.Expression<String>("snapshot_id")
    private let colAnalysisVersion = SQLite.Expression<String>("analysis_version")
    private let colPlanText = SQLite.Expression<String>("plan_text")
    private let colActionsJSON = SQLite.Expression<String>("actions_json")
    private let colAvoid = SQLite.Expression<String>("avoid")
    private let colImprove = SQLite.Expression<String>("improve")
    private let colMotivation = SQLite.Expression<String>("motivation")
    private let colCreatedAt = SQLite.Expression<Double>("created_at")

    private init() {
        createTableIfNeeded()
    }

    private func createTableIfNeeded() {
        do {
            try db.run(table.create(ifNotExists: true) { t in
                t.column(colID, primaryKey: true)
                t.column(colDate)
                t.column(colGoal)
                t.column(colSnapshotId)
                t.column(colAnalysisVersion)
                t.column(colPlanText)
                t.column(colActionsJSON)
                t.column(colAvoid)
                t.column(colImprove)
                t.column(colMotivation)
                t.column(colCreatedAt)
            })
        } catch {
            print("❌ CoachPlanDBManager schema error: \(error)")
        }
    }

    func upsert(_ plan: CoachPlan) {
        let actionsJSON: String
        do {
            let data = try JSONEncoder().encode(plan.actions)
            actionsJSON = String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            print("❌ CoachPlanDBManager actions encode error: \(error)")
            return
        }

        let insert = table.insert(or: .replace,
                                  colID <- plan.id,
                                  colDate <- plan.date.timeIntervalSince1970,
                                  colGoal <- plan.goal.rawValue,
                                  colSnapshotId <- plan.snapshotId,
                                  colAnalysisVersion <- plan.analysisVersion,
                                  colPlanText <- plan.planText,
                                  colActionsJSON <- actionsJSON,
                                  colAvoid <- plan.avoid,
                                  colImprove <- plan.improve,
                                  colMotivation <- plan.motivation,
                                  colCreatedAt <- plan.createdAt.timeIntervalSince1970)
        do {
            try db.run(insert)
        } catch {
            print("❌ CoachPlanDBManager upsert error: \(error)")
        }
    }

    func get(dateID: String) -> CoachPlan? {
        let query = table.filter(colID == dateID)
        do {
            guard let row = try db.pluck(query) else { return nil }
            let actions = decodeActions(row[colActionsJSON])
            let goal = TrainingGoal(rawValue: row[colGoal]) ?? .maintain

            return CoachPlan(
                id: row[colID],
                date: Date(timeIntervalSince1970: row[colDate]),
                goal: goal,
                snapshotId: row[colSnapshotId],
                analysisVersion: row[colAnalysisVersion],
                planText: row[colPlanText],
                actions: actions,
                avoid: row[colAvoid],
                improve: row[colImprove],
                motivation: row[colMotivation],
                createdAt: Date(timeIntervalSince1970: row[colCreatedAt])
            )
        } catch {
            print("❌ CoachPlanDBManager get error: \(error)")
            return nil
        }
    }

    private func decodeActions(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}
