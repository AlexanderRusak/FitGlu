//
//  WorkoutManager.swift
//  FitGlu Watch App
//
//  Created by Александр Русак on 02/12/2024.
//

import Foundation
import HealthKit

class WorkoutManager: NSObject {
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    func startWorkoutSession(completion: @escaping (Error?) -> Void) {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .indoor

        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()

            session?.delegate = self
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

            session?.startActivity(with: Date())
            builder?.beginCollection(withStart: Date()) { success, error in
                completion(error)
            }
        } catch {
            completion(error)
        }
    }

    func stopWorkoutSession(completion: @escaping (Error?) -> Void) {
        session?.end()
        builder?.endCollection(withEnd: Date()) { success, error in
            completion(error)
        }
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        if toState == .ended {
            print("Тренировка завершена")
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Ошибка в тренировке: \(error.localizedDescription)")
    }
}

