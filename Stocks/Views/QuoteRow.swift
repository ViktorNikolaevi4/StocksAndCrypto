import SwiftUI

/// Одна строка списка котировок c мини-графиком и открытием карточки по нажатию.
struct QuoteRow: View {
    @ObservedObject var vm: QuotesViewModel
    let q: SimpleQuote

    // Настройки компоновки
    private let sparklineWidth: CGFloat = 120   // подберите 90…140
    private let gutter: CGFloat = 8             // отступы вокруг графика

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button {
            vm.selectedSymbol = q.symbol
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "quoteDetail")
        } label: {
            VStack(spacing: 4) {
                // Верхняя строка: индикатор • тикер — [SPARKLINE] — цена
                HStack(spacing: 10) {
                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundStyle(q.changeIsPositive ? .green : .red)

                    Text(q.symbol)
                        .font(.headline.monospaced())

                    Spacer(minLength: gutter)

                    SparklineRemote(
                        symbol: q.symbol,
                        vm: vm,
                        color: q.changeIsPositive ? .green : .red
                    )
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
        .buttonStyle(.plain) // без синей подсветки
    }
}

