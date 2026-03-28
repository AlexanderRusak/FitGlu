import Foundation

public struct WorkoutDiaryRow: Identifiable {
    public let id: Int64
    public let dayKey: Int64
    public let exerciseName: String
    public let setIndex: Int
    public let blockId: String
    public let reps: Int?
    public let weight: Double?
    public let durationSec: Int?
    public let groupLabel: String?
    public let notes: String?
}
