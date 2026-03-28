//
//  TrainingModels.swift
//  Shared
//
//  Created by (Your Name) on (Date).
//

import Foundation

/// Тип тренировки
public enum TrainingType: String, CaseIterable, Identifiable {
    case fatBurning = "FatBurning"
    case cardio = "Cardio"
    case strength = "Strength"

    public var id: String { self.rawValue }
}

/// Структура, описывающая запись тренировки, прочитанную из БД
public struct TrainingRow {
    public let id: Int64
    public let type: String
    public let startTime: Double
    public let endTime: Double
    public let energyKcal: Double?     // ← NEW (active/total energy)
    
    public init(
        id: Int64,
        type: String,
        startTime: Double,
        endTime: Double,
        energyKcal: Double? = nil
    ) {
        self.id = id
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.energyKcal = energyKcal
    }
}

public struct HeartRateLogRow {
    public let id: Int64          // Уникальный ID записи пульса
    public let trainingID: Int64  // ID тренировки (связь с training_log)
    public let heartRate: Int     // Значение пульса
    public let timestamp: Double  // Время фиксации пульса
    public let isSynced: Bool     // Флаг синхронизации (с телефона)
    
    public init(id: Int64, trainingID: Int64, heartRate: Int, timestamp: Double, isSynced: Bool) {
        self.id = id
        self.trainingID = trainingID
        self.heartRate = heartRate
        self.timestamp = timestamp
        self.isSynced = isSynced
    }
}
