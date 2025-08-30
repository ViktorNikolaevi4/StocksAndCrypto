import SwiftUI

struct SparklineRemote: View {
    let symbol: String
    @ObservedObject var vm: QuotesViewModel
    var color: Color? = nil

    @State private var series: [Double] = []
    @State private var isLoading = false

    var body: some View {
        SparklineView(
            data: series,
            rising: (series.last ?? 0) >= (series.first ?? 0),
            colorOverride: color          // ← было: color
        )
        .onAppear { Task { await load() } }
        .onChange(of: vm.serverRaw) { _ in Task { await load() } }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let client = FinanceQueryClient(baseURL: URL(string: vm.serverRaw)!, apiKey: vm.apiKey)
            // Для крипты покажем более «живую» линию (5d/1h), для акций — 1mo/1d
            let isCrypto = SymbolNormalizer.isCrypto(symbol: symbol)
            let range = isCrypto ? "5d" : "1mo"
            let interval = isCrypto ? "1h" : "1d"
            let closes = try await client.historicalCloses(symbol: symbol, range: range, interval: interval)

            // берём последние 50 точек максимум
            series = Array(closes.suffix(50))
        } catch {
            series = [] // тихо не рисуем
        }
    }
}
