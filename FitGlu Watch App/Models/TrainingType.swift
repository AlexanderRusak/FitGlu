//
//  TrainingType.swift
//  FitGlu Watch App
//
//  Created by Александр Русак on 30/11/2024.
//

import Foundation

enum TrainingType: String, CaseIterable {
    case fatBurning = "Fat Burning"
    case cardio = "Cardio"
    case highIntensity = "High Intensity"
    case strength = "Strength"

    var description: String {
        switch self {
        case .fatBurning:
            return "Low-intensity workout focused on maximizing fat oxidation during aerobic activity."
        case .cardio:
            return "Moderate-intensity aerobic workout designed to enhance cardiovascular health and improve endurance."
        case .highIntensity:
            return "High-intensity interval workout aimed at improving anaerobic capacity, power, and stamina."
        case .strength:
            return "Resistance-based training focused on building muscle hypertrophy, strength, and power."
        }
    }
}
