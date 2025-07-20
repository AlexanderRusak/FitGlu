import Foundation

class TrainingsStateDBManager {
    static let shared = TrainingsStateDBManager()
    private let key = "TrainingsState_lastUpdate"
    
    // Получить дату последнего обновления
    func getLastUpdateDate() -> Date? {
        return UserDefaults.standard.object(forKey: key) as? Date
    }
    
    // Сохранить новую дату последнего обновления
    func saveLastUpdateDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: key)
    }
}
