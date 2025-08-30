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

            // 1) строим варианты запроса
            let variants = buildSearchQueries(raw: q, filter: filter)

            // 2) шлём запросы ко всем источникам для всех вариантов
            var bucket: [SearchResult] = []
            for v in variants {
                // Yahoo
                bucket += try await client.searchSymbols(query: v, hits: 20, yahoo: true)
                // non-Yahoo (внутренний источник; лучше ловит крипту)
                bucket += try await client.searchSymbols(query: v, hits: 20, yahoo: false)
            }

            // 3) удаляем дубли (по symbol+exchange)
            var seen = Set<String>()
            let deduped = bucket.filter { r in
                let key = r.symbol.uppercased() + "@" + r.exchange.uppercased()
                if seen.contains(key) { return false }
                seen.insert(key); return true
            }

            // 4) показываем в зависимости от фильтра
            switch filter {
            case .all:
                results = deduped
            case .crypto:
                results = deduped.filter { isCryptoResult($0) }
            case .equities:
                results = deduped.filter { !isCryptoResult($0) }
            }

            // 5) фоллбек: ничего не нашли, но это точно токен → подсунем CRYPTO
            if results.isEmpty, let usd = usdVariantIfToken(q) {
                results = [SearchResult(
                    name: prettyName(for: usd),
                    symbol: usd,
                    exchange: "CRYPTO",
                    type: "crypto"
                )]
            }
        } catch {
            errorText = friendlyError(error)
        }
    }

    // === Helpers ===

    /// Построить набор разумных запросов для крипты/акций.
    private func buildSearchQueries(raw: String, filter: SearchFilter) -> [String] {
        var out = Set<String>()
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let upper = trimmed.uppercased()
        out.insert(trimmed)                  // как ввёл пользователь
        out.insert(upper)                    // в верхнем регистре (для тикеров)

        // имя монеты → тикер (на случай "Celestia", "Avalanche" и т.п.)
        if let sym = nameToTicker[upper] {
            out.insert(sym)
            out.insert("\(sym)-USD")
        }

        // если это похоже на токен или фильтр "Крипто" — добавим -USD
        if filter == .crypto || looksLikeToken(upper) {
            if !upper.contains("-") { out.insert("\(upper)-USD") }
        }

        // если уже ввели -USD — добавим также короткий символ
        if upper.hasSuffix("-USD") {
            out.insert(String(upper.dropLast(4)))
        }

        return Array(out)
    }

    /// Признак «похоже на крипто-тикер».
    private func looksLikeToken(_ u: String) -> Bool {
        u.range(of: #"^[A-Z0-9]{2,10}$"#, options: .regularExpression) != nil
    }

    /// Если строка похожа на токен — вернуть его вариант с -USD.
    private func usdVariantIfToken(_ raw: String) -> String? {
        let u = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !u.isEmpty else { return nil }
        if u.hasSuffix("-USD") { return u }
        return looksLikeToken(u) ? "\(u)-USD" : nil
    }

    /// Определение «крипты» для результата поиска.
    private func isCryptoResult(_ r: SearchResult) -> Bool {
        let uSym = r.symbol.uppercased()
        let uEx  = r.exchange.uppercased()
        return uSym.contains("-USD") || uEx.contains("CRYPTO") || uEx.contains("CCC")
    }

    /// Красивое имя для CRYPTO-фоллбека.
    private func prettyName(for symbol: String) -> String {
        let base = symbol.replacingOccurrences(of: "-USD", with: "")
        return (tickerToName[base] ?? base.capitalized)
    }

    /// Мини-алиасы «имя → тикер» (можно расширять по мере нужды)
    private let nameToTicker: [String: String] = [
        "BITCOIN": "BTC",
        "ETHEREUM": "ETH",
        "SOLANA": "SOL",
        "BINANCE": "BNB",
        "RIPPLE": "XRP",
        "CARDANO": "ADA",
        "AVALANCHE": "AVAX",
        "POLKADOT": "DOT",
        "CELESTIA": "TIA"
    ]

    /// Алиасы «тикер → красивое имя» (для фоллбека)
    private let tickerToName: [String: String] = [
        "BTC":"Bitcoin", "ETH":"Ethereum", "SOL":"Solana", "BNB":"BNB",
        "XRP":"Ripple", "ADA":"Cardano", "AVAX":"Avalanche", "DOT":"Polkadot",
        "TIA":"Celestia"
    ]



    private func queryVariants(for raw: String, filter: SearchFilter) -> [String] {
        // базовый вариант всегда
        var v = [raw]
        // если выбран «Крипто» или введено похоже на символ (A..Z/0..9 без пробелов) — добавим -USD
        if filter == .crypto || looksLikeToken(raw) {
            let u = raw.uppercased()
            if !u.contains("-") { v.append(u + "-USD") }
        }
        return Array(Set(v)) // на всякий случай без дублей
    }

//    private func looksLikeToken(_ s: String) -> Bool {
//        let u = s.uppercased()
//        return u.range(of: "^[A-Z0-9]{2,10}$", options: .regularExpression) != nil
//    }



    private func uniqueBySymbol(_ arr: [SearchResult]) -> [SearchResult] {
        var seen = Set<String>(), res: [SearchResult] = []
        for r in arr {
            let key = r.symbol.uppercased()
            if seen.insert(key).inserted { res.append(r) }
        }
        return res
    }
    private func friendlyError(_ error: Error) -> String {
        let ns = error as NSError
        return ns.userInfo["body"] as? String ?? ns.localizedDescription
    }


}
//extension SymbolNormalizer {
//    static func prettyName(for symbol: String) -> String {
//        // "AVAX-USD" -> "Avalanche"
//        let base = symbol.replacingOccurrences(of: "-USD", with: "")
//        let map = ["BTC":"Bitcoin","ETH":"Ethereum","SOL":"Solana","BNB":"BNB",
//                   "XRP":"Ripple","ADA":"Cardano","AVAX":"Avalanche"]
//        return map[base] ?? base
//    }
//}

