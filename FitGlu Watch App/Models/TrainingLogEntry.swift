//
//  TrainingLogEntry.swift
//  FitGlu Watch App
//
//  Created by Александр Русак on 04/01/2025.
//

import Foundation

struct TrainingLogEntry: Identifiable {
    let id: Int64          // ID из SQLite (PRIMARY KEY)
    let trainingType: TrainingType
    let startDate: Date
    let endDate: Date?

    /// Инициализатор для создания новой записи (id = 0, т.к. автоинкремент)
    init(id: Int64 = 0, trainingType: TrainingType, startDate: Date, endDate: Date? = nil) {
        self.id = id
        self.trainingType = trainingType
        self.startDate = startDate
        self.endDate = endDate
    }
}
