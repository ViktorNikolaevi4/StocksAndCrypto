import SwiftUI

/// Одна строка списка котировок c мини-графиком (sparkline).
struct QuoteRow: View {
    @ObservedObject var vm: QuotesViewModel
    let q: SimpleQuote

    // Настраиваемая ширина графика и отступы
    private let sparklineWidth: CGFloat = 120     // подберите 90…140
    private let gutter: CGFloat = 8               // отступы слева/справа от графика

    var body: some View {
        VStack(spacing: 4) {

            // Верхняя строка: • тикер — [SPARKLINE фикс. ширины] — цена (справа)
            HStack(spacing: 10) {
                Circle()
                    .frame(width: 8, height: 8)
                    .foregroundStyle(q.changeIsPositive ? .green : .red)

                Text(q.symbol)
                    .font(.headline.monospaced())

                // Разводим контент: символ слева, цена справа
                Spacer(minLength: gutter)

                // Узкий спарклайн фиксированной ширины
                SparklineRemote(symbol: q.symbol, vm: vm)
                    .frame(width: sparklineWidth, height: 18)

                Spacer(minLength: gutter)

                Text(q.price)
                    .font(.headline.monospaced())
                    .layoutPriority(1) // не даём цене сжиматься
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

