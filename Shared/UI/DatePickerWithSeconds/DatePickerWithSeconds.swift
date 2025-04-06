import SwiftUI

/// Кастомный DatePicker с возможностью выбора часов, минут и секунд.
struct DatePickerWithSeconds: View {
    @Binding var date: Date
    private let calendar = Calendar.current
    
    var body: some View {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)
        
        VStack(alignment: .leading, spacing: 12) {
            DatePicker("Выберите дату", selection: $date, displayedComponents: .date)
                    #if !os(watchOS)
                        .datePickerStyle(CompactDatePickerStyle())
                    #else
                        .datePickerStyle(WheelDatePickerStyle())
                    #endif
            
            HStack(spacing: 24) {
                VStack {
                    Text("Часы")
                        .font(.caption)
                    Picker("", selection: Binding(
                        get: { hour },
                        set: { newHour in
                            updateDate(year: year, month: month, day: day,
                                       hour: newHour, minute: minute, second: second)
                        }
                    )) {
                        ForEach(0..<24, id: \.self) { h in
                            Text("\(h)").tag(h)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: 50, height: 80)
                    .clipped()
                }
                
                VStack {
                    Text("Минуты")
                        .font(.caption)
                    Picker("", selection: Binding(
                        get: { minute },
                        set: { newMinute in
                            updateDate(year: year, month: month, day: day,
                                       hour: hour, minute: newMinute, second: second)
                        }
                    )) {
                        ForEach(0..<60, id: \.self) { m in
                            Text("\(m)").tag(m)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: 50, height: 80)
                    .clipped()
                }
                
                VStack {
                    Text("Секунды")
                        .font(.caption)
                    Picker("", selection: Binding(
                        get: { second },
                        set: { newSecond in
                            updateDate(year: year, month: month, day: day,
                                       hour: hour, minute: minute, second: newSecond)
                        }
                    )) {
                        ForEach(0..<60, id: \.self) { s in
                            Text("\(s)").tag(s)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: 50, height: 80)
                    .clipped()
                }
            }
        }
    }
    
    private func updateDate(year: Int, month: Int, day: Int,
                            hour: Int, minute: Int, second: Int) {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        
        if let newDate = calendar.date(from: components) {
            date = newDate
        }
    }
}
