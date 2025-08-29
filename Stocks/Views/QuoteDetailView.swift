import SwiftUI
import AppKit

struct QuoteDetailView: View {
    @ObservedObject var vm: QuotesViewModel

    @State private var quote: SimpleQuote?
    @State private var series: [Double] = []
    @State private var isLoading = false

    @AppStorage("quoteDetailAlwaysOnTop") private var alwaysOnTop = false

    var body: some View {
        content
            .padding(14)
            // ⬇️ добавляем пин в заголовок окна
            .background(TitlebarPinAccessory(isPinned: $alwaysOnTop))
    }

    @ViewBuilder private var content: some View {
        if let symbol = vm.selectedSymbol {
            VStack(spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(symbol).font(.title3.monospaced()).bold()
                        Text(quote?.name ?? "—").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    let isUp = quote?.change.trimmingCharacters(in: .whitespaces).hasPrefix("+") ?? false
                    Text(quote?.percentChange ?? "—")
                        .font(.title3.monospaced())
                        .foregroundStyle(isUp ? .green : .red)
                }

                SparklineView(
                    data: series,
                    rising: ((series.last ?? 0) >= (series.first ?? 0)),
                    color: .green
                )
                .frame(height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack {
                    Spacer()
                    Text(quote?.price ?? "—")
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                }

                if isLoading { ProgressView().controlSize(.small) }
            }
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
            quote = try await client.simpleQuotes(symbols: [symbol]).first
            let isCrypto = SymbolNormalizer.isCrypto(symbol: symbol)
            let range = isCrypto ? "1mo" : "3mo"
            let interval = isCrypto ? "1h" : "1d"
            series = try await client.historicalCloses(symbol: symbol, range: range, interval: interval)
        } catch {
            series = []; quote = nil
        }
    }
}


import SwiftUI
import AppKit

/// Кнопка "pin" в title bar окна (справа).
/// Хранит состояние в Binding и сама поднимает/опускает уровень окна.
struct TitlebarPinAccessory: NSViewRepresentable {
    @Binding var isPinned: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        // Ждём, когда view попадёт в окно, и прикручиваем аксессуар
        DispatchQueue.main.async {
            if let win = v.window {
                context.coordinator.attach(to: win)
                context.coordinator.syncWindowLevel()
            }
        }
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Подхватываем возможную смену окна (редко, но корректно)
        DispatchQueue.main.async {
            if let win = nsView.window {
                context.coordinator.attach(to: win)
            }
            context.coordinator.syncWindowLevel()
        }
    }

    // MARK: - Coordinator
    final class Coordinator: NSObject {
        private let parent: TitlebarPinAccessory
        private weak var window: NSWindow?
        private var accessory: NSTitlebarAccessoryViewController?
        private let button = NSButton()

        init(_ parent: TitlebarPinAccessory) {
            self.parent = parent
            super.init()
            configureButton()
        }

        func attach(to window: NSWindow) {
            guard self.window !== window else { return }
            self.window = window

            if accessory == nil {
                let ac = NSTitlebarAccessoryViewController()
                ac.view = button
                ac.layoutAttribute = .right  // справа в title bar
                window.addTitlebarAccessoryViewController(ac)
                accessory = ac
            }
            syncButtonAppearance()
        }

        func syncWindowLevel() {
            guard let w = window else { return }
            w.level = parent.isPinned ? .floating : .normal
            if parent.isPinned {
                w.collectionBehavior.insert([.canJoinAllSpaces, .fullScreenAuxiliary])
            } else {
                w.collectionBehavior.remove([.canJoinAllSpaces, .fullScreenAuxiliary])
            }
            syncButtonAppearance()
        }

        private func configureButton() {
            button.bezelStyle = .texturedRounded
            button.isBordered = true
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(togglePin)
            button.setFrameSize(NSSize(width: 26, height: 26))
            syncButtonAppearance()
        }

        private func syncButtonAppearance() {
            button.image = NSImage(
                systemSymbolName: parent.isPinned ? "pin.fill" : "pin",
                accessibilityDescription: nil
            )
            button.toolTip = parent.isPinned ? "Открепить окно" : "Держать поверх всех"
            button.contentTintColor = parent.isPinned ? .systemYellow : .labelColor
        }

        @objc private func togglePin() {
            parent.isPinned.toggle()
            syncWindowLevel()
        }
    }
}


