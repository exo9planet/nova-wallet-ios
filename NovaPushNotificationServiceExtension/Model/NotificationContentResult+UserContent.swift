import UserNotifications

extension NotificationContentResult {
    func toUserNotificationContent(with originalContent: UNMutableNotificationContent? = nil) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = ""
        content.sound = originalContent?.sound
        content.badge = originalContent?.badge
        content.body = subtitle
        content.userInfo = originalContent?.userInfo ?? [:]
        return content
    }
}
