import SwiftUI

@MainActor
final class QuotesViewModel: ObservableObject {
    @AppStorage("financeApiKey") var apiKey: String = ""
    @AppStorage("financeSymbols") var symbolsCSV: String = "AAPL,MSFT,TSLA,BTC-USD,ETH-USD"
    @AppStorage("financeServer") var serverRaw: String = FinanceQueryClient.Server.render.rawValue
    @AppStorage("refreshSeconds") var refreshSeconds: Double = 15

    @Published var quotes: [SimpleQuote] = []
    @Published var isLoading = false
    @Published var lastError: String?
    @Published var selectedSymbol: String? 

    private var client: FinanceQueryClient {
        FinanceQueryClient(baseURL: URL(string: serverRaw)!, apiKey: apiKey)
    }

    var symbols: [String] {
        symbolsCSV
            .split(separator: ",")
            .map { SymbolNormalizer.normalize(String($0)) }
            .filter { !$0.isEmpty }
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        lastError = nil
        do {
            let result = try await client.simpleQuotes(symbols: symbols)
            self.quotes = result
        } catch {
            self.lastError = (error as NSError).userInfo["body"] as? String ?? error.localizedDescription
        }
        isLoading = false
    }

    func startAutoRefresh() {
        Task.detached { [weak self] in
            while true {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: UInt64((self?.refreshSeconds ?? 15) * 1_000_000_000))
            }
        }
    }
}
