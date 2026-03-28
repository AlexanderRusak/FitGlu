import SwiftUI

struct DiaryBlockCard: View {
    let block: WorkoutDiaryBlock
    let onEditSet: (WorkoutDiarySet) -> Void
    let onDeleteSet: (WorkoutDiarySet) -> Void
    let onDeleteBlock: () -> Void
    let onSaveTemplate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header (тип блока + названия упражнений)
            HStack(spacing: 10) {
                Image(systemName: headerIcon)
                    .imageScale(.medium)
                    .foregroundStyle(headerTint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(baseTitle)
                        .font(.headline)

                    Text(exerciseSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .contextMenu {
                Button("Save as template") { onSaveTemplate() }
                Button("Delete block", role: .destructive) { onDeleteBlock() }
            }
            

            // Exercises inside block
            VStack(alignment: .leading, spacing: 10) {
                ForEach(block.exercises) { group in
                    VStack(alignment: .leading, spacing: 8) {

                        Text(group.exerciseName)
                            .font(.subheadline.weight(.semibold))

                        ForEach(group.sets) { set in
                            HStack {
                                Text("Set \(set.setIndex)")
                                    .frame(width: 60, alignment: .leading)
                                    .foregroundStyle(.secondary)

                                if let reps = set.reps { Text("\(reps) reps") }

                                Spacer()

                                if let weight = set.weight {
                                    Text(String(format: "%.1f kg", weight))
                                        .monospacedDigit()
                                }
                            }
                            .font(.subheadline)
                            .contentShape(Rectangle())
                            .onTapGesture { onEditSet(set) }
                            .contextMenu {
                                Button("Edit") { onEditSet(set) }
                                Button("Delete", role: .destructive) { onDeleteSet(set) }
                            }
                        }

                        if let note = group.sets.compactMap({ $0.notes }).first,
                           !note.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "note.text")
                                    .foregroundStyle(.secondary)
                                Text(note)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 2)
                        }
                    }

                    if group.id != block.exercises.last?.id {
                        Divider().opacity(0.12)
                    }
                }
            }
            .padding(10)
            .background(innerBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(12)
        .background(outerBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(borderTint, lineWidth: borderWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Header text

    private var baseTitle: String {
        switch (block.groupLabel ?? "").lowercased() {
        case "superset": return "Superset"
        case "hiit":     return "HIIT"
        default:         return "Exercise"
        }
    }

    private var exerciseSummary: String {
        let names = block.exercises.map { $0.exerciseName }
        if names.isEmpty { return "" }
        return names.joined(separator: " + ")
    }

    // MARK: - Style

    private var headerIcon: String {
        switch (block.groupLabel ?? "").lowercased() {
        case "superset": return "link"
        case "hiit":     return "bolt.fill"
        default:         return "dumbbell.fill"
        }
    }

    private var headerTint: Color {
        switch (block.groupLabel ?? "").lowercased() {
        case "superset": return .blue
        case "hiit":     return .orange
        default:         return .secondary
        }
    }

    private var borderTint: Color {
        switch (block.groupLabel ?? "").lowercased() {
        case "superset": return Color.blue.opacity(0.35)
        case "hiit":     return Color.orange.opacity(0.35)
        default:         return Color.secondary.opacity(0.15)
        }
    }

    private var borderWidth: CGFloat {
        switch (block.groupLabel ?? "").lowercased() {
        case "superset", "hiit": return 1.2
        default: return 1.0
        }
    }

    private var outerBackground: Color {
        Color(.secondarySystemBackground)
    }

    private var innerBackground: Color {
        switch (block.groupLabel ?? "").lowercased() {
        case "superset":
            return Color.blue.opacity(0.06)
        case "hiit":
            return Color.orange.opacity(0.06)
        default:
            return Color(.systemBackground).opacity(0.35)
        }
    }
}
