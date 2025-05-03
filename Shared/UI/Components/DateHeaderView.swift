import SwiftUI

struct DateHeaderView: View {
    @Binding var date: Date
    @Binding var showPicker: Bool

    var body: some View {
        HStack {
            Button {
                showPicker = true
            } label: {
                Label(date.formatted(.dateTime.day().month().year()),
                      systemImage: "calendar")
                    .font(.headline)
            }
            Spacer()
        }
        .padding([.horizontal, .top])
        .sheet(isPresented: $showPicker) {
            CalendarSheet(date: $date, isPresented: $showPicker)
        }
    }

    /// Простой календарь‑sheet
    private struct CalendarSheet: View {
        @Binding var date: Date
        @Binding var isPresented: Bool

        var body: some View {
            NavigationStack {
                VStack {
                    DatePicker("", selection: $date, displayedComponents: [.date])
#if !os(watchOS)
                        .datePickerStyle(.graphical)
#endif
                        .tint(.accentColor)
                        .padding()
                    Spacer()
                }
                .navigationTitle("Select Day")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Apply") { isPresented = false }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isPresented = false }
                    }
                }
            }
        }
    }
}
