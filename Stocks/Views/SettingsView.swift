import SwiftUI

struct SettingsView: View {
    @ObservedObject var vm: QuotesViewModel
    @State private var showingAdd = false
    @AppStorage("showSymbolsList") private var showSymbolsList = false

    // Сколько строк показываем без прокрутки
    private let visibleRows = 10
    private let rowHeight: CGFloat = 28

    var body: some View {
        Form {
            // MARK: Список тикеров
            Section("Список тикеров") {
                TextField("", text: $vm.symbolsCSV,
                          prompt: Text("AAPL,MSFT,TSLA,BTC-USD,ETH-USD"))
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()

                Text("Можно писать коротко: BTC → добавим как BTC-USD автоматически.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !vm.symbols.isEmpty {
                    // высота окна списка = min(кол-во, visibleRows) * rowHeight
                    let height = rowHeight * CGFloat(min(vm.symbols.count, visibleRows)) + 1

                    ScrollView {
                        LazyVStack(spacing: 0) {
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
                                    .buttonStyle(.borderless)
                                    .help("Удалить")
                                }
                                .frame(height: rowHeight)
                                Divider()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))
                }

                HStack {
                    Button("Добавить тикер…") { showingAdd = true }
                        .sheet(isPresented: $showingAdd) { AddSymbolSheet(vm: vm) }

                    Spacer()

                    Button("Упорядочить и убрать дубликаты") {
                        let set = Array(Set(vm.symbols.map { $0.uppercased() })).sorted()
                        vm.symbolsCSV = set.joined(separator: ",")
                        Task { await vm.refresh() }
                    }
                }

                // Доп. вариант — скрытый поштучный список (можно удалить весь DisclosureGroup, если не нужен)
//                DisclosureGroup(isExpanded: $showSymbolsList) {
//                    if vm.symbols.isEmpty {
//                        Text("Список пуст").foregroundStyle(.secondary)
//                    } else {
//                        ForEach(vm.symbols, id: \.self) { s in
//                            HStack {
//                                Text(s).font(.body.monospaced())
//                                Spacer()
//                                Button(role: .destructive) {
//                                    removeSymbol(s)
//                                } label: { Image(systemName: "trash") }
//                                .buttonStyle(.borderless)
//                                .help("Удалить \(s)")
//                            }
//                        }
//                    }
///                } label: {
//                    HStack {
//                        Text("Показать по одному (\(vm.symbols.count))")
//                        Spacer()
//                        Toggle("", isOn: $showSymbolsList)
//                            .labelsHidden()
//                    }
//                }
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
                        .frame(width: 44, alignment: .trailing)
                }
                Text("Крипто 24/7 — можно выбрать интервал пониже.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Применить и обновить") { Task { await vm.refresh() } }
        }
        .padding()
        .frame(minWidth: 520)
    }

    private func removeSymbol(_ s: String) {
        let arr = vm.symbols.filter { $0 != s }
        vm.symbolsCSV = arr.joined(separator: ",")
        Task { await vm.refresh() }
    }
}

