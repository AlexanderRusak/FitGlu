import Foundation

public enum ChartDataType {
    case glucose
    case heartRate
}

public struct ChartDataPoint: Identifiable {
    public let id = UUID()
    public let type: ChartDataType
    public let timestamp: Double
    public let value: Double
}
