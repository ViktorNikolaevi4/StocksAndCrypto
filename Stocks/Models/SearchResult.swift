import Foundation

struct SearchResult: Codable, Identifiable {
    let name: String
    let symbol: String
    let exchange: String
    let type: String
    var id: String { symbol }
}
