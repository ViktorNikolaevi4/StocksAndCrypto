import Foundation

actor FinanceQueryClient {
    enum Server: String, CaseIterable, Identifiable {
        case render = "https://finance-query.onrender.com"
        case aws    = "https://43pk30s7aj.execute-api.us-east-2.amazonaws.com/prod"
        var id: String { rawValue }
        var title: String { self == .render ? "Render" : "AWS" }
    }

    var baseURL: URL
    var apiKey: String?

    init(baseURL: URL, apiKey: String?) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    func simpleQuotes(symbols: [String]) async throws -> [SimpleQuote] {
        let syms = symbols.filter { !$0.isEmpty }
        guard !syms.isEmpty else { return [] }

        var c = URLComponents(url: baseURL.appendingPathComponent("/v1/simple-quotes"), resolvingAgainstBaseURL: false)!
        c.queryItems = [URLQueryItem(name: "symbols", value: syms.joined(separator: ","))]

        var req = URLRequest(url: c.url!)
        if let key = apiKey, !key.isEmpty {
            req.addValue(key, forHTTPHeaderField: "x-api-key")
        }

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw URLError(.badServerResponse, userInfo: ["body": body])
        }
        return try JSONDecoder().decode([SimpleQuote].self, from: data)
    }

    func searchSymbols(query: String, hits: Int = 20, yahoo: Bool = true, type: String? = nil) async throws -> [SearchResult] {
        var c = URLComponents(url: baseURL.appendingPathComponent("/v1/search"), resolvingAgainstBaseURL: false)!
        c.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "hits", value: String(hits)),
            URLQueryItem(name: "yahoo", value: yahoo ? "true" : "false")
        ]
        if let type { c.queryItems?.append(URLQueryItem(name: "type", value: type)) }

        var req = URLRequest(url: c.url!)
        if let key = apiKey, !key.isEmpty {
            req.addValue(key, forHTTPHeaderField: "x-api-key")
        }

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([SearchResult].self, from: data)
    }
}
extension FinanceQueryClient {
    /// Возвращает массив закрытий по возрастанию даты
    func historicalCloses(symbol: String, range: String = "1mo", interval: String = "1d")
    async throws -> [Double] {
        var c = URLComponents(
            url: baseURL.appendingPathComponent("/v1/historical"),
            resolvingAgainstBaseURL: false
        )!
        c.queryItems = [
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "range", value: range),
            URLQueryItem(name: "interval", value: interval)
        ]

        var req = URLRequest(url: c.url!)
        if let key = apiKey, !key.isEmpty {
            req.addValue(key, forHTTPHeaderField: "x-api-key")
        }

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw URLError(.badServerResponse, userInfo: ["body": body])
        }

        // Ответ — словарь "YYYY-MM-DD" -> HistoricalData
        let dict = try JSONDecoder().decode([String: HistoricalData].self, from: data)
        let keys = dict.keys.sorted() // формат ISO сортируется лексикографически
        return keys.compactMap { dict[$0]?.close }
    }
}
