import SwiftUI

struct QuoteRow: View {
    let q: SimpleQuote

    var body: some View {
        HStack(spacing: 10) {
            Circle().frame(width: 8, height: 8)
                .foregroundStyle(q.changeIsPositive ? .green : .red)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(q.symbol).font(.headline.monospaced())
                    Spacer()
                    Text(q.price).font(.headline.monospaced())
                }
                HStack(spacing: 6) {
                    Text(q.name).lineLimit(1).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(q.change + "  " + q.percentChange)
                        .font(.caption.monospaced())
                        .foregroundStyle(q.changeIsPositive ? .green : .red)
                }
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}
