import SwiftUI

struct TemplateDetailsScreen: View {
    let template: WorkoutTemplateRow
    let dayKey: Int64
    let onApplied: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = TemplatesViewModel()

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Type")
                    Spacer()
                    Text(labelText(template.groupLabel))
                        .foregroundStyle(.secondary)
                }
            }

            if let items = vm.itemsByTemplateId[template.id], !items.isEmpty {
                Section("Exercises") {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.exerciseName)
                                .font(.headline)

                            Text(setsPreview(item))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if let n = item.notes, !n.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                HStack(spacing: 8) {
                                    Image(systemName: "note.text")
                                        .foregroundStyle(.secondary)
                                    Text(n)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.top, 2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } else {
                Section {
                    Text("No details.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(template.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Apply") {
                    vm.apply(id: template.id, dayKey: dayKey)
                    onApplied()
                    dismiss()
                }
            }
        }
        .onAppear {
            vm.loadDetails(templateId: template.id)
        }
    }

    private func labelText(_ groupLabel: String?) -> String {
        switch (groupLabel ?? "").lowercased() {
        case "superset": return "Superset"
        case "hiit":     return "HIIT"
        default:         return "Exercise"
        }
    }

    private func setsPreview(_ item: WorkoutTemplateItemRow) -> String {
        // пример: "3 sets · 80×8, 82.5×8, 85×6"
        let pairs: [String] = (0..<max(1, item.setsCount)).map { i in
            let w: Double? = item.weights.indices.contains(i) ? item.weights[i] : item.weights.last ?? nil
            let r: Int?    = item.reps.indices.contains(i)    ? item.reps[i]    : item.reps.last ?? nil

            switch (w, r) {
            case (nil, nil): return "—"
            case (let w?, nil): return String(format: "%.1f×—", w)
            case (nil, let r?): return "—×\(r)"
            case (let w?, let r?): return String(format: "%.1f×%d", w, r)
            }
        }

        let preview = pairs.prefix(5).joined(separator: ", ")
        let more = pairs.count > 5 ? " …" : ""
        return "\(item.setsCount) sets · \(preview)\(more)"
    }
}
