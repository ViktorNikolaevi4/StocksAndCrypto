import SwiftUI

/// Одна строка списка котировок без индикаторной точки и без процента.
struct QuoteRow: View {
    @ObservedObject var vm: QuotesViewModel
    let q: SimpleQuote

    private let sparklineWidth: CGFloat = 120
    private let gutter: CGFloat = 8

    var body: some View {
        VStack(spacing: 4) {

            // Верхняя строка: тикер — [SPARKLINE] — цена
            HStack(spacing: 10) {
                // ⬇️ индикатор- кружок удалён
                Text(q.symbol)
                    .font(.headline.monospaced())

                Spacer(minLength: gutter)

                SparklineRemote(
                    symbol: q.symbol,
                    vm: vm,
                    colorOverride: q.changeIsPositive ? .green : .red,
                    risingOverride: q.changeIsPositive
                )
                    .frame(width: sparklineWidth, height: 18)

                Spacer(minLength: gutter)

                Text(q.price)
                    .font(.headline.monospaced())
                    .layoutPriority(1)
            }

            // Нижняя строка: название и ТОЛЬКО изменение (без процента)
            HStack {
                Text(q.name)
                    .lineLimit(1)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                // ⬇️ оставляем только абсолютное изменение; проценты убраны
                Text(q.change)
                    .font(.caption2.monospaced())
                    .foregroundStyle(q.changeIsPositive ? .green : .red)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}


