import SwiftUI

struct DiaryBlockCard: View {
    let block: WorkoutDiaryBlock
    let onEditSet: (WorkoutDiarySet) -> Void
    let onDeleteSet: (WorkoutDiarySet) -> Void
    let onDeleteBlock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
            }
            .contentShape(Rectangle())
            .contextMenu {
                Button("Delete block", role: .destructive) {
                    onDeleteBlock()
                }
            }

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

                    // ✅ notes показываем один раз после сетов
                    if let note = group.sets.compactMap({ $0.notes }).first,
                       !note.isEmpty {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }

                if group.id != block.exercises.last?.id {
                    Divider().opacity(0.15)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var title: String {
        let base: String
        switch (block.groupLabel ?? "").lowercased() {
        case "superset": base = "Superset"
        case "hiit":     base = "HIIT"
        default:         base = "Exercise"
        }

        let names = block.exercises
            .map { $0.exerciseName }
            .joined(separator: " + ")

        return names.isEmpty ? base : "\(base) · \(names)"
    }

}
