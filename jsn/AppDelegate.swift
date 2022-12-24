//
//  AppDelegate.swift
//  jsn
//
//  Created by Jorrit van Asselt on 04/01/2022.
//

import Cocoa
import UserNotifications

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

private let FetchTimeInterval: TimeInterval = 15*60 // (15 minutes)

@main
class AppDelegate: NSObject
{
    private let notificationCenter = UNUserNotificationCenter.current()
    private lazy var settingsWindowController: NSWindowController =
    {
        let window = NSWindow()
        return NSWindowController(window: window)
    }()
    
    fileprivate let PreviousFetchDateKey = "PreviousFetchDateKey"
    var viewController: ViewController?
    {
        /// Yeah this line hurst my eyes too, please educate me on how
        /// to do this properly - Jorrit
        return mainWindow?.contentViewController as? ViewController
    }
    var mainWindow: NSWindow?
    {
        /// Watch out, retinal damage might occur
        /// by looking at this implementation!
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
    
    private let session = URLSession(configuration: .ephemeral)
    private var statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var checkItem: NSMenuItem? = nil
    
    func sendNotification(title: String,
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
    
//    @objc private func checkSprints(sender: AnyClass?)
//    {
//        updateMenuItemTitleAndState(forFetchingState: true)
        
//        sprintsReviewer?.fetchSprintReviewResults(for: ProjectKeys)
//        {
//            let rapportsByKey = $0
//            DispatchQueue.main.async
//            {
//                var allDetails = ""
//                for aKeyAndRapport in rapportsByKey
//                {
//                    allDetails += "\(aKeyAndRapport.key) sprint:\n\(aKeyAndRapport.value.details)\n"
////                    self.sendNotification(title: "\(aKeyAndRapport.key) has changes",
////                                          body: aKeyAndRapport.value.summary)
//                }
//                self.viewController?.textView.string = allDetails
//                self.updateMenuItemTitleAndState(for: false)
//                self.showWindow(sender: self)
//            }
//        }
//    }
}

extension AppDelegate: UNUserNotificationCenterDelegate
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
        
//        obtainSprintReviews()
    }
    
    @objc private func obtainSprintReviews(sender: AnyObject? = nil)
    {
        updateMenuItemTitleAndState(forFetchingState: true)
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
                self.updateMenuItemTitleAndState(forFetchingState: false)
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
    
    private func updateMenuItemTitleAndState(forFetchingState isFetching: Bool)
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
        
        notificationCenter.delegate = self
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error
            {
                print("Error requesting permission for notifiations: \(error)")
                // Handle the error here.
            }
            // Enable or disable features based on the authorization.
        }
        
        mainWindow?.close()
        mainWindow?.title = "Jira Sprint Notifier"
        
        statusBarItem.button?.title = "◎"
        let statusBarMenu = NSMenu(title: NSLocalizedString("Jira Sprint Updates", comment: ""))
        statusBarItem.menu = statusBarMenu
        statusBarMenu.autoenablesItems = false
        
        let checkItem = NSMenuItem(title: "",
                                  action: #selector(AppDelegate.obtainSprintReviews(sender:)),
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
        
        updateMenuItemTitleAndState(forFetchingState: false)
        
//        self.fetchScheduler.start
//        {
//            self.checkSprints(sender: nil)
//        }
    }
    
    @objc private func showSettingsWindow(sender: Any)
    {
        settingsWindowController.window?.level = .floating
        settingsWindowController.window?.title = NSLocalizedString("Jira Sprint Reporter Settings",
                                                                   comment: "")
//        let settingsViewHostingController = SettingsViewHostingController(rootView: SettingsView())
//        settingsWindowController.window?.contentViewController = settingsViewHostingController
        
//        guard let screenSize = NSScreen.main?.visibleFrame.size
//        else { fatalError("No monitor connected? Not covering this case.") }
//
//        let contentSize = settingsViewHostingController.sizeThatFits(in: screenSize)
//        settingsWindowController.window?.setContentSize(contentSize)
//        settingsWindowController.window?.styleMask = [.closable,
//                                                      .miniaturizable,
//                                                      .resizable,
//                                                      .titled]
//        settingsWindowController.showWindow(self)
    }
    @objc private func generateSprintReports(sender: Any)
    {
        for anIdentifier in userprojectKeys
        {
            /// do here what `jsr` command line tool does
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
