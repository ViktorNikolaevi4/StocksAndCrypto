import Foundation

struct SimpleQuote: Codable, Identifiable {
    let symbol: String
    let name: String
    let price: String
    let change: String
    let percentChange: String
    let logo: String?

    var id: String { symbol }

    var priceValue: Double? { Double(price.replacingOccurrences(of: ",", with: "")) }
    var changeIsPositive: Bool {
        change.trimmingCharacters(in: .whitespaces).hasPrefix("+")
    }
}
