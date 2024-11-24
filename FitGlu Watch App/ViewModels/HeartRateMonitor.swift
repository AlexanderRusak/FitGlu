import Foundation
import HealthKit
import WatchKit
import WatchConnectivity

class HeartRateMonitor: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private(set) var cachedAge: Int?
    @Published var heartRate: Double = 0.0
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    func sendHeartRateToPhone(_ heartRate: Double, trainingType: String) {
        guard WCSession.default.isReachable else {
            print("Телефон недоступен для связи")
            return
        }

        let message: [String: Any] = [
            "heartRate": heartRate,
            "trainingType": trainingType
        ]

        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Ошибка отправки сообщения: \(error.localizedDescription)")
        }
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

    func startWorkoutSession(trainingType: String) {
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
            
            sendHeartRateToPhone(heartRate, trainingType: trainingType)
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
    
    private func fetchHeartRate() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return
        }

        let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, _, error in
            if let error = error {
                print("Ошибка ObserverQuery: \(error.localizedDescription)")
                return
            }
            self?.fetchLatestHeartRate()
        }
        
        healthStore.execute(query)
    }

    private func fetchLatestHeartRate() {
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
                    self.sendHeartRateToPhone(self.heartRate, trainingType: "Your Training Type") // Example
                }
            }
        }
    }
}

extension HeartRateMonitor: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
}
