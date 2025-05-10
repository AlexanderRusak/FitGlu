import Foundation

extension Date {
    /// 00:00 текущего дня, с учётом локали/календаря пользователя
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// 23:59:59.999 того же дня
    var endOfDay: Date {
        guard let dayEnd = Calendar.current.date(byAdding: .day, value: 1,
                                                 to: startOfDay)?
                              .addingTimeInterval(-0.001)
        else { return self }
        return dayEnd
    }
    
}

enum DateUtils {
    static func mediumDay(_ d: Date) -> String {
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("dd MMM yyyy")
        return f.string(from: d)
    }
    static func shortDayString(_ d: Date) -> String {
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("dd MMM")
        return f.string(from: d)
    }
}
