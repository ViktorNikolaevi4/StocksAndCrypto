import Combine
import SwiftUI

@main
struct FinanceMenuBarApp: App {
    @StateObject private var vm = QuotesViewModel()

    var body: some Scene {
        MenuBarExtra("Quotes", systemImage: "chart.line.uptrend.xyaxis") {
            MenuContent(vm: vm)
                .frame(width: 400)
                .task {
                    await vm.refresh()
                    vm.startAutoRefresh()
                }
        }
        .menuBarExtraStyle(.window)

        // Отдельное окно настроек
        Window("Настройки", id: "settings") {
            SettingsView(vm: vm)
                .frame(width: 560)
        }
        // Отдельное окно  для добавления тикера
        Window("Добавить тикер", id: "addSymbol") {
            AddSymbolSheet(vm: vm)
                .frame(width: 560, height: 400)
        }
    }
}
