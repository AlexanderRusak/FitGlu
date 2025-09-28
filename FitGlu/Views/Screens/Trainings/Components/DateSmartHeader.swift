import SwiftUI

/// Режим выбора дат
enum DatePickMode: String, CaseIterable {
    case single = "Day"
    case range  = "Range"
}

/// Пресеты интервалов
enum DatePreset: String, CaseIterable {
    case week     = "7d"
    case twoWeeks = "14d"
    case month    = "30d"

    var days: Int {
        switch self {
        case .week: return 7
        case .twoWeeks: return 14
        case .month: return 30
        }
    }
}

/// Заголовок с календарём: одиночный день + диапазоны + пресеты
struct DateSmartHeader: View {
    // базовый «день» (обязательно)
    @Binding var selectedDate: Date

    // диапазон (опционально, если supportsRange=true)
    @Binding var rangeStart: Date?
    @Binding var rangeEnd: Date?

    // конфиг
    var supportsRange: Bool = true
    var titleIcon: String = "calendar"

    @State private var showSheet = false
    @State private var mode: DatePickMode = .single

    var body: some View {
        HStack {
            Button {
                showSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: titleIcon)
                    Text(headerLabel)
                        .font(.headline)
                }
            }
            Spacer()
        }
        .padding([.horizontal, .top])
        .sheet(isPresented: $showSheet) {
            CalendarSheet(
                selectedDate: $selectedDate,
                rangeStart: $rangeStart,
                rangeEnd: $rangeEnd,
                mode: $mode,
                supportsRange: supportsRange
            ) {
                showSheet = false
            }
        }
    }

    private var headerLabel: String {
        if supportsRange, let s = rangeStart, let e = rangeEnd, mode == .range {
            let f = Date.FormatStyle().day().month(.abbreviated).year()
            return "\(s.formatted(f)) – \(e.formatted(f))"
        } else {
            return selectedDate.formatted(.dateTime.day().month().year())
        }
    }
}

// MARK: - Sheet

private struct CalendarSheet: View {
    @Binding var selectedDate: Date
    @Binding var rangeStart: Date?
    @Binding var rangeEnd: Date?
    @Binding var mode: DatePickMode

    let supportsRange: Bool
    let onClose: () -> Void

    // локальные «черновики», чтобы Apply отменял/подтверждал разом
    @State private var draftDate: Date = Date()
    @State private var draftStart: Date = Date().startOfDay
    @State private var draftEnd: Date = Date().endOfDay

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {

                if supportsRange {
                    Picker("Mode", selection: $mode) {
                        ForEach(DatePickMode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
#if !os(watchOS)
                    .pickerStyle(.segmented)
#endif
                    .padding(.horizontal)
                }

                if mode == .single || !supportsRange {
                    // SINGLE
                    DatePicker(
                        "",
                        selection: $draftDate,
                        displayedComponents: .date
                    )
#if !os(watchOS)
                    .datePickerStyle(.graphical)
#endif
                    .tint(.accentColor)
                    .padding(.horizontal)
                    .onAppear { draftDate = selectedDate }
                } else {
                    // RANGE
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Range").font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                            // Быстрые пресеты
                            PresetsBar { preset in
                                draftEnd = selectedDate.endOfDay
                                draftStart = Calendar.current.date(byAdding: .day, value: -preset.days + 1, to: draftEnd.startOfDay) ?? draftEnd.startOfDay
                            }
                        }

                        DatePicker("Start", selection: $draftStart, displayedComponents: .date)
                        DatePicker("End",   selection: $draftEnd,   displayedComponents: .date)
                    }
                    .padding(.horizontal)
                    .onAppear {
                        draftStart = (rangeStart ?? selectedDate.startOfDay)
                        draftEnd   = (rangeEnd   ?? selectedDate.endOfDay)
                        normalizeRange()
                    }
                    .onChange(of: draftStart) { _, _ in normalizeRange() }
                    .onChange(of: draftEnd) { _, _ in normalizeRange() }
                }

                Spacer(minLength: 0)
            }
            .navigationTitle(mode == .range && supportsRange ? "Select Range" : "Select Day")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onClose() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        if mode == .range && supportsRange {
                            // фиксим края диапазона по суткам
                            rangeStart = draftStart.startOfDay
                            rangeEnd   = draftEnd.endOfDay
                            // базовую дату подвинем на конец диапазона (удобно для графиков)
                            selectedDate = draftEnd
                        } else {
                            selectedDate = draftDate
                            // на всякий — обнулим диапазон, если выходим из range
                            if supportsRange {
                                rangeStart = nil
                                rangeEnd = nil
                            }
                        }
                        onClose()
                    }
                }
            }
        }
    }

    private func normalizeRange() {
        if draftEnd < draftStart {
            draftEnd = draftStart
        }
        // ограничим диапазон разумно (например, до 180 дней), чтобы не улетать
        if let lim = Calendar.current.date(byAdding: .day, value: 180, to: draftStart),
           draftEnd > lim {
            draftEnd = lim
        }
    }
}

// MARK: – Presets Bar

private struct PresetsBar: View {
    var onPick: (DatePreset) -> Void
    @State private var selected: DatePreset? = nil

    var body: some View {
        HStack(spacing: 8) {
            ForEach(DatePreset.allCases, id: \.self) { p in
                Button {
                    selected = p
                    onPick(p)
                } label: {
                    Text(p.rawValue)
                        .font(.caption)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(selected == p ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
    }
}
