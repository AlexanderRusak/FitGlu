import Foundation

protocol TrainingSample {
    var gender: String { get }
    var age: Int { get }
    var minHeartRate: Int { get }
    var maxHeartRate: Int { get }
    var updateInterval: TimeInterval { get } // время в секундах между обновлениями
    var step: Int { get } // шаг изменения пульса

    func infiniteHeartRateSequence(step: Int) -> AnySequence<(String, Int, Int)>
}

struct Sample: TrainingSample {
    let gender: String
    let age: Int
    let minHeartRate: Int
    let maxHeartRate: Int
    let updateInterval: TimeInterval
    let step: Int

    init(
        gender: String,
        age: Int,
        minHeartRate: Int,
        maxHeartRate: Int,
        updateInterval: TimeInterval = 3.0,
        step: Int = 1
    ) {
        self.gender = gender
        self.age = age
        self.minHeartRate = minHeartRate
        self.maxHeartRate = maxHeartRate
        self.updateInterval = updateInterval
        self.step = step
    }

    func infiniteHeartRateSequence(step: Int) -> AnySequence<(String, Int, Int)> {
        var current = minHeartRate
        var goingUp = true
        return AnySequence {
            AnyIterator {
                let value = current
                if goingUp {
                    current += step
                    if current >= maxHeartRate {
                        current = maxHeartRate
                        goingUp = false
                    }
                } else {
                    current -= step
                    if current <= minHeartRate {
                        current = minHeartRate
                        goingUp = true
                    }
                }
                return (gender, age, value)
            }
        }
    }
}
