//
//  AppDelegate.swift
//  jsn
//
//  Created by Jorrit van Asselt on 04/01/2022.
//

import Cocoa
import UserNotifications

private let ProjectKeys = Set(["AVI", "EET"])

private let FetchTimeInterval: TimeInterval = 15*60 // (15 minutes)
private let cookieString = "ajs_anonymous_id=%2295a65932-738a-46e9-91db-3e0daba4fc40%22; ajs_group_id=null; cloud.session.token=eyJraWQiOiJzZXNzaW9uLXNlcnZpY2VcL3Byb2QtMTU5Mjg1ODM5NCIsImFsZyI6IlJTMjU2In0.eyJhc3NvY2lhdGlvbnMiOltdLCJzdWIiOiI2MGEyM2VjNTVkNjdmMjAwNjkyYWE1NmYiLCJlbWFpbERvbWFpbiI6InRyaXBhY3Rpb25zLmNvbSIsImltcGVyc29uYXRpb24iOltdLCJjcmVhdGVkIjoxNjM0MjEwNTMxLCJyZWZyZXNoVGltZW91dCI6MTY0MDE3MDQ1NSwidmVyaWZpZWQiOnRydWUsImlzcyI6InNlc3Npb24tc2VydmljZSIsInNlc3Npb25JZCI6IjZjMjNiZDcyLWQ4OGUtNDc4MC05NDlhLTc0ZTQ3MGMzZTYwYiIsImF1ZCI6ImF0bGFzc2lhbiIsIm5iZiI6MTY0MDE2OTg1NSwiZXhwIjoxNjQyNzYxODU1LCJpYXQiOjE2NDAxNjk4NTUsImVtYWlsIjoianZhbmFzc2VsdEB0cmlwYWN0aW9ucy5jb20iLCJqdGkiOiI2YzIzYmQ3Mi1kODhlLTQ3ODAtOTQ5YS03NGU0NzBjM2U2MGIifQ.nh-cIPGdzlo-NOiJXeeF0IVczgi8ZUc9cq0qoTGR63eg-i059ALa3lpxpQ8lSQcVXQdgxcaUCNMsACljrD-y3LmhCa0GddenaYM5Cy8wFNIquv3wfTIg7a3dMpf6a1sZdDkP3VEA73L8tSw5B7cB5D1_EugwpNw0rw4HD5-0YPkX5RexYNhCnof_TAQb2ipiM_86IobUqWvBzpJ34In_A3YgdCUaWfrWqYHe092zvlXKXIjiyT9QEp9lEUZ0LqkfTN_lMR1WY1MRXYooR4UFDCKgQtop47I9Zxr-Blk5Rn5sJJ-cPY4yMNKmhIGR5SRlsUZqvqPuhq5L5-5czj25uQ; AJS.conglomerate.cookie=\"|com.innovalog.jmwe.jira-misc-workflow-extensions$$is_user_admin=60a23ec55d67f200692aa56f/user\"; JSESSIONID=76A566E55A214E170331D20F7B311EE3; __awc_tld_test__=tld_test; atlassian.xsrf.token=b38f75f3-7759-44f9-9f16-5cbbc9ed9706_a970c9cb55a665bbbd2b4436a17647091d325ccf_lin"

@main
class AppDelegate: NSObject
{
    let projectIdentifiers = ["EET", "AVI"]
    var sprintReportsGenerators = [SprintReportsGenerator]()
    fileprivate let PreviousFetchDateKey = "PreviousFetchDateKey"
    var viewController: ViewController?
    {
        /// Yeah this line hurst my eyes too, please educate me on how
        /// to do this properly - Jorrit
        return mainWindow?.contentViewController as? ViewController
    }
    var mainWindow: NSWindow?
    {
        for aWindow in NSApplication.shared.windows
        {
            guard let classType = NSClassFromString("NSStatusBarWindow")
            else { fatalError() }
            if !aWindow.isKind(of: classType.self)
            {
                return aWindow
            }
        }
        return nil
    }
    
//    private var fetchScheduler = FetchScheduler()
    private let session = URLSession(configuration: .ephemeral)
    private var statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var checkItem: NSMenuItem? = nil
    private var sprintsReviewer: SprintsReviewer? = nil
    
