import SwiftUI

/// Одна строка списка котировок c мини-графиком (sparkline).
struct QuoteRow: View {
    @ObservedObject var vm: QuotesViewModel
    let q: SimpleQuote

    var body: some View {
        VStack(spacing: 4) {
            // Верхняя строка: индикатор • тикер — SPARKLINE — цена
            HStack(spacing: 10) {
                Circle()
                    .frame(width: 8, height: 8)
                    .foregroundStyle(q.changeIsPositive ? .green : .red)

                Text(q.symbol)
                    .font(.headline.monospaced())

                // Мини-график между тикером и ценой
                SparklineRemote(symbol: q.symbol, vm: vm)
                    .frame(height: 18)
                    .frame(maxWidth: .infinity)

                Text(q.price)
                    .font(.headline.monospaced())
            }

            // Нижняя строка: название и изменение
            HStack {
                Text(q.name)
                    .lineLimit(1)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(q.change + "  " + q.percentChange)
                    .font(.caption2.monospaced())
                    .foregroundStyle(q.changeIsPositive ? .green : .red)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
