import SwiftUI
import AppKit

/// Детальная карточка тикера: слева сверху тикер+имя, справа проценты,
/// ниже мини-график и крупная цена. Данные живут, пока окно открыто.
struct QuoteDetailView: View {
    @ObservedObject var vm: QuotesViewModel

    // только серия для графика и служебные флаги
    @State private var series: [Double] = []
    @State private var isLoading = false
    @State private var lastSeriesUpdate = Date.distantPast

    // «держать поверх всех»
    @AppStorage("quoteDetailAlwaysOnTop") private var alwaysOnTop = false

    /// Текущая «живая» котировка для выбранного тикера из общего списка vm.quotes
    private var liveQuote: SimpleQuote? {
        guard let s = vm.selectedSymbol else { return nil }
        return vm.quotes.first { $0.symbol.uppercased() == s.uppercased() }
    }

    var body: some View {
        content
            .padding(14)
            // Кнопка-пин в заголовок окна (не перекрывает контент)
            .background(TitlebarPinAccessory(isPinned: $alwaysOnTop))
            // первый заход/смена тикера — грузим серию
            .task(id: vm.selectedSymbol) {
                if let s = vm.selectedSymbol { await loadSeries(for: s, force: true) }
            }
            // каждое обновление общего списка котировок — освежаем график редко,
            // а цена/процент обновятся сами через liveQuote
            .onReceive(vm.$refreshTick) { _ in
                guard let s = vm.selectedSymbol else { return }
                let isCrypto = SymbolNormalizer.isCrypto(symbol: s)
                let minGap: TimeInterval = isCrypto ? 60 : 300   // 1 мин для крипты, 5 мин для акций
                if Date().timeIntervalSince(lastSeriesUpdate) > minGap {
                    Task { await loadSeries(for: s) }
                }
            }
    }

    @ViewBuilder private var content: some View {
        if let s = vm.selectedSymbol {
            let q = liveQuote
            let isUp = q?.changeIsPositive ?? false   // ← готовый флаг

            VStack(spacing: 10) {
                // Верхняя строка
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s).font(.title3.monospaced()).bold()
                        Text(q?.name ?? "—")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(q?.percentChange ?? "—")
                        .font(.title3.monospaced())
                        .foregroundStyle(isUp ? .green : .red)
                }

                // График
                SparklineView(
                    data: series,
                    rising: (series.last ?? 0) >= (series.first ?? 0),
                    colorOverride: isUp ? .green : .red
                )
                .frame(height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Крупная цена
                HStack {
                    Spacer()
                    Text(q?.price ?? "—")
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                }

                if isLoading { ProgressView().controlSize(.small) }
            }
        } else {
            Text("Тикер не выбран").padding()
        }
    }


    // Грузим только исторические закрытия для графика
    private func loadSeries(for symbol: String, force: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true; defer { isLoading = false }
        do {
            let client = FinanceQueryClient(baseURL: URL(string: vm.serverRaw)!, apiKey: vm.apiKey)
            let isCrypto = SymbolNormalizer.isCrypto(symbol: symbol)
            let range = isCrypto ? "1mo" : "3mo"
            let interval = isCrypto ? "1h" : "1d"
            let values = try await client.historicalCloses(symbol: symbol, range: range, interval: interval)
            self.series = Array(values.suffix(120))
            self.lastSeriesUpdate = Date()
        } catch {
            // оставляем прошлую серию; можно показать ошибку при желании
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