    func sendNotification(title: String,
                          body: String = "",
                          subTitle: String = "")
    {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.subtitle = subTitle
        
        let uuidString = UUID().uuidString
        let request = UNNotificationRequest(
            identifier: uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false))
        
        
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.delegate = self
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        notificationCenter.add(request)
        {
            if let error = $0
            {
                print("Could not show notification: \(error)")
            }
        }
    }
    
    @objc private func checkSprints(sender: AnyClass?)
    {
        updateMenuItemTitleAndState(for: true)
        sprintsReviewer?.fetchSprintReviewResults(for: ProjectKeys)
        {
            let rapportsByKey = $0
            DispatchQueue.main.async
            {
                var allDetails = ""
                for aKeyAndRapport in rapportsByKey
                {
                    allDetails += "\(aKeyAndRapport.key) sprint:\n\(aKeyAndRapport.value.details)\n"
//                    self.sendNotification(title: "\(aKeyAndRapport.key) has changes",
//                                          body: aKeyAndRapport.value.summary)
                }
                self.viewController?.textView.string = allDetails
                self.updateMenuItemTitleAndState(for: false)
                self.showWindow(sender: self)
            }
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate
{
    //for displaying notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        /// This method is only called when the app is active. By    default,
        /// notifications are not shown when the app is active.
        /// Implementing this method, and calling the completionHandler will
        /// cause the notifcation to be shown when the app is active. Don't
        /// forget to assign the `delegate` property of a
        /// `UNUserNotificationCenter` instance.
        completionHandler([.banner, .sound])
    }
    
    // For handling tap and user actions
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void)
    {
        switch response.actionIdentifier
        {
        case UNNotificationDismissActionIdentifier: break
        case UNNotificationDefaultActionIdentifier:
            NSApplication.shared.windows[1].makeKeyAndOrderFront(self)
        default:
            break
        }
        completionHandler()
    }
}


extension AppDelegate: NSApplicationDelegate
{
    func applicationWillFinishLaunching(_ notification: Notification)
    {
        // The application does not appear in the Dock and does not have a menu
        // bar, but it may be activated programmatically or by clicking on one
        // of its windows.
        NSApp.setActivationPolicy(.accessory)
        
        sprintsReviewer = SprintsReviewer(cookieString: cookieString,
                                          session: session)
    }
    
    var defaultImage: NSImage
    {
        guard let defaultImage = NSImage(systemSymbolName: "circle",
                                                accessibilityDescription: nil)
        else { fatalError("Could not create symbol") }
        return defaultImage
    }
    var activityIndicatorImage: NSImage
    {
        guard let defaultImage = NSImage(systemSymbolName: "arrow.clockwise.circle",
                                                accessibilityDescription: nil)
        else { fatalError("Could not create symbol") }
        return defaultImage
    }
    
    private func updateMenuItemTitleAndState(for isFetching: Bool)
    {
        
        checkItem?.isEnabled = !isFetching
        if isFetching
        {
            self.checkItem?.title = NSLocalizedString("Currently Checking...", comment: "")
//            statusBarItem.button?.title = "꩜"
            statusBarItem.button?.image = activityIndicatorImage
        }
        else
        {
            self.checkItem?.title = NSLocalizedString("Check now", comment: "")
//            statusBarItem.button?.title = "◎"
            statusBarItem.button?.image = defaultImage
        }
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification)
    {
        mainWindow?.close()
        mainWindow?.title = "Jira Sprint Notifier"
        
        statusBarItem.button?.title = "◎"
        let statusBarMenu = NSMenu(title: NSLocalizedString("Jira Sprint Updates", comment: ""))
        statusBarItem.menu = statusBarMenu
        statusBarMenu.autoenablesItems = false
        
        let checkItem = NSMenuItem(title: "",
                                  action: #selector(AppDelegate.checkSprints(sender:)),
                                  keyEquivalent: "c")
        statusBarMenu.addItem(checkItem)
        self.checkItem = checkItem
        
        
        let showWindowItem = NSMenuItem(title: NSLocalizedString("Show Sprint Updates", comment: ""),
                                  action: #selector(AppDelegate.showWindow(sender:)),
                                  keyEquivalent: "s")
        statusBarMenu.addItem(showWindowItem)
        
        let generateSprintRapportsItem =
        NSMenuItem(title: NSLocalizedString("Generate Sprint Reports", comment: ""),
                   action: #selector(AppDelegate.generateSprintReports(sender:)),
                   keyEquivalent: "g")
        statusBarMenu.addItem(generateSprintRapportsItem)
        
        let settingsItem =
        NSMenuItem(title: NSLocalizedString("Settings", comment: ""),
                   action: #selector(AppDelegate.showSettingsWindow(sender:)),
                   keyEquivalent: ",")
        statusBarMenu.addItem(settingsItem)
        
        statusBarMenu.addItem(
            withTitle: NSLocalizedString("Quit", comment: ""),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q")
        
        updateMenuItemTitleAndState(for: false)
        
//        self.fetchScheduler.start
//        {
//            self.checkSprints(sender: nil)
//        }
    }
    
    @objc private func showSettingsWindow(sender: Any)
    {
        
        
    }
    @objc private func generateSprintReports(sender: Any)
    {
        for anIdentifier in projectIdentifiers
        {
            let sprintReportsGenerator = SprintReportsGenerator(cookieString: cookieString,
                                                                projectKey: anIdentifier,
                                                                activeSprintOnly: true)
            self.sprintReportsGenerators.append(sprintReportsGenerator)
            sprintReportsGenerator.generateReports
            {
                DispatchQueue.main.async
                {
                    self.sprintReportsGenerators.removeAll { $0 === sprintReportsGenerator }
                }
            }
        }
    }
    
    @objc private func showWindow(sender: Any)
    {
        mainWindow?.makeKey()
        mainWindow?.windowController?.showWindow(self)
        mainWindow?.level = .floating
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool
    { false }
}
