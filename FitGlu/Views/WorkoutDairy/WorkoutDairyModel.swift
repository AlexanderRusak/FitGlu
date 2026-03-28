//
//  WorkoutDairyModel.swift
//  FitGlu
//
//  Created by Александр Русак on 30/12/2025.
//

import Foundation


struct WorkoutDiaryBlock: Identifiable {
    let blockId: String
    let groupLabel: String?         // Superset / HIIT / nil
    let exercises: [WorkoutDiaryGroup]

    var id: String { blockId }
}
