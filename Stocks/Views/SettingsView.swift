import SwiftUI

struct SettingsView: View {
    @ObservedObject var vm: QuotesViewModel
    @State private var showingAdd = false
    @AppStorage("showSymbolsList") private var showSymbolsList = false

    var body: some View {
        Form {
            // MARK: Список тикеров
            Section("Список тикеров") {
                TextField("", text: $vm.symbolsCSV, prompt: Text("AAPL,MSFT,TSLA,BTC-USD,ETH-USD"))
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                Text("Можно писать коротко: BTC → добавим как BTC-USD автоматически.")
                    .font(.caption).foregroundStyle(.secondary)

                HStack {
                    Button("Добавить тикер…") { showingAdd = true }
                        .sheet(isPresented: $showingAdd) { AddSymbolSheet(vm: vm) }

                    Spacer()

                    Button("Упорядочить и убрать дубликаты") {
                        let set = Set(vm.symbols.map { $0.uppercased() })
                        vm.symbolsCSV = set.sorted().joined(separator: ",")
                        Task { await vm.refresh() }
                    }
                    .buttonStyle(.link)
                }

                // ===== Если хотите совсем убрать поштучный список — удалите DisclosureGroup ниже =====
                DisclosureGroup(isExpanded: $showSymbolsList) {
                    if vm.symbols.isEmpty {
                        Text("Список пуст").foregroundStyle(.secondary)
                    } else {
                        ForEach(vm.symbols, id: \.self) { s in
                            HStack {
                                Text(s).font(.body.monospaced())
                                Spacer()
                                Button(role: .destructive) {
                                    removeSymbol(s)
                                } label: { Image(systemName: "trash") }
                                .help("Удалить \(s)")
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text("Показать по одному (\(vm.symbols.count))")
                        Spacer()
                        Toggle("", isOn: $showSymbolsList)
                            .labelsHidden()
                    }
                }
                // ======================================================================================
            }

            // MARK: API
            Section("API") {
                SecureField("x-api-key", text: $vm.apiKey)
                    .textFieldStyle(.roundedBorder)

                Picker("Сервер", selection: Binding(
                    get: { FinanceQueryClient.Server(rawValue: vm.serverRaw) ?? .render },
                    set: { vm.serverRaw = $0.rawValue }
                )) {
                    ForEach(FinanceQueryClient.Server.allCases) { s in
                        Text(s == .render ? "Render" : "AWS").tag(s)
                    }
                }
            }

            // MARK: Обновление
            Section("Обновление") {
                HStack {
                    Slider(value: $vm.refreshSeconds, in: 5...120, step: 1)
                    Text("\(Int(vm.refreshSeconds))s")
                        .frame(width: 40, alignment: .trailing)
                }
                Text("Крипто 24/7 — можно выбрать интервал пониже.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Button("Применить и обновить") { Task { await vm.refresh() } }
        }
        .padding()
    }

    private func removeSymbol(_ s: String) {
        let arr = vm.symbols.filter { $0 != s }
        vm.symbolsCSV = arr.joined(separator: ",")
        Task { await vm.refresh() }
    }
}
