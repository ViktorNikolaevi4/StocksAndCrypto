import SwiftUI
import AppKit

struct MenuContent: View {
    @ObservedObject var vm: QuotesViewModel
    @Environment(\.openWindow) private var openWindow
//    @State private var showAdd = false

    private let rowHeight: CGFloat = 52
    private let visibleRows: CGFloat = 7

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Мой список").font(.headline)
                Spacer()
                Button { Task { await vm.refresh() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Обновить сейчас")
            }
            .padding(.bottom, 2)

            if vm.isLoading && vm.quotes.isEmpty {
                ProgressView().frame(maxWidth: .infinity, alignment: .center)
            } else if let err = vm.lastError, vm.quotes.isEmpty {
                Text(err).foregroundStyle(.red).font(.caption).padding(.vertical, 6)
            } else {
                // скроллируемый список с видимыми 7 строками
                let rows = min(CGFloat(vm.quotes.count), visibleRows)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.quotes) { q in
                            Button {
                                vm.selectedSymbol = q.symbol
                                NSApp.activate(ignoringOtherApps: true)
                                openWindow(id: "quoteDetail")
                            } label: {
                                QuoteRow(vm: vm, q: q)
                                    .frame(height: rowHeight)
                            }
                            .buttonStyle(.plain)   // без синих подсветок
                            Divider()
                        }

                    }
                }
                .frame(height: rows * rowHeight)        // ограничиваем высоту
                .scrollIndicators(.automatic)
            }

            Button("＋ Добавить тикер…") {
                NSApp.activate(ignoringOtherApps: true)   // вытащить окно на передний план
                openWindow(id: "addSymbol")               // открыть отдельное окно
            }
            .buttonStyle(.borderless)
            .padding(.top, 4)

            HStack {
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "settings")
                } label: {
                    Label("⚙︎ Настройки…", systemImage: "gearshape")
                }

                Spacer()
                Text("обновление: \(Int(vm.refreshSeconds))s")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .padding(12)
        .frame(minWidth: 400)
    }
}
