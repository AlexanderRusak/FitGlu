import Foundation

public struct WorkoutTemplateRow: Identifiable {
    public let id: Int64
    public let name: String
    public let groupLabel: String?
    public let createdAt: Int64
}

public struct WorkoutTemplateItemRow: Identifiable {
    public let id: Int64
    public let templateId: Int64
    public let exerciseName: String
    public let orderIndex: Int
    public let notes: String?
    public let setsCount: Int
    public let weights: [Double?]
    public let reps: [Int?]
}

@MainActor
final class TemplatesViewModel: ObservableObject {
    @Published var templates: [WorkoutTemplateRow] = []
    @Published var itemsByTemplateId: [Int64: [WorkoutTemplateItemRow]] = [:]

    private let manager = WorkoutDiaryDBManager.shared

    func load() {
        templates = manager.fetchTemplates()
    }

    func loadDetails(templateId: Int64) {
        itemsByTemplateId[templateId] = manager.fetchTemplateItems(templateId: templateId)
    }

    func delete(id: Int64) {
        manager.deleteTemplate(templateId: id)
        load()
    }

    func apply(id: Int64, dayKey: Int64) {
        _ = manager.applyTemplate(templateId: id, dayKey: dayKey)
        load()
    }
    
    func rename(id: Int64, newName: String) {
        manager.renameTemplate(templateId: id, newName: newName)
        load()
    }

    func duplicate(id: Int64) {
        _ = manager.duplicateTemplate(templateId: id)
        load()
    }
}
