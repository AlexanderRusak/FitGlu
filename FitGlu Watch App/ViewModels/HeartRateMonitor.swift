import Foundation
import HealthKit
import WatchKit

class HeartRateMonitor: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var heartRateQuery: HKObserverQuery? // Ссылка на текущий запрос
    private(set) var cachedAge: Int?
    @Published var heartRate: Double = 0.0
    private var isWorkoutActive = false // Флаг активности тренировки

    override init() {
        super.init()
    }

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit недоступен")
            return
        }
        
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let typesToRead: Set<HKObjectType> = [heartRateType]
        let typesToShare: Set<HKSampleType> = []

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if success {
                print("Авторизация HealthKit успешна")
            } else {
                print("Ошибка авторизации HealthKit: \(String(describing: error))")
            }
        }
    }

    func startWorkoutSession() {
        guard HKHealthStore.isHealthDataAvailable() else {
            return
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .indoor

        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()

            builder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            session?.delegate = self
            builder?.delegate = self

            session?.startActivity(with: Date())
            builder?.beginCollection(withStart: Date()) { success, error in
                if let error = error {
                    print("Error starting data collection: \(error.localizedDescription)")
                }
            }

            // Установить флаг активности и начать мониторинг пульса
            isWorkoutActive = true
            startHeartRateMonitoring()

            WKInterfaceDevice.current().play(.start)
        } catch {
            print("Error starting workout session: \(error.localizedDescription)")
        }
    }

    func stopWorkoutSession() {
        session?.end()
        builder?.endCollection(withEnd: Date()) { success, error in
            if let error = error {
                print("Ошибка завершения сбора данных: \(error.localizedDescription)")
            }
        }

        // Убрать флаг активности и завершить мониторинг пульса
        isWorkoutActive = false
        stopHeartRateMonitoring()

        WKInterfaceDevice.current().play(.stop)
    }

    func fetchAge() {
        do {
            let birthDate = try healthStore.dateOfBirthComponents().date
            let ageComponents = Calendar.current.dateComponents([.year], from: birthDate ?? Date(), to: Date())
            cachedAge = ageComponents.year
            print("User's age fetched and cached: \(cachedAge ?? 0)")
        } catch {
            print("Ошибка получения возраста: \(error.localizedDescription)")
        }
    }

    func getAge() -> Int? {
        return cachedAge
    }

    private func startHeartRateMonitoring() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return
        }

        heartRateQuery = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, _, error in
            if let error = error {
                print("Ошибка ObserverQuery: \(error.localizedDescription)")
                return
            }
            self?.fetchLatestHeartRate()
        }
        
        healthStore.execute(heartRateQuery!)
    }

    private func stopHeartRateMonitoring() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
            print("Heart rate monitoring stopped.")
        }
    }

    private func fetchLatestHeartRate() {
        guard isWorkoutActive else { return } // Проверяем, активна ли тренировка
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return
        }

        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { [weak self] _, samples, error in
            if let error = error {
                print("Ошибка SampleQuery: \(error.localizedDescription)")
                return
            }

            guard let sample = samples?.first as? HKQuantitySample else { return }
            let heartRate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))

            DispatchQueue.main.async {
                self?.heartRate = heartRate
            }
        }

        healthStore.execute(query)
    }
}

extension HeartRateMonitor: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        if toState == .ended {
            print("Тренировка завершена")
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Ошибка в тренировке: \(error.localizedDescription)")
    }
}

extension HeartRateMonitor: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Обработка событий, если нужно
    }

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return
        }

        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType, quantityType == heartRateType else {
                continue
            }

            if let statistics = builder?.statistics(for: heartRateType) {
                let heartRateUnit = HKUnit(from: "count/min")
                let value = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit)

                DispatchQueue.main.async {
                    self.heartRate = value ?? 0.0
                }
            }
        }
    }
}
