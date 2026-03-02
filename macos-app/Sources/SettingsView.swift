import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = Settings.shared
    @ObservedObject var monitor = BluetoothMonitor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configurações")
                .font(.headline)
                .padding(.bottom, 4)

            Text("Exibir bateria na barra de menus:")
                .font(.subheadline)

            if monitor.knownDevices.isEmpty {
                Text("Nenhum dispositivo encontrado")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .padding(.leading, 20)
            } else {
                ForEach(monitor.knownDevices, id: \.address) { device in
                    Toggle(isOn: menubarBinding(for: device.address)) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(deviceConnected(device.address) ? Color.green : Color.gray)
                                .frame(width: 6, height: 6)
                            Text(device.name)
                                .lineLimit(1)
                            Spacer()
                            Text(batteryText(for: device.address))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.leading, 20)
                }
            }

            HStack {
                Text("Modo de exibição:")
                Picker("", selection: $settings.menubarDisplayMode) {
                    Text("Ícone e porcentagem").tag("iconAndPercentage")
                    Text("Apenas ícone").tag("iconOnly")
                    Text("Apenas porcentagem").tag("percentageOnly")
                }
                .labelsHidden()
            }

            Divider()

            Toggle("Sempre notificar ao desconectar", isOn: $settings.alwaysNotifyOnDisconnect)

            if !settings.alwaysNotifyOnDisconnect {
                Toggle("Notificar bateria baixa", isOn: $settings.notifyLowBattery)
                    .padding(.leading, 20)

                if settings.notifyLowBattery {
                    HStack {
                        Text("Notificar quando bateria abaixo de:")
                        Stepper("\(settings.batteryThreshold)%", value: $settings.batteryThreshold, in: 5...100, step: 5)
                    }
                    .padding(.leading, 20)
                }
            }

            Toggle("Notificar ao conectar", isOn: $settings.notifyOnConnect)

            Divider()

            Toggle("Abrir ao iniciar o Mac", isOn: $settings.launchAtLogin)

            Divider()

            HStack {
                Spacer()
                Button("Encerrar") {
                    NSApplication.shared.terminate(nil)
                }
                .foregroundColor(.red)
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private func deviceConnected(_ address: String) -> Bool {
        monitor.state[address]?.connected == true
    }

    private func batteryText(for address: String) -> String {
        guard let state = monitor.state[address] else { return "" }
        let battery = mainBattery(of: state)
        guard battery > 0 else { return "" }

        if state.connected {
            return "\(battery)%"
        } else if let date = state.lastBatteryUpdate {
            return "\(battery)% · \(formatDate(date))"
        }
        return "\(battery)%"
    }

    private func mainBattery(of state: BluetoothMonitor.DeviceState) -> Int {
        if state.isMultiBattery {
            return [state.batteryLeft, state.batteryRight, state.batteryCase].filter { $0 > 0 }.min() ?? 0
        }
        return state.battery
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "dd/MM HH:mm"
        }
        return formatter.string(from: date)
    }

    private func menubarBinding(for address: String) -> Binding<Bool> {
        Binding(
            get: { settings.menubarDeviceAddresses.contains(address) },
            set: { enabled in
                if enabled {
                    if !settings.menubarDeviceAddresses.contains(address) {
                        settings.menubarDeviceAddresses.append(address)
                    }
                } else {
                    settings.menubarDeviceAddresses.removeAll { $0 == address }
                }
            }
        )
    }
}
