import SwiftUI

struct ActivityScreen: View {
    @State private var selectedDate = Date()
    @State private var showPicker    = false

    @StateObject private var detailsVM = DetailsViewModel()
    @StateObject private var chartVM   = ActivityChartViewModel()

    var body: some View {
        VStack(spacing: 12) {
            // MARK: — Header + date picker
            HStack {
                Text(selectedDate, format: .dateTime.day().month().year())
                    .font(.headline)
                Spacer()
                Button {
                    showPicker.toggle()
                } label: {
                    Image(systemName: "calendar")
                        .font(.title2)
                }
            }

            if showPicker {
                DatePicker(
                    "Выберите дату",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                // вместо deprecated onChange(of:perform:)
                .onChange(of: selectedDate) { old, new in
                    Task { await loadData() }
                }
            }

            Divider()

            // MARK: — Chart or placeholder
            if detailsVM.trainings.isEmpty && detailsVM.hrDailyPoints.isEmpty {
                Text("Нет данных за выбранную дату")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                ActivityChartView(vm: chartVM)
                    .frame(height: 320)
            }
        }
        .padding()
        .navigationTitle("Activity")
        // initial load + re–load on date change
        .task(id: selectedDate) {
            await loadData()
        }
    }

    // MARK: — helper
    @MainActor
    private func loadData() async {
        await detailsVM.load(for: selectedDate)
        await chartVM.configure(from: detailsVM)
    }
}
