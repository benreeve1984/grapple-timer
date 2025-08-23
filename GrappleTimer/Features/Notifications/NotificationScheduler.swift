import Foundation
import UserNotifications

@MainActor
final class NotificationScheduler: ObservableObject {
    static let shared = NotificationScheduler()
    
    @Published private(set) var isAuthorized = false
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private var scheduledNotifications: [String] = []
    
    private init() {
        checkAuthorizationStatus()
    }
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.isAuthorized = granted
            }
            return granted
        } catch {
            print("Failed to request notification authorization: \(error)")
            return false
        }
    }
    
    func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func scheduleSessionNotifications(for session: TimerSession) async {
        guard isAuthorized else {
            _ = await requestAuthorization()
            guard isAuthorized else { return }
        }
        
        await clearAllNotifications()
        
        var notifications: [UNNotificationRequest] = []
        let startTime = session.startTime
        var currentTime = session.configuration.startDelay
        
        for round in 1...session.configuration.rounds {
            let workContent = UNMutableNotificationContent()
            workContent.title = "Round \(round) - WORK"
            workContent.body = "Time to work! \(Int(session.configuration.roundDuration / 60)) minutes"
            workContent.sound = .default
            workContent.categoryIdentifier = "TIMER_PHASE"
            
            let workTrigger = UNTimeIntervalNotificationTrigger(
                timeInterval: currentTime,
                repeats: false
            )
            
            let workId = "work_\(round)_\(UUID().uuidString)"
            let workRequest = UNNotificationRequest(
                identifier: workId,
                content: workContent,
                trigger: workTrigger
            )
            
            notifications.append(workRequest)
            scheduledNotifications.append(workId)
            
            currentTime += session.configuration.roundDuration
            
            if round < session.configuration.rounds {
                let restContent = UNMutableNotificationContent()
                restContent.title = "Round \(round) - REST"
                restContent.body = "Rest time! \(Int(session.configuration.restDuration / 60)) minute"
                restContent.sound = .default
                restContent.categoryIdentifier = "TIMER_PHASE"
                
                let restTrigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: currentTime,
                    repeats: false
                )
                
                let restId = "rest_\(round)_\(UUID().uuidString)"
                let restRequest = UNNotificationRequest(
                    identifier: restId,
                    content: restContent,
                    trigger: restTrigger
                )
                
                notifications.append(restRequest)
                scheduledNotifications.append(restId)
                
                currentTime += session.configuration.restDuration
            }
        }
        
        let doneContent = UNMutableNotificationContent()
        doneContent.title = "Session Complete!"
        doneContent.body = "Great work! You completed all \(session.configuration.rounds) rounds"
        doneContent.sound = .default
        doneContent.categoryIdentifier = "TIMER_COMPLETE"
        
        let doneTrigger = UNTimeIntervalNotificationTrigger(
            timeInterval: currentTime,
            repeats: false
        )
        
        let doneId = "done_\(UUID().uuidString)"
        let doneRequest = UNNotificationRequest(
            identifier: doneId,
            content: doneContent,
            trigger: doneTrigger
        )
        
        notifications.append(doneRequest)
        scheduledNotifications.append(doneId)
        
        for notification in notifications {
            do {
                try await notificationCenter.add(notification)
            } catch {
                print("Failed to schedule notification: \(error)")
            }
        }
    }
    
    func clearAllNotifications() async {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
        scheduledNotifications.removeAll()
    }
    
    func updateNotificationsForPause(at pauseTime: Date) async {
        let pending = await notificationCenter.pendingNotificationRequests()
        
        var updatedNotifications: [UNNotificationRequest] = []
        
        for request in pending {
            guard scheduledNotifications.contains(request.identifier) else { continue }
            
            if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                let newTrigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: trigger.timeInterval + 86400,
                    repeats: false
                )
                
                let newRequest = UNNotificationRequest(
                    identifier: request.identifier + "_paused",
                    content: request.content,
                    trigger: newTrigger
                )
                
                updatedNotifications.append(newRequest)
            }
        }
        
        await clearAllNotifications()
        
        for notification in updatedNotifications {
            do {
                try await notificationCenter.add(notification)
                scheduledNotifications.append(notification.identifier)
            } catch {
                print("Failed to update notification: \(error)")
            }
        }
    }
    
    func updateNotificationsForResume(pauseDuration: TimeInterval) async {
        let pending = await notificationCenter.pendingNotificationRequests()
        
        var updatedNotifications: [UNNotificationRequest] = []
        
        for request in pending {
            guard scheduledNotifications.contains(request.identifier) else { continue }
            
            if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                let adjustedInterval = max(1, trigger.timeInterval - 86400 + pauseDuration)
                
                let newTrigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: adjustedInterval,
                    repeats: false
                )
                
                let originalId = request.identifier.replacingOccurrences(of: "_paused", with: "")
                let newRequest = UNNotificationRequest(
                    identifier: originalId,
                    content: request.content,
                    trigger: newTrigger
                )
                
                updatedNotifications.append(newRequest)
            }
        }
        
        await clearAllNotifications()
        
        for notification in updatedNotifications {
            do {
                try await notificationCenter.add(notification)
                scheduledNotifications.append(notification.identifier)
            } catch {
                print("Failed to resume notification: \(error)")
            }
        }
    }
}