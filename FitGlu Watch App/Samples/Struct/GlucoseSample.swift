import Foundation

protocol GlucoseSample {
    var minGlucose: Double { get set }
    var maxGlucose: Double { get set }
    var updateInterval: TimeInterval { get set }
    var step: Double { get set }
    
    func infiniteGlucoseSequence() -> AnySequence<Double>
}

struct GlucoseRangeSample: GlucoseSample {
    var minGlucose: Double
    var maxGlucose: Double
    var updateInterval: TimeInterval
    var step: Double
    
    init(
        minGlucose: Double,
        maxGlucose: Double,
        updateInterval: TimeInterval = 10.0,
        step: Double = 0.5
    ) {
        self.minGlucose = minGlucose
        self.maxGlucose = maxGlucose
        self.updateInterval = updateInterval
        self.step = step
    }
    
    func infiniteGlucoseSequence() -> AnySequence<Double> {
        var current = minGlucose
        var goingUp = true
        
        return AnySequence {
            AnyIterator {
                let value = current
                if goingUp {
                    current += step
                    if current >= maxGlucose {
                        current = maxGlucose
                        goingUp = false
                    }
                } else {
                    current -= step
                    if current <= minGlucose {
                        current = minGlucose
                        goingUp = true
                    }
                }
                return value
            }
        }
    }
}
