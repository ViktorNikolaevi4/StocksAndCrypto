import SwiftUI

enum SearchFilter: String, CaseIterable, Identifiable {
    case equities = "Акции/ETF"
    case crypto = "Крипто"
    var id: String { rawValue }

}


struct AddSymbolSheet: View {
    @ObservedObject var vm: QuotesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var filter: SearchFilter = .equities

    private let quickCrypto = ["BTC","ETH","SOL","BNB","XRP","ADA"]

    var body: some View {
        VStack(spacing: 10) {
            // Быстрые кнопки по монетам
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickCrypto, id: \.self) { sym in
                        Button(sym) { add(symbol: sym) }.buttonStyle(.bordered)
                    }
                }.padding(.bottom, 4)
            }

            HStack {
                TextField("Название или тикер…", text: $query)
                    .textFieldStyle(.roundedBorder)
                Button("Найти") { Task { await search() } }
                    .keyboardShortcut(.return)
            }

            Picker("", selection: $filter) {
                Text("Акции/ETF").tag(SearchFilter.equities)
                Text("Крипто").tag(SearchFilter.crypto)
            }
            .pickerStyle(.segmented)

            if isLoading { ProgressView().padding(.vertical, 6) }
            if let e = errorText { Text(e).foregroundStyle(.red).font(.caption) }

            List(results) { r in
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

    private func add(symbol: String) {
        let normalized = SymbolNormalizer.normalize(symbol)
        var set = Set(vm.symbols.map { $0.uppercased() })
        set.insert(normalized.uppercased())
        vm.symbolsCSV = set.sorted().joined(separator: ",")
        Task { await vm.refresh() }
    }

    private func search() async {
        let raw = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        isLoading = true; errorText = nil
        defer { isLoading = false }

        do {
            let client = FinanceQueryClient(baseURL: URL(string: vm.serverRaw)!, apiKey: vm.apiKey)
            var bucket: [SearchResult] = []

            switch filter {
            case .crypto:
                for v in buildCryptoQueries(raw: raw) {
                    async let a: [SearchResult] = client.searchSymbols(query: v, hits: 20, yahoo: false)
                    async let b: [SearchResult] = client.searchSymbols(query: v, hits: 20, yahoo: true)
                    let (inner, yahoo) = try await (a, b)
                    bucket += inner + yahoo
                }
                results = dedupe(bucket).filter { isCrypto($0) }

                // фоллбек — если совсем пусто, но это похоже на токен
                if results.isEmpty, let usd = usdVariantIfToken(raw) {
                    results = [SearchResult(name: prettyName(for: usd),
                                            symbol: usd,
                                            exchange: "CRYPTO",
                                            type: "crypto")]
                }

            case .equities:
                for v in buildEquityQueries(raw: raw) {
                    bucket += try await client.searchSymbols(query: v, hits: 20, yahoo: true)
                }
                results = dedupe(bucket).filter { !isCrypto($0) }
            }

        } catch {
            errorText = friendlyError(error)
        }
    }

    // MARK: - Helpers

    private func dedupe(_ arr: [SearchResult]) -> [SearchResult] {
        var seen = Set<String>(), res: [SearchResult] = []
        for r in arr {
            let key = (r.symbol.uppercased()) + "@" + (r.exchange.uppercased())
            if seen.insert(key).inserted { res.append(r) }
        }
        return res
    }

    private func isCrypto(_ r: SearchResult) -> Bool {
        let uSym = r.symbol.uppercased()
        let uEx  = r.exchange.uppercased()
        if uEx.contains("CRYPTO") || uEx.contains("CCC") { return true }
        if uSym.hasSuffix("-USD") && !uSym.contains(".") { return true } // исключаем AVAX-USD.SW и т.п.
        return false
    }

    // — Крипто: добавляем -USD и альясы "имя → тикер"
    private func buildCryptoQueries(raw: String) -> [String] {
        var out = Set<String>()
        let u = raw.uppercased()
        out.insert(raw); out.insert(u)

        if let sym = nameToTicker[u] {
            out.insert(sym); out.insert("\(sym)-USD")
        }
        if looksLikeToken(u) && !u.contains("-") { out.insert("\(u)-USD") }
        if u.hasSuffix("-USD") { out.insert(String(u.dropLast(4))) }

        return Array(out)
    }

    // — Акции/ETF: никаких -USD, только то, что ввёл пользователь (+UPPER)
    private func buildEquityQueries(raw: String) -> [String] {
        let u = raw.uppercased()
        return Array(Set([raw, u]))
    }

    private func looksLikeToken(_ u: String) -> Bool {
        u.range(of: #"^[A-Z0-9]{2,10}$"#, options: .regularExpression) != nil
    }
    private func usdVariantIfToken(_ raw: String) -> String? {
        let u = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !u.isEmpty else { return nil }
        if u.hasSuffix("-USD") { return u }
        return looksLikeToken(u) ? "\(u)-USD" : nil
    }

    private let nameToTicker: [String: String] = [
        "BITCOIN":"BTC","ETHEREUM":"ETH","SOLANA":"SOL","BINANCE":"BNB",
        "RIPPLE":"XRP","CARDANO":"ADA","AVALANCHE":"AVAX","POLKADOT":"DOT",
        "CELESTIA":"TIA"
    ]
    private func prettyName(for symbol: String) -> String {
        let base = symbol.replacingOccurrences(of: "-USD", with: "")
        let map = ["BTC":"Bitcoin","ETH":"Ethereum","SOL":"Solana","BNB":"BNB",
                   "XRP":"Ripple","ADA":"Cardano","AVAX":"Avalanche","DOT":"Polkadot",
                   "TIA":"Celestia"]
        return map[base] ?? base.capitalized
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

