import Foundation

struct LocalDBProvider {
    private let settingsKey = "fitglu.userSettings.v1"

    func trainings(from start: Date, to end: Date) -> [TrainingRow] {
        TrainingLogDBManager.shared
            .getAllTrainings()
            .filter {
                let ts = Date(timeIntervalSince1970: $0.startTime)
                return ts >= start && ts < end
            }
    }

    func heartRates(for trainings: [TrainingRow]) -> [HeartRateLogRow] {
        trainings.flatMap { HeartRateLogDBManager.shared.getHeartRates(for: $0.id) }
    }

    func glucose(from start: Date, to end: Date) -> [GlucoseRow] {
        GlucoseLogDBManager.shared
            .getAllGlucose()
            .filter {
                let ts = Date(timeIntervalSince1970: $0.timestamp)
                return ts >= start && ts < end
            }
    }

    func loadUserSettings() -> UserSettings {
        guard
            let data = UserDefaults.standard.data(forKey: settingsKey),
            let decoded = try? JSONDecoder().decode(UserSettings.self, from: data)
        else {
            return .default
        }
        return decoded
    }

    func saveUserSettings(_ settings: UserSettings) {
        var value = settings
        value.updatedAt = .now
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: settingsKey)
    }
}
