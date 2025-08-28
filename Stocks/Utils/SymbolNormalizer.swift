import Foundation

enum SymbolNormalizer {
    static let cryptoBase: Set<String> = [
        "BTC","ETH","SOL","BNB","XRP","ADA","DOGE","TON","TRX","AVAX",
        "DOT","LINK","LTC","BCH","MATIC","ATOM","XLM","ETC","ICP","FIL"
    ]

    /// "btc" → "BTC-USD"; акции/ETF не трогаем
    static func normalize(_ raw: String) -> String {
        let u = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !u.isEmpty else { return u }
        if u.contains("-") { return u }                 // уже вида BTC-USD
        if cryptoBase.contains(u) { return "\(u)-USD" } // короткая запись крипты
        return u
    }

    static func isCrypto(symbol: String) -> Bool {
        let u = symbol.uppercased()
        return u.contains("-USD") || cryptoBase.contains(u)
    }
}
