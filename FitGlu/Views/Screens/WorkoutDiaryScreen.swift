import SwiftUI

struct WorkoutDiaryScreen: View {

    @StateObject private var vm = WorkoutDiaryViewModel()

    @State private var showAddSheet = false

    // Block type
    @State private var blockType: WorkoutBlockType = .single

    // Edit set
    @State private var editingSet: WorkoutDiarySet? = nil
    @State private var editWeight: String = ""
    @State private var editReps: String = ""
    @State private var editNotes: String = ""

    // MARK: - Draft models

    struct SetDraft: Identifiable {
        let id = UUID()
        var weight: String = ""
        var reps: String = ""
        var notes: String = ""
    }

    struct ExerciseDraft: Identifiable {
        let id = UUID()
        var name: String = ""
        var notes: String = ""          // ✅ добавили
        var sets: [SetDraft] = [SetDraft()]
    }
    @State private var drafts: [ExerciseDraft] = [ExerciseDraft()]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {

                DatePicker(
                    "Day",
                    selection: $vm.selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .onChange(of: vm.selectedDate) { _, newValue in
                    vm.load(for: newValue)
                }

                Divider()

                if let training = vm.currentTraining {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(training.type)
                            .font(.headline)

                        Text(formatTrainingTime(training))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if vm.entries.isEmpty {
                    Spacer()
                    Text("No diary entries for this day yet.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    List {
                        ForEach(vm.blocks) { block in
                            DiaryBlockCard(
                                block: block,
                                onEditSet: { set in
                                    editingSet = set
                                    editWeight = set.weight.map { String(format: "%.1f", $0) } ?? ""
                                    editReps   = set.reps.map { String($0) } ?? ""
                                    editNotes  = set.notes ?? ""
                                },
                                onDeleteSet: { set in
                                    vm.deleteSet(id: set.id)
                                },
                                onDeleteBlock: {
                                    vm.deleteBlock(blockId: block.blockId)
                                }
                            )
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    vm.deleteBlock(blockId: block.blockId)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemBackground))
                }
            }
            .padding()
            .navigationTitle("Workout diary")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet, onDismiss: {
                resetDraft()
            }) {
                addExerciseSheet
            }
            .sheet(item: $editingSet) { set in
                editSetSheet(set)
            }
        }
        .onAppear {
            vm.load(for: vm.selectedDate)
        }
    }

    // MARK: - Add Exercise Sheet

    private var addExerciseSheet: some View {
        NavigationStack {
            Form {

                Section("Block type") {
                    Picker("Type", selection: $blockType) {
                        ForEach(WorkoutBlockType.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(blockType.hint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Exercises in this block") {
                    ForEach($drafts, id: \.id) { $exercise in
                        VStack(alignment: .leading, spacing: 12) {

                            TextField("Name", text: $exercise.name)
                            TextField("Notes", text: $exercise.notes, axis: .vertical)
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            ForEach($exercise.sets, id: \.id) { $set in
                                HStack(spacing: 12) {
                                    TextField("kg", text: $set.weight)
                                        .keyboardType(.decimalPad)
                                        .frame(maxWidth: 90)

                                    TextField("reps", text: $set.reps)
                                        .keyboardType(.numberPad)
                                        .frame(maxWidth: 90)

                                    Spacer()

                                    Button(role: .destructive) {
                                        let setId = set.id
                                        DispatchQueue.main.async {
                                            if exercise.sets.count > 1 {
                                                exercise.sets.removeAll { $0.id == setId }
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "minus.circle")
                                    }
                                    .buttonStyle(.borderless)
                                    .disabled(exercise.sets.count <= 1)
                                }
                            }

                            Button {
                                DispatchQueue.main.async {
                                    exercise.sets.append(SetDraft())
                                }
                            } label: {
                                Label("Add set", systemImage: "plus")
                            }
                            .buttonStyle(.borderless)

                            if drafts.count > 1 {
                                Button(role: .destructive) {
                                    let exId = exercise.id
                                    DispatchQueue.main.async {
                                        drafts.removeAll { $0.id == exId }
                                    }
                                } label: {
                                    Label("Remove exercise", systemImage: "trash")
                                }
                                .buttonStyle(.borderless)
                            }

                            Divider().opacity(0.2)
                        }
                    }

                    Button {
                        DispatchQueue.main.async {
                            drafts.append(ExerciseDraft())
                        }
                    } label: {
                        Label("Add exercise to this block", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                    .disabled(blockType != .superset)
                }
            }
            .navigationTitle("Add exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showAddSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveDrafts()
                        showAddSheet = false
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
    }

    // MARK: - Edit Set Sheet

    private func editSetSheet(_ set: WorkoutDiarySet) -> some View {
        NavigationStack {
            Form {
                Section("Set \(set.setIndex)") {
                    TextField("Weight, kg", text: $editWeight)
                        .keyboardType(.decimalPad)

                    TextField("Reps", text: $editReps)
                        .keyboardType(.numberPad)

                    TextField("Notes", text: $editNotes, axis: .vertical)
                        .font(.footnote)
                }
            }
            .navigationTitle("Edit set")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { editingSet = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let weight = Double(editWeight.replacingOccurrences(of: ",", with: "."))
                        let reps = Int(editReps)

                        let notesTrimmed = editNotes.trimmingCharacters(in: .whitespacesAndNewlines)
                        let notesOrNil = notesTrimmed.isEmpty ? nil : notesTrimmed

                        vm.updateSet(
                            id: set.id,
                            reps: reps,
                            weight: weight,
                            notes: notesOrNil
                        )
                        editingSet = nil
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var isSaveDisabled: Bool {
        drafts.allSatisfy {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func resetDraft() {
        blockType = .single
        drafts = [ExerciseDraft()]
    }

    private func saveDrafts() {
        let blockId = UUID().uuidString

        for draft in drafts {
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }

            let weights = draft.sets.map {
                Double($0.weight.replacingOccurrences(of: ",", with: "."))
            }

            let reps = draft.sets.map {
                Int($0.reps)
            }

            let notesTrimmed = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let notes = notesTrimmed.isEmpty ? nil : notesTrimmed

            vm.addSets(
                blockId: blockId,
                exerciseName: name,
                weightsPerSet: weights,
                repsPerSet: reps,
                sets: draft.sets.count,
                blockType: blockType,
                notes: notes
            )
        }
    }

    private func formatTrainingTime(_ t: TrainingRow) -> String {
        let start = Date(timeIntervalSince1970: t.startTime)
        let end   = Date(timeIntervalSince1970: t.endTime)

        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short

        return "\(df.string(from: start)) – \(df.string(from: end))"
    }
}
