import SwiftUI

struct SparklineRemote: View {
    let symbol: String
    @ObservedObject var vm: QuotesViewModel
    var colorOverride: Color? = nil
    var risingOverride: Bool? = nil

    @State private var points: [Double] = []
    @State private var isLoading = false

    var body: some View {
        SparklineView(
            data: points,
            risingOverride: risingOverride,
            colorOverride: colorOverride
        )
        .task(id: symbol) { await load() }
        .onReceive(vm.$refreshTick) { _ in Task { await load() } }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let client = FinanceQueryClient(baseURL: URL(string: vm.serverRaw)!, apiKey: vm.apiKey)
            let isCrypto  = SymbolNormalizer.isCrypto(symbol: symbol)
            let range     = isCrypto ? "5d"  : "1mo"
            let interval  = isCrypto ? "1h"  : "1d"
            let closes    = try await client.historicalCloses(symbol: symbol, range: range, interval: interval)

            await MainActor.run {
                points = Array(closes.suffix(50)) // последние 50
            }
        } catch {
            await MainActor.run { points = [] }
        }
    }
}
