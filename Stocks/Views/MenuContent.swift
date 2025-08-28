import SwiftUI
import AppKit

struct MenuContent: View {
    @ObservedObject var vm: QuotesViewModel
    @Environment(\.openWindow) private var openWindow
    @State private var showAdd = false

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
                ForEach(vm.quotes) { q in
                    QuoteRow(q: q)
                    Divider()
                }
            }

            Button("＋ Добавить тикер…") { showAdd = true }
                .sheet(isPresented: $showAdd) { AddSymbolSheet(vm: vm) }
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
        .frame(minWidth: 300)
    }
}
