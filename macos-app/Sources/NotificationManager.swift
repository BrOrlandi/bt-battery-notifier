import UserNotifications

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    @Published var authorizationDenied = false

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.authorizationDenied = settings.authorizationStatus == .denied
            }
        }
    }

    func requestPermission() {
        let center = UNUserNotificationCenter.current()

        // Check current authorization status
        center.getNotificationSettings { settings in
            NSLog("[INFO] Notification auth status: %d (0=notDetermined, 1=denied, 2=authorized)", settings.authorizationStatus.rawValue)

            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if let error = error {
                        NSLog("[ERROR] Notification permission error: %@", "\(error)")
                    }
                    NSLog("[INFO] Notification permission result: %@", granted ? "granted" : "denied")
                }
            case .authorized, .provisional:
                NSLog("[INFO] Notifications already authorized")
                DispatchQueue.main.async { self.authorizationDenied = false }
            case .denied:
                NSLog("[WARN] Notifications denied - user must enable in System Settings")
                DispatchQueue.main.async { self.authorizationDenied = true }
            @unknown default:
                NSLog("[WARN] Notification status unknown: %d", settings.authorizationStatus.rawValue)
            }
        }
    }

    func send(title: String, body: String, subtitle: String? = nil) {
        NSLog("[INFO] Sending notification: %@ - %@", title, body)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if let subtitle = subtitle {
            content.subtitle = subtitle
        }
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("[ERROR] Failed to send notification: %@", "\(error)")
            } else {
                NSLog("[INFO] Notification delivered: %@", title)
            }
        }
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
