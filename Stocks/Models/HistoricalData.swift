import Foundation

struct HistoricalData: Codable {
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let adjClose: Double?
    let volume: Int
}
