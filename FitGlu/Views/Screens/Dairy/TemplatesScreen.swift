import SwiftUI

struct TemplatesScreen: View {

    let dayKey: Int64
    let onApplied: () -> Void
    
    @State private var showRenameDialog = false
    @State private var renameDraft = ""
    @State private var renameId: Int64? = nil

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = TemplatesViewModel()

    var body: some View {
        List {
            if vm.templates.isEmpty {
                Text("No templates yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vm.templates) { tpl in
                    NavigationLink {
                        TemplateDetailsScreen(
                            template: tpl,
                            dayKey: dayKey,
                            onApplied: onApplied
                        )
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tpl.name).font(.headline)
                                Text(labelText(tpl.groupLabel))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { vm.delete(id: tpl.id) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button("Rename") {
                            renameId = tpl.id
                            renameDraft = tpl.name
                            showRenameDialog = true
                        }

                        Button("Duplicate") {
                            vm.duplicate(id: tpl.id)
                        }
                    }
                }
            }
        }
        .navigationTitle("Templates")
        .onAppear { vm.load() }
        .alert("Rename template", isPresented: $showRenameDialog) {
            TextField("Name", text: $renameDraft)

            Button("Save") {
                guard let id = renameId else { return }
                let name = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                vm.rename(id: id, newName: name)
                renameId = nil
                renameDraft = ""
            }

            Button("Cancel", role: .cancel) {
                renameId = nil
                renameDraft = ""
            }
        }
    }

    private func labelText(_ groupLabel: String?) -> String {
        switch (groupLabel ?? "").lowercased() {
        case "superset": return "Superset"
        case "hiit":     return "HIIT"
        default:         return "Exercise"
        }
    }
}
