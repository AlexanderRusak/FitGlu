//
//  TrainingModels.swift
//  Shared
//
//  Created by (Your Name) on (Date).
//

import Foundation

/// Тип тренировки
public enum TrainingType: String {
    case fatBurning = "FatBurning"
    case cardio = "Cardio"
    case strength = "Strength"
    // добавьте при необходимости
}

/// Структура, описывающая запись тренировки, прочитанную из БД
public struct TrainingRow {
    public let id: Int64
    public let type: String
    public let startTime: Double
    public let endTime: Double
    
    public init(id: Int64, type: String, startTime: Double, endTime: Double) {
        self.id = id
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
    }
}
