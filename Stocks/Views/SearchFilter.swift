import SwiftUI

enum SearchFilter: String, CaseIterable, Identifiable {
    case all = "Все", crypto = "Крипто", equities = "Акции/ETF"
    var id: String { rawValue }
}

struct AddSymbolSheet: View {
    @ObservedObject var vm: QuotesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var filter: SearchFilter = .all

    private let quickCrypto = ["BTC","ETH","SOL","BNB","XRP","ADA"]

    var body: some View {
        VStack(spacing: 10) {
            // Быстрая панель популярных монет
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickCrypto, id: \.self) { sym in
                        Button(sym) { add(symbol: sym) }
                            .buttonStyle(.bordered)
                    }
                }
                .padding(.bottom, 4)
            }

            HStack {
                TextField("Название или тикер…", text: $query)
                    .textFieldStyle(.roundedBorder)
                Button("Найти") { Task { await search() } }
                    .keyboardShortcut(.return)
            }

            Picker("Фильтр", selection: $filter) {
                ForEach(SearchFilter.allCases) { f in Text(f.rawValue).tag(f) }
            }
            .pickerStyle(.segmented)

            if isLoading { ProgressView().padding(.vertical, 6) }
            if let e = errorText { Text(e).foregroundStyle(.red).font(.caption) }

            List(filtered(results)) { r in
                Button { add(symbol: r.symbol) } label: {
                    HStack {
                        Text(r.symbol).bold().monospaced()
                        Text(r.name).foregroundStyle(.secondary)
                        Spacer()
                        Text(r.exchange).foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 220)

            HStack {
                Spacer()
                Button("Закрыть") { dismiss() }
            }
        }
        .padding(16)
        .frame(width: 560, height: 400)
    }

    private func filtered(_ items: [SearchResult]) -> [SearchResult] {
        switch filter {
        case .all: return items
        case .crypto:
            return items.filter { item in
                let ex = item.exchange.uppercased()
                return item.symbol.uppercased().contains("-USD") || ex.contains("CRYPTO") || ex.contains("CCC")
            }
        case .equities:
            return items.filter { item in
                let ex = item.exchange.uppercased()
                return !(item.symbol.uppercased().contains("-USD") || ex.contains("CRYPTO") || ex.contains("CCC"))
            }
        }
    }

    private func add(symbol: String) {
        let normalized = SymbolNormalizer.normalize(symbol)
        var set = Set(vm.symbols.map { $0.uppercased() })
        set.insert(normalized.uppercased())
        vm.symbolsCSV = set.sorted().joined(separator: ",")
        Task { await vm.refresh() }
    }

    private func search() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        isLoading = true; errorText = nil
        defer { isLoading = false }
        do {
            let client = FinanceQueryClient(baseURL: URL(string: vm.serverRaw)!, apiKey: vm.apiKey)
            results = try await client.searchSymbols(query: q, hits: 20, yahoo: true)
        } catch {
            errorText = error.localizedDescription
        }
    }
}
