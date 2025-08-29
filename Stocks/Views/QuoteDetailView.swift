import SwiftUI

struct QuoteDetailView: View {
    @ObservedObject var vm: QuotesViewModel

    @State private var quote: SimpleQuote?
    @State private var series: [Double] = []
    @State private var isLoading = false

    var body: some View {
        if let symbol = vm.selectedSymbol {
            VStack(spacing: 10) {
                // Заголовок
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(symbol).font(.title3.monospaced()).bold()
                        Text(quote?.name ?? "—").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    let isUp = (quote?.change.trimmingCharacters(in: .whitespaces).hasPrefix("+") ?? false)
                    Text(quote?.percentChange ?? "—")
                        .font(.title3.monospaced())
                        .foregroundStyle(isUp ? .green : .red)
                }

                // Большой график
                SparklineView(
                    data: series,
                    rising: ((series.last ?? 0) >= (series.first ?? 0)),
                    color: .yellow                                   // стиль как на мокапе
                )
                .frame(height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Цена крупно
                HStack {
                    Spacer()
                    Text(quote?.price ?? "—")
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                }

                if isLoading { ProgressView().controlSize(.small) }
            }
            .padding(14)
            .task(id: symbol) { await load(symbol: symbol) }
        } else {
            Text("Тикер не выбран").padding()
        }
    }

    private func load(symbol: String) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let client = FinanceQueryClient(baseURL: URL(string: vm.serverRaw)!, apiKey: vm.apiKey)
            // котировка
            quote = try await client.simpleQuotes(symbols: [symbol]).first
            // история (чуть длиннее для акций, покороче и детальнее для крипты)
            let isCrypto = SymbolNormalizer.isCrypto(symbol: symbol)
            let range = isCrypto ? "1mo" : "3mo"
            let interval = isCrypto ? "1h" : "1d"
            series = try await client.historicalCloses(symbol: symbol, range: range, interval: interval)
        } catch {
            series = []; quote = nil
        }
    }
}
