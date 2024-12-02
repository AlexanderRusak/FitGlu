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

    var description: String {
        switch self {
        case .fatBurning: return "Low-intensity workout for fat burning."
        case .cardio: return "Moderate-intensity workout to improve endurance."
        case .highIntensity: return "High-intensity workout for strength and stamina."
        }
    }
}
