import SwiftUI

struct SettingsView: View {
    @ObservedObject var vm: QuotesViewModel
    @State private var showingAdd = false

    var body: some View {
        Form {
            Section("Список тикеров") {
                TextField("AAPL,MSFT,TSLA,BTC-USD,ETH-USD", text: $vm.symbolsCSV)
                    .textFieldStyle(.roundedBorder)
                Text("Можно писать коротко: BTC → преобразуем в BTC-USD автоматически.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !vm.symbols.isEmpty {
                    ForEach(vm.symbols, id: \.self) { s in
                        HStack {
                            Text(s).font(.body.monospaced())
                            Spacer()
                            Button(role: .destructive) {
                                let arr = vm.symbols.filter { $0 != s }
                                vm.symbolsCSV = arr.joined(separator: ",")
                                Task { await vm.refresh() }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .help("Удалить")
                        }
                    }
                }

                Button("Добавить тикер…") { showingAdd = true }
                    .sheet(isPresented: $showingAdd) { AddSymbolSheet(vm: vm) }
            }

            Section("API") {
                SecureField("x-api-key", text: $vm.apiKey)
                    .textFieldStyle(.roundedBorder)

                Picker("Сервер", selection: Binding(
                    get: { FinanceQueryClient.Server(rawValue: vm.serverRaw) ?? .render },
                    set: { vm.serverRaw = $0.rawValue }
                )) {
                    ForEach(FinanceQueryClient.Server.allCases) { s in
                        Text(s.title).tag(s)
                    }
                }
            }

            Section("Обновление") {
                HStack {
                    Slider(value: $vm.refreshSeconds, in: 5...120, step: 1)
                    Text("\(Int(vm.refreshSeconds))s")
                        .frame(width: 40, alignment: .trailing)
                }
                Text("Крипто 24/7 — можно ставить интервал пониже.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Применить и обновить") { Task { await vm.refresh() } }
        }
        .padding()
    }
}
