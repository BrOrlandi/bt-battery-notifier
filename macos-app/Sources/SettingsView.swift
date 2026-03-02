import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = Settings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configurações")
                .font(.headline)
                .padding(.bottom, 4)

            Toggle("Sempre notificar ao desconectar", isOn: $settings.alwaysNotifyOnDisconnect)

            if !settings.alwaysNotifyOnDisconnect {
                HStack {
                    Text("Notificar quando bateria abaixo de:")
                    Stepper("\(settings.batteryThreshold)%", value: $settings.batteryThreshold, in: 5...100, step: 5)
                }
                .padding(.leading, 20)
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
}
