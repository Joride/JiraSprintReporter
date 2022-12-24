//
//  SprintReviewer.swift
//  jsn
//
//  Created by Jorrit van Asselt on 24/12/2022.
//

import Foundation
import UserNotifications

private let FetchTimeInterval: TimeInterval = 15 * 60 // (15 minutes)


/// The identifiers for the Jira projects for Recharge's engineering teams
private let userprojectKeys: [String] = [
"PAY",      // Payments & Risk
"MR",       // Retention
"SHOP",     // Checkout
"MOBAPP",   // Mobile Apps
"DIS",      // Discovery
"OD",       // Orders & Delivery
"SIM",      // Supply Integation & Management
"PET",      // Platform Engineering
]


class SprintReviewer: NSObject
{
    private let notificationCenter = UNUserNotificationCenter.current()
    private let session = URLSession(configuration: .ephemeral)
    private let PreviousFetchDateKey = "PreviousFetchDateKey"
    
    private lazy var callbackRepeater = {
        CallbackRepeater(interval: FetchTimeInterval,
                         activeTimeStart: DateComponents(),
                         activeTimeEnd: DateComponents())
        {
            
        }
    }()
    
    
    override init()
    {
        super.init()
        notificationCenter.delegate = self
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error
            {
                print("Error requesting permission for notifiations: \(error)")
                // Handle the error here.
            }
            // Enable or disable features based on the authorization.
        }
    }
    
    private  func sendNotification(title: String,
                          body: String,
                          subTitle: String,
                          threadId: String?)
    {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.subtitle = subTitle
        content.sound = .default
        content.interruptionLevel = .active
        
        if let threadIdentifier = threadId
        {
            content.threadIdentifier = threadIdentifier
        }
        
        let uuidString = UUID().uuidString
        let request = UNNotificationRequest(
            identifier: uuidString,
            content: content,
            trigger: nil)
        
        notificationCenter.add(request)
        {
            if let error = $0
            {
                print("Could not show notification: \(error)")
            }
        }
    }
    @objc private func obtainSprintReviews(sender: AnyObject? = nil)
    {
        Task
        {
            let sprintReviews = try await withThrowingTaskGroup(of: SprintReview?.self) { group in
                
                for aUserprojectKey in userprojectKeys
                {
                    group.addTask { try await self.obtainSprintReview(forProject: aUserprojectKey) }
                }
                
                var result = [SprintReview?]()
                for try await sprintReview in group
                {
                    result.append(sprintReview)
                }
                return result.compactMap{$0}
            }
            DispatchQueue.main.async
            {
                for aReview in sprintReviews
                {
                    if let summary = aReview.notificationSummary
                    {
                        self.sendNotification(title: summary.title,
                                              body: summary.body,
                                              subTitle: summary.subtitle,
                                              threadId: aReview.projectKey)
                    }
                }
            }
            
            for aReview in sprintReviews
            {
                if aReview.extendedIssues.count == 0
                {
                    print("\t\(aReview.projectKey) -> no issues in sprint")
                    continue
                }
                
                if aReview.doneTickets.count == 0
                {
                    print("\t\(aReview.projectKey) -> has no tickets done yet")
                }
                else if aReview.doneBugsWithoutTimeSpent.count > 0
                {
                    print("\t\(aReview.projectKey) -> has bugs without logged time")
                }
                else if aReview.doneTasksWithoutTimeSpent.count > 0
                {
                    print("\t\(aReview.projectKey) -> has tasks without logged time")
                }
                else
                {
                    print("\t\(aReview.projectKey) - \(aReview.extendedIssues.count) issues in sprint")
                }
            }
        }
    }
        
    func obtainSprintReview(forProject projectKey: String) async throws -> SprintReview?
    {
        let sprintIssuesFetcher = SprintIssuesFetcher(projectKey: projectKey,
                                                      cookieString: cookieString)
        if let issues = await sprintIssuesFetcher.fetch()
        {
            let issueKeys = issues.map{ $0.key }
            do
            {
                let extendedIssues = try await IssuesChangelogsFetcher(issueKeys: issueKeys,
                                                                       cookieString: cookieString).fetch()
                let review = await SprintReview(projectKey: projectKey,
                                                extendedIssues: extendedIssues,
                                                sinceDate: Date.distantPast)
                return review
            }
            catch
            {
                print("Could not obtain changelogs for issue: \(error)")
            }
        }
        else
        {
            print("Could not fetch issues for \(projectKey)")
        }
        return nil
    }
}

extension SprintReviewer: UNUserNotificationCenterDelegate
{
    //for displaying notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        /// This method is only called when the app is active. By default,
        /// notifications are not shown when the app is active.
        /// Implementing this method, and calling the completionHandler will
        /// cause the notifcation to be shown when the app is active. Don't
        /// forget to assign the `delegate` property of a
        /// `UNUserNotificationCenter` instance.
        completionHandler([.banner, .sound, .list])
    }
    
    // For handling tap and user actions
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void)
    {
        switch response.actionIdentifier
        {
        case UNNotificationDismissActionIdentifier: break
        case UNNotificationDefaultActionIdentifier: break
//            NSApplication.shared.windows[1].makeKeyAndOrderFront(self)
        default:
            break
        }
        completionHandler()
    }
}
