//
//   LocalDBProvider.swift
//  FitGlu
//
//  Created by Александр Русак on 03/05/2025.
//

import Foundation

struct LocalDBProvider {

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
}
